// Shared character language model (nc_lm_*). Included after
// the ORT helpers.
//
// The graph (tools/char_lm_onnx.py) takes ids, positions, an attention mask that
// is combined with the causal mask, and a per-layer KV cache. Scoring packs the
// candidates into one trie (every node after its ancestors, position = depth,
// mask = ancestors only), so shared prefixes are computed once and every
// candidate gets exactly the log-probability of a separate run.
namespace {

constexpr int64_t kCharLmBos = 0;
constexpr int64_t kCharLmUnknown = 1;
constexpr size_t kCharLmMaxNodes = 1024;
constexpr int kCharLmMaxTexts = 256;

// A real ORT cancellation deadline, not merely discarding an already-late result.
class CharLmDeadline {
    PTP_TIMER timer_{};
    static void CALLBACK Cancel(PTP_CALLBACK_INSTANCE, void* context, PTP_TIMER) {
        try { static_cast<Ort::RunOptions*>(context)->SetTerminate(); } catch (...) {}
    }
public:
    explicit CharLmDeadline(Ort::RunOptions& options, int milliseconds) {
        if (milliseconds <= 0) return;
        timer_ = CreateThreadpoolTimer(Cancel, &options, nullptr);
        if (!timer_) throw std::runtime_error("cannot create inference deadline");
        LARGE_INTEGER relative; relative.QuadPart = -10000LL * milliseconds;
        FILETIME due{relative.LowPart, static_cast<DWORD>(relative.HighPart)};
        SetThreadpoolTimer(timer_, &due, 0, 0);
    }
    ~CharLmDeadline() {
        if (timer_) {
            SetThreadpoolTimer(timer_, nullptr, 0, 0);
            WaitForThreadpoolTimerCallbacks(timer_, TRUE);
            CloseThreadpoolTimer(timer_);
        }
    }
};

struct CharLmHandle {
    // Handles opened on the same model share one session (and its weights);
    // each keeps its own lock and buffers.
    std::shared_ptr<Ort::Session> session;
    std::unordered_map<uint32_t, int64_t> vocabulary;
    std::vector<uint32_t> code_points;  // token id - 2 -> code point
    std::vector<uint8_t> continuation_allowed;  // per token id
    int64_t vocab_size{};
    int64_t block_size{};
    int64_t layers{};
    int64_t heads{};
    int64_t head_dim{};
    std::vector<std::string> input_names;
    std::vector<std::string> output_names;
    std::mutex mutex;
};

// Sessions by model path, so the shared LM and the repair host load one copy of
// a model they both use. Guarded by InitializationMutex().
std::map<std::wstring, std::weak_ptr<Ort::Session>>& CharLmSessions() {
    static std::map<std::wstring, std::weak_ptr<Ort::Session>> value;
    return value;
}

std::wstring CharLmSessionKey(const std::wstring& path) {
    std::wstring full(32768, L'\0');
    const DWORD length = GetFullPathNameW(path.c_str(), static_cast<DWORD>(full.size()), full.data(), nullptr);
    std::wstring key = (length > 0 && length < full.size()) ? full.substr(0, length) : path;
    for (auto& c : key) c = static_cast<wchar_t>(std::towlower(c));
    return key;
}

bool CharLmIsHan(uint32_t cp) {
    return (cp >= 0x4E00 && cp <= 0x9FFF) || (cp >= 0x3400 && cp <= 0x4DBF) ||
        (cp >= 0x20000 && cp <= 0x2FFFF) || (cp >= 0xF900 && cp <= 0xFAFF);
}

void CharLmLoadVocabulary(const std::wstring& directory, CharLmHandle& h) {
    std::ifstream in(directory + L"\\char_lm_vocab.bin", std::ios::binary);
    char magic[8];
    if (!in.read(magic, 8) || std::memcmp(magic, "CASSLM01", 8))
        throw std::runtime_error("invalid character LM vocabulary");
    uint32_t count = 0, block = 0, vocab = 0;
    if (!ReadBinary(in, count) || !ReadBinary(in, block) || !ReadBinary(in, vocab) ||
        count + 2 != vocab || block == 0 || block > 4096)
        throw std::runtime_error("invalid character LM vocabulary header");
    h.code_points.resize(count);
    h.continuation_allowed.assign(vocab, 0);
    for (uint32_t i = 0; i < count; ++i) {
        if (!ReadBinary(in, h.code_points[i]) || h.code_points[i] > 0x10FFFF)
            throw std::runtime_error("truncated character LM vocabulary");
        h.vocabulary.emplace(h.code_points[i], static_cast<int64_t>(i) + 2);
        h.continuation_allowed[i + 2] = CharLmIsHan(h.code_points[i]) ? 1 : 0;
    }
    h.vocab_size = vocab;
    h.block_size = block;
}

std::vector<int64_t> CharLmEncode(const CharLmHandle& h, const wchar_t* text) {
    std::vector<int64_t> ids;
    if (!text) return ids;
    for (const wchar_t* p = text; *p; ++p) {
        uint32_t cp = *p;
        if (cp >= 0xD800 && cp <= 0xDBFF && p[1] >= 0xDC00 && p[1] <= 0xDFFF) {
            cp = 0x10000 + ((cp - 0xD800) << 10) + (static_cast<uint32_t>(p[1]) - 0xDC00);
            ++p;
        } else if (cp >= 0xD800 && cp <= 0xDFFF) {
            ids.push_back(kCharLmUnknown);  // unpaired surrogate
            continue;
        }
        const auto found = h.vocabulary.find(cp);
        ids.push_back(found == h.vocabulary.end() ? kCharLmUnknown : found->second);
    }
    return ids;
}

void CharLmAppendUtf16(std::wstring& out, uint32_t cp) {
    if (cp >= 0x10000) {
        cp -= 0x10000;
        out.push_back(static_cast<wchar_t>(0xD800 + (cp >> 10)));
        out.push_back(static_cast<wchar_t>(0xDC00 + (cp & 0x3FF)));
    } else {
        out.push_back(static_cast<wchar_t>(cp));
    }
}

// Runs the graph. past may be null (empty cache). Returns logp_all, and the
// per-layer presents when want_presents is set.
std::vector<Ort::Value> CharLmRun(CharLmHandle& h, const std::vector<int64_t>& ids,
    const std::vector<int64_t>& positions, const std::vector<int32_t>& mask,
    int64_t past_length, std::vector<Ort::Value>* past, bool want_presents,
    Ort::RunOptions& options) {
    auto memory = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
    const int64_t n = static_cast<int64_t>(ids.size());
    const std::array<int64_t, 2> ids_shape{1, n};
    const std::array<int64_t, 3> mask_shape{1, n, past_length + n};
    const std::array<int64_t, 5> empty_shape{2, 1, h.heads, 0, h.head_dim};
    static float empty_value = 0.0f;
    std::vector<Ort::Value> inputs;
    inputs.push_back(Ort::Value::CreateTensor<int64_t>(memory, const_cast<int64_t*>(ids.data()),
        ids.size(), ids_shape.data(), 2));
    inputs.push_back(Ort::Value::CreateTensor<int64_t>(memory, const_cast<int64_t*>(positions.data()),
        positions.size(), ids_shape.data(), 2));
    inputs.push_back(Ort::Value::CreateTensor<int32_t>(memory, const_cast<int32_t*>(mask.data()),
        mask.size(), mask_shape.data(), 3));
    for (int64_t layer = 0; layer < h.layers; ++layer) {
        if (past) {
            inputs.push_back(std::move((*past)[static_cast<size_t>(layer)]));
        } else {
            inputs.push_back(Ort::Value::CreateTensor<float>(memory, &empty_value, 0,
                empty_shape.data(), 5));
        }
    }
    std::vector<const char*> input_names;
    for (const auto& name : h.input_names) input_names.push_back(name.c_str());
    std::vector<const char*> output_names{h.output_names[0].c_str()};
    if (want_presents)
        for (size_t i = 1; i < h.output_names.size(); ++i) output_names.push_back(h.output_names[i].c_str());
    return h.session->Run(options, input_names.data(), inputs.data(), inputs.size(),
        output_names.data(), output_names.size());
}

// The top_k most probable Han characters after a node (log-probabilities in
// row, one per token id), best first; ties keep the lower id.
void CharLmTopNext(const CharLmHandle& h, const float* row, int top_k, uint32_t* code_points,
    float* logps) {
    std::vector<int64_t> best;
    for (int64_t id = 2; id < h.vocab_size; ++id) {
        if (!h.continuation_allowed[static_cast<size_t>(id)]) continue;
        if (static_cast<int>(best.size()) == top_k && row[id] <= row[best.back()]) continue;
        auto at = best.end();
        while (at != best.begin() && row[*(at - 1)] < row[id]) --at;
        best.insert(at, id);
        if (static_cast<int>(best.size()) > top_k) best.pop_back();
    }
    for (int i = 0; i < top_k; ++i) {
        const bool found = i < static_cast<int>(best.size());
        code_points[i] = found ? h.code_points[static_cast<size_t>(best[static_cast<size_t>(i)] - 2)] : 0;
        logps[i] = found ? row[best[static_cast<size_t>(i)]] : 0.0f;
    }
}

// Sum of log P(text | BOS + context) for each leading text, from one packed trie.
// Texts are taken in order while the trie (BOS and context included) stays within
// max_nodes; the first min_count texts are always taken. For each of next_count
// text indices, also writes the top_k Han characters after that text (code point
// 0 when the text was not scored). Returns how many texts were scored, or -1.
int CharLmScore(CharLmHandle& h, const wchar_t* context, const wchar_t* const* texts, int count,
    int min_count, size_t max_nodes, float* out, Ort::RunOptions& options,
    const int* next_indices = nullptr, int next_count = 0, int top_k = 0,
    uint32_t* next_code_points = nullptr, float* next_logps = nullptr) {
    std::vector<std::vector<int64_t>> encoded;
    size_t longest = 0;
    for (int i = 0; i < count; ++i) {
        encoded.push_back(CharLmEncode(h, texts[i]));
        longest = std::max(longest, encoded.back().size());
    }
    if (static_cast<int64_t>(longest) + 1 > h.block_size) return -1;
    auto context_ids = CharLmEncode(h, context);
    const size_t context_room = static_cast<size_t>(h.block_size) - 1 - longest;
    if (context_ids.size() > context_room)
        context_ids.erase(context_ids.begin(), context_ids.end() - static_cast<std::ptrdiff_t>(context_room));

    // Root chain: BOS, then the context.
    std::vector<int64_t> ids{kCharLmBos}, positions{0};
    std::vector<int32_t> parents{-1};
    for (int64_t token : context_ids) {
        parents.push_back(static_cast<int32_t>(ids.size()) - 1);
        positions.push_back(static_cast<int64_t>(ids.size()));
        ids.push_back(token);
    }
    const int32_t root = static_cast<int32_t>(ids.size()) - 1;
    std::unordered_map<uint64_t, int32_t> children;
    std::vector<std::vector<int32_t>> paths;
    for (int i = 0; i < count; ++i) {
        // Nodes this text would add; a text that does not fit ends the batch.
        size_t added = 0;
        int32_t node = root;
        const auto& text = encoded[static_cast<size_t>(i)];
        for (size_t t = 0; t < text.size(); ++t) {
            const uint64_t key = (static_cast<uint64_t>(node) << 32) | static_cast<uint32_t>(text[t]);
            const auto found = children.find(key);
            if (found == children.end()) {
                added = text.size() - t;
                break;
            }
            node = found->second;
        }
        const size_t limit = i < min_count ? kCharLmMaxNodes : std::min(max_nodes, kCharLmMaxNodes);
        if (ids.size() + added > limit) {
            if (i < min_count) return -1;
            break;
        }
        node = root;
        paths.emplace_back();
        for (int64_t token : text) {
            const uint64_t key = (static_cast<uint64_t>(node) << 32) | static_cast<uint32_t>(token);
            auto found = children.find(key);
            if (found == children.end()) {
                found = children.emplace(key, static_cast<int32_t>(ids.size())).first;
                parents.push_back(node);
                positions.push_back(positions[static_cast<size_t>(node)] + 1);
                ids.push_back(token);
            }
            node = found->second;
            paths.back().push_back(node);
        }
    }
    const size_t n = ids.size();
    std::vector<int32_t> mask(n * n, 0);
    for (size_t i = 0; i < n; ++i)
        for (int32_t j = static_cast<int32_t>(i); j >= 0; j = parents[static_cast<size_t>(j)])
            mask[i * n + static_cast<size_t>(j)] = 1;
    auto outputs = CharLmRun(h, ids, positions, mask, 0, nullptr, false, options);
    const float* logp = outputs[0].GetTensorData<float>();
    for (size_t i = 0; i < paths.size(); ++i) {
        double total = 0.0;
        for (int32_t node : paths[i])
            total += logp[static_cast<size_t>(parents[static_cast<size_t>(node)]) * static_cast<size_t>(h.vocab_size) +
                static_cast<size_t>(ids[static_cast<size_t>(node)])];
        out[i] = static_cast<float>(total);
    }
    for (int j = 0; j < next_count; ++j) {
        const int i = next_indices[j];
        uint32_t* cps = next_code_points + static_cast<size_t>(j) * static_cast<size_t>(top_k);
        float* lps = next_logps + static_cast<size_t>(j) * static_cast<size_t>(top_k);
        if (i < 0 || i >= static_cast<int>(paths.size()) || paths[static_cast<size_t>(i)].empty()) {
            std::fill(cps, cps + top_k, 0u);
            std::fill(lps, lps + top_k, 0.0f);
            continue;
        }
        const size_t node = static_cast<size_t>(paths[static_cast<size_t>(i)].back());
        CharLmTopNext(h, logp + node * static_cast<size_t>(h.vocab_size), top_k, cps, lps);
    }
    return static_cast<int>(paths.size());
}

// Greedy continuation over Han characters only; returns the number of characters.
int CharLmContinue(CharLmHandle& h, const wchar_t* context, const wchar_t* prefix, int max_chars,
    std::wstring& text, std::vector<float>& logps, Ort::RunOptions& options) {
    auto prefix_ids = CharLmEncode(h, prefix);
    auto context_ids = CharLmEncode(h, context);
    const int64_t fixed = 1 + static_cast<int64_t>(prefix_ids.size()) + max_chars;
    if (fixed > h.block_size) return -1;
    const size_t context_room = static_cast<size_t>(h.block_size - fixed);
    if (context_ids.size() > context_room)
        context_ids.erase(context_ids.begin(), context_ids.end() - static_cast<std::ptrdiff_t>(context_room));
    std::vector<int64_t> ids{kCharLmBos};
    ids.insert(ids.end(), context_ids.begin(), context_ids.end());
    ids.insert(ids.end(), prefix_ids.begin(), prefix_ids.end());
    std::vector<int64_t> positions(ids.size());
    for (size_t i = 0; i < positions.size(); ++i) positions[i] = static_cast<int64_t>(i);
    std::vector<int32_t> mask(ids.size() * ids.size(), 1);  // causal mask applies on top
    auto outputs = CharLmRun(h, ids, positions, mask, 0, nullptr, true, options);
    int64_t length = static_cast<int64_t>(ids.size());
    for (int step = 0; step < max_chars; ++step) {
        const float* row = outputs[0].GetTensorData<float>() +
            static_cast<size_t>(outputs[0].GetTensorTypeAndShapeInfo().GetShape()[1] - 1) *
            static_cast<size_t>(h.vocab_size);
        int64_t best = -1;
        for (int64_t id = 2; id < h.vocab_size; ++id)
            if (h.continuation_allowed[static_cast<size_t>(id)] && (best < 0 || row[id] > row[best])) best = id;
        if (best < 0) break;
        CharLmAppendUtf16(text, h.code_points[static_cast<size_t>(best - 2)]);
        logps.push_back(row[best]);
        if (step + 1 == max_chars) break;
        std::vector<Ort::Value> past;
        for (size_t i = 1; i < outputs.size(); ++i) past.push_back(std::move(outputs[i]));
        const std::vector<int64_t> next_ids{best}, next_positions{length};
        const std::vector<int32_t> next_mask(static_cast<size_t>(length + 1), 1);
        outputs = CharLmRun(h, next_ids, next_positions, next_mask, length, &past, true, options);
        ++length;
    }
    return static_cast<int>(logps.size());
}

// Correction of a draft with the pinyin-conditioned model (model consolidation,
// step 3). The prompt is BOS + context (the host's pinyin, draft marker, draft
// and separator); the corrected text follows it, one character per draft
// character, each from that position's allowed ids. One run scores the draft
// as the corrected text. When the best allowed character differs from the
// draft somewhere, a beam of `width` paths starts at the first such position
// and grows as a tree over the cached prompt and draft prefix, one run per
// position. Returns 0 when the model keeps the draft, 1 with the best text
// other than the draft and its log-probability gain over the draft, -1 on error.
int CharLmCorrect(CharLmHandle& h, const wchar_t* context, const wchar_t* draft,
    const std::vector<std::vector<int64_t>>& allowed, int width, std::wstring& out_text,
    float& out_gain, Ort::RunOptions& options) {
    const auto context_ids = CharLmEncode(h, context);
    const auto draft_ids = CharLmEncode(h, draft);
    const size_t n = draft_ids.size();
    if (n == 0 || allowed.size() != n || width < 1) return -1;
    const int64_t prompt = 1 + static_cast<int64_t>(context_ids.size());
    const int64_t total = prompt + static_cast<int64_t>(n);
    if (total > h.block_size) return -1;
    std::vector<int64_t> ids{kCharLmBos};
    ids.insert(ids.end(), context_ids.begin(), context_ids.end());
    ids.insert(ids.end(), draft_ids.begin(), draft_ids.end());
    std::vector<int64_t> positions(static_cast<size_t>(total));
    for (int64_t i = 0; i < total; ++i) positions[static_cast<size_t>(i)] = i;
    std::vector<int32_t> mask(static_cast<size_t>(total * total), 1);
    auto outputs = CharLmRun(h, ids, positions, mask, 0, nullptr, true, options);
    const int64_t vocab = h.vocab_size;
    const float* logp = outputs[0].GetTensorData<float>();
    auto row = [&](int64_t r) { return logp + static_cast<size_t>(r * vocab); };

    float draft_total = 0.0f;
    std::vector<float> draft_prefix(n + 1, 0.0f);
    size_t first = n, last = n;
    for (size_t t = 0; t < n; ++t) {
        const float* dist = row(prompt - 1 + static_cast<int64_t>(t));
        draft_prefix[t + 1] = draft_prefix[t] + dist[draft_ids[t]];
        int64_t best = -1;
        for (int64_t id : allowed[t])
            if (best < 0 || dist[id] > dist[best]) best = id;
        if (best >= 0 && best != draft_ids[t]) {
            if (first == n) first = t;
            last = t;
        }
    }
    draft_total = draft_prefix[n];
    if (first == n) return 0;

    // Keep the cache of the prompt and the draft before the first disagreement.
    const int64_t kept = prompt + static_cast<int64_t>(first);
    auto memory = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
    Ort::AllocatorWithDefaultOptions allocator;
    std::vector<Ort::Value> past;
    for (size_t i = 1; i < outputs.size(); ++i) {
        const auto shape = outputs[i].GetTensorTypeAndShapeInfo().GetShape();  // [2,1,H,T,D]
        const std::array<int64_t, 5> cut{shape[0], shape[1], shape[2], kept, shape[4]};
        Ort::Value value = Ort::Value::CreateTensor<float>(allocator, cut.data(), cut.size());
        const float* src = outputs[i].GetTensorData<float>();
        float* dst = value.GetTensorMutableData<float>();
        const int64_t blocks = shape[0] * shape[1] * shape[2];
        for (int64_t b = 0; b < blocks; ++b)
            std::memcpy(dst + b * kept * shape[4], src + b * shape[3] * shape[4],
                sizeof(float) * static_cast<size_t>(kept * shape[4]));
        past.push_back(std::move(value));
    }

    struct Beam { std::vector<int64_t> tokens; std::vector<int64_t> nodes; float score; };
    auto expand = [&](const std::vector<Beam>& beams, const std::vector<const float*>& dists, size_t t) {
        std::vector<std::pair<float, std::pair<size_t, int64_t>>> options_list;
        for (size_t j = 0; j < beams.size(); ++j)
            for (int64_t id : allowed[t])
                options_list.push_back({beams[j].score + dists[j][id], {j, id}});
        const size_t keep = std::min(options_list.size(), static_cast<size_t>(width));
        std::partial_sort(options_list.begin(), options_list.begin() + keep, options_list.end(),
            [](const auto& a, const auto& b) { return a.first > b.first; });
        std::vector<Beam> next;
        for (size_t k = 0; k < keep; ++k) {
            Beam beam = beams[options_list[k].second.first];
            beam.tokens.push_back(options_list[k].second.second);
            beam.score = options_list[k].first;
            next.push_back(std::move(beam));
        }
        return next;
    };
    std::vector<Beam> beams{{{}, {}, draft_prefix[first]}};
    beams = expand(beams, {row(prompt - 1 + static_cast<int64_t>(first))}, first);
    int64_t cached = kept;
    // Once every path is back on the draft for two characters and the draft
    // has no later disagreement, each path finishes with the draft: one run
    // scores those suffixes instead of one run per remaining position.
    auto rejoined = [&](size_t t) {
        if (t <= last || t + 1 >= n || t < first + 2) return false;
        for (const auto& beam : beams) {
            const size_t k = beam.tokens.size();
            if (k < 2 || beam.tokens[k - 1] != draft_ids[t] || beam.tokens[k - 2] != draft_ids[t - 1]) return false;
        }
        return true;
    };
    for (size_t t = first + 1; t < n && !beams.empty(); ++t) {
        if (rejoined(t - 1)) {
            // Nodes per path: its last character (position t - 1), then the draft
            // up to position n - 2; node k predicts position t + k.
            const int64_t chain = static_cast<int64_t>(n - t);
            const int64_t s = static_cast<int64_t>(beams.size()) * chain;
            std::vector<int64_t> step_ids, step_positions;
            std::vector<int32_t> step_mask(static_cast<size_t>(s * (cached + s)), 0);
            for (size_t j = 0; j < beams.size(); ++j) {
                for (int64_t k = 0; k < chain; ++k) {
                    const int64_t node = static_cast<int64_t>(j) * chain + k;
                    step_ids.push_back(k == 0 ? beams[j].tokens.back() : draft_ids[t - 1 + static_cast<size_t>(k)]);
                    step_positions.push_back(prompt + static_cast<int64_t>(t) - 1 + k);
                    int32_t* m = step_mask.data() + node * (cached + s);
                    for (int64_t c = 0; c < kept; ++c) m[c] = 1;
                    for (int64_t prior : beams[j].nodes) m[prior] = 1;
                    for (int64_t q = 0; q <= k; ++q) m[cached + static_cast<int64_t>(j) * chain + q] = 1;
                }
            }
            auto step = CharLmRun(h, step_ids, step_positions, step_mask, cached, &past, false, options);
            const float* step_logp = step[0].GetTensorData<float>();
            for (size_t j = 0; j < beams.size(); ++j) {
                for (int64_t k = 0; k < chain; ++k) {
                    const size_t target = t + static_cast<size_t>(k);
                    const float* dist = step_logp + static_cast<size_t>((static_cast<int64_t>(j) * chain + k) * vocab);
                    beams[j].score += dist[draft_ids[target]];
                    beams[j].tokens.push_back(draft_ids[target]);
                }
            }
            break;
        }
        const int64_t s = static_cast<int64_t>(beams.size());
        std::vector<int64_t> step_ids, step_positions;
        std::vector<int32_t> step_mask(static_cast<size_t>(s * (cached + s)), 0);
        for (int64_t j = 0; j < s; ++j) {
            Beam& beam = beams[static_cast<size_t>(j)];
            step_ids.push_back(beam.tokens.back());
            step_positions.push_back(prompt + static_cast<int64_t>(t) - 1);
            int32_t* m = step_mask.data() + j * (cached + s);
            for (int64_t c = 0; c < kept; ++c) m[c] = 1;
            for (int64_t node : beam.nodes) m[node] = 1;
            m[cached + j] = 1;
            beam.nodes.push_back(cached + j);
        }
        auto step = CharLmRun(h, step_ids, step_positions, step_mask, cached, &past, true, options);
        past.clear();
        for (size_t i = 1; i < step.size(); ++i) past.push_back(std::move(step[i]));
        cached += s;
        const float* step_logp = step[0].GetTensorData<float>();
        std::vector<const float*> dists;
        for (int64_t j = 0; j < s; ++j) dists.push_back(step_logp + static_cast<size_t>(j * vocab));
        beams = expand(beams, dists, t);
    }
    const Beam* best = nullptr;
    for (const auto& beam : beams) {
        bool same = true;
        for (size_t k = 0; k < beam.tokens.size(); ++k) same = same && beam.tokens[k] == draft_ids[first + k];
        if (!same && (!best || beam.score > best->score)) best = &beam;
    }
    if (!best) return 0;
    out_text.clear();
    for (size_t t = 0; t < first; ++t)
        CharLmAppendUtf16(out_text, h.code_points[static_cast<size_t>(draft_ids[t] - 2)]);
    for (int64_t id : best->tokens) CharLmAppendUtf16(out_text, h.code_points[static_cast<size_t>(id - 2)]);
    out_gain = best->score - draft_total;
    return 1;
}

}  // namespace

extern "C" __declspec(dllexport) void* __cdecl nc_lm_create(
    const wchar_t* directory, int intra_threads, wchar_t* error, int capacity) {
    SetError(error, capacity, L"");
    try {
        if (!directory || !*directory) throw std::runtime_error("missing character LM directory");
        FloatingPointMaskGuard fp;
        const std::lock_guard<std::mutex> lock(InitializationMutex());
        Ort::InitApi();
        auto h = std::make_unique<CharLmHandle>();
        CharLmLoadVocabulary(directory, *h);
        Ort::SessionOptions options;
        options.SetExecutionMode(ORT_SEQUENTIAL);
        options.SetIntraOpNumThreads(std::max(1, intra_threads));
        options.SetInterOpNumThreads(1);
        // Sessions share the host CPU with lattice decoding and each other.
        options.AddConfigEntry("session.force_spinning_stop", "1");
        UseReleasableInitializers(options);
        options.SetGraphOptimizationLevel(ORT_ENABLE_ALL);
        const std::wstring path = std::wstring(directory) + L"\\char_lm.onnx";
        const std::wstring key = CharLmSessionKey(path);
        h->session = CharLmSessions()[key].lock();
        if (!h->session) {
            h->session = std::make_shared<Ort::Session>(Environment(), path.c_str(), options);
            CharLmSessions()[key] = h->session;
        }
        Ort::AllocatorWithDefaultOptions allocator;
        for (size_t i = 0; i < h->session->GetInputCount(); ++i)
            h->input_names.emplace_back(h->session->GetInputNameAllocated(i, allocator).get());
        for (size_t i = 0; i < h->session->GetOutputCount(); ++i)
            h->output_names.emplace_back(h->session->GetOutputNameAllocated(i, allocator).get());
        if (h->input_names.size() < 4 || h->input_names[0] != "ids" || h->input_names[1] != "positions" ||
            h->input_names[2] != "attention_mask" || h->output_names.empty() || h->output_names[0] != "logp_all" ||
            h->input_names.size() - 3 != h->output_names.size() - 1)
            throw std::runtime_error("unexpected character LM graph signature");
        h->layers = static_cast<int64_t>(h->input_names.size() - 3);
        const auto past_shape = h->session->GetInputTypeInfo(3).GetTensorTypeAndShapeInfo().GetShape();
        const auto logp_shape = h->session->GetOutputTypeInfo(0).GetTensorTypeAndShapeInfo().GetShape();
        if (past_shape.size() != 5 || past_shape[2] <= 0 || past_shape[4] <= 0 ||
            logp_shape.size() != 3 || logp_shape[2] != h->vocab_size)
            throw std::runtime_error("character LM graph does not match its vocabulary");
        h->heads = past_shape[2];
        h->head_dim = past_shape[4];
        return h.release();
    } catch (const std::exception& e) { SetError(error, capacity, Utf8ToWide(e.what())); }
    catch (...) { SetError(error, capacity, L"character LM initialization failed"); }
    return nullptr;
}

extern "C" __declspec(dllexport) void __cdecl nc_lm_destroy(void* handle) {
    FloatingPointMaskGuard fp;
    delete static_cast<CharLmHandle*>(handle);
}

// Scores texts in order while the packed trie stays within max_nodes (<= 0: the
// runtime limit); the first min_count texts are always scored. Writes one value
// per scored text and returns how many were scored; -1 when busy, invalid, too
// large or past the deadline.
extern "C" __declspec(dllexport) int __cdecl nc_lm_score(void* handle, const wchar_t* context,
    const wchar_t* const* texts, int count, int min_count, int max_nodes, float* out_logp,
    int timeout_ms, wchar_t* error, int capacity) {
    SetError(error, capacity, L"");
    try {
        if (!handle || !texts || !out_logp || count <= 0 || count > kCharLmMaxTexts ||
            min_count < 1 || min_count > count) return -1;
        for (int i = 0; i < count; ++i)
            if (!texts[i] || !*texts[i]) return -1;
        auto& h = *static_cast<CharLmHandle*>(handle);
        std::unique_lock<std::mutex> lock(h.mutex, std::try_to_lock);
        if (!lock.owns_lock()) return -1;
        FloatingPointMaskGuard fp;
        Ort::RunOptions options;
        CharLmDeadline deadline(options, timeout_ms);
        const size_t node_limit = max_nodes > 0 ? static_cast<size_t>(max_nodes) : kCharLmMaxNodes;
        return CharLmScore(h, context ? context : L"", texts, count, min_count, node_limit, out_logp, options);
    } catch (const std::exception& e) { SetError(error, capacity, Utf8ToWide(e.what())); }
    catch (...) { SetError(error, capacity, L"character LM scoring failed"); }
    return -1;
}

// nc_lm_score, and for each of next_count text indices the top_k Han characters
// (code points, best first) that follow it, with their log-probabilities, at
// next_index * top_k. A text that was not scored gets code point 0.
extern "C" __declspec(dllexport) int __cdecl nc_lm_score_next(void* handle, const wchar_t* context,
    const wchar_t* const* texts, int count, int min_count, int max_nodes, float* out_logp,
    const int* next_indices, int next_count, int top_k, uint32_t* out_next_code_points,
    float* out_next_logp, int timeout_ms, wchar_t* error, int capacity) {
    SetError(error, capacity, L"");
    try {
        if (!handle || !texts || !out_logp || count <= 0 || count > kCharLmMaxTexts ||
            min_count < 1 || min_count > count || next_count < 0 || next_count > count ||
            (next_count > 0 && (!next_indices || !out_next_code_points || !out_next_logp ||
            top_k < 1 || top_k > 32))) return -1;
        for (int i = 0; i < count; ++i)
            if (!texts[i] || !*texts[i]) return -1;
        auto& h = *static_cast<CharLmHandle*>(handle);
        std::unique_lock<std::mutex> lock(h.mutex, std::try_to_lock);
        if (!lock.owns_lock()) return -1;
        FloatingPointMaskGuard fp;
        Ort::RunOptions options;
        CharLmDeadline deadline(options, timeout_ms);
        const size_t node_limit = max_nodes > 0 ? static_cast<size_t>(max_nodes) : kCharLmMaxNodes;
        return CharLmScore(h, context ? context : L"", texts, count, min_count, node_limit, out_logp, options,
            next_indices, next_count, next_count > 0 ? top_k : 0, out_next_code_points, out_next_logp);
    } catch (const std::exception& e) { SetError(error, capacity, Utf8ToWide(e.what())); }
    catch (...) { SetError(error, capacity, L"character LM scoring failed"); }
    return -1;
}

// Greedy Han-only continuation of prefix after context. Writes up to max_chars
// characters (UTF-16, NUL-terminated) and each character's log-probability
// under the full distribution. Returns the character count or -1.
extern "C" __declspec(dllexport) int __cdecl nc_lm_continue(void* handle, const wchar_t* context,
    const wchar_t* prefix, int max_chars, wchar_t* out_text, int out_capacity, float* out_logp,
    int timeout_ms, wchar_t* error, int capacity) {
    SetError(error, capacity, L"");
    try {
        if (!handle || !prefix || !out_text || !out_logp || max_chars <= 0 || max_chars > 32 ||
            out_capacity < 2 * max_chars + 1) return -1;
        out_text[0] = L'\0';
        auto& h = *static_cast<CharLmHandle*>(handle);
        std::unique_lock<std::mutex> lock(h.mutex, std::try_to_lock);
        if (!lock.owns_lock()) return -1;
        FloatingPointMaskGuard fp;
        Ort::RunOptions options;
        CharLmDeadline deadline(options, timeout_ms);
        std::wstring text;
        std::vector<float> logps;
        const int produced = CharLmContinue(h, context ? context : L"", prefix, max_chars, text, logps, options);
        if (produced < 0) return -1;
        std::wmemcpy(out_text, text.data(), text.size());
        out_text[text.size()] = L'\0';
        std::copy(logps.begin(), logps.end(), out_logp);
        return produced;
    } catch (const std::exception& e) { SetError(error, capacity, Utf8ToWide(e.what())); }
    catch (...) { SetError(error, capacity, L"character LM continuation failed"); }
    return -1;
}

// Draft correction for the pinyin-conditioned model (see CharLmCorrect). allowed
// lists the code points each draft character may become, as one array with
// draft_length + 1 offsets; characters outside the vocabulary are skipped.
// Writes the corrected text (UTF-16, NUL-terminated) and its gain; returns 1,
// 0 when the draft is kept, or -1.
extern "C" __declspec(dllexport) int __cdecl nc_lm_correct(void* handle, const wchar_t* context,
    const wchar_t* draft, const uint32_t* allowed_code_points, const int* allowed_offsets,
    int width, wchar_t* out_text, int out_capacity, float* out_gain, int timeout_ms,
    wchar_t* error, int capacity) {
    SetError(error, capacity, L"");
    try {
        if (!handle || !draft || !allowed_code_points || !allowed_offsets || !out_text || !out_gain ||
            width < 1 || width > 16 || out_capacity < 2) return -1;
        out_text[0] = L'\0';
        auto& h = *static_cast<CharLmHandle*>(handle);
        const size_t n = CharLmEncode(h, draft).size();
        std::vector<std::vector<int64_t>> allowed(n);
        for (size_t t = 0; t < n; ++t) {
            for (int k = allowed_offsets[t]; k < allowed_offsets[t + 1]; ++k) {
                const auto found = h.vocabulary.find(allowed_code_points[k]);
                if (found != h.vocabulary.end()) allowed[t].push_back(found->second);
            }
        }
        std::unique_lock<std::mutex> lock(h.mutex, std::try_to_lock);
        if (!lock.owns_lock()) return -1;
        FloatingPointMaskGuard fp;
        Ort::RunOptions options;
        CharLmDeadline deadline(options, timeout_ms);
        std::wstring text;
        float gain = 0.0f;
        const int result = CharLmCorrect(h, context ? context : L"", draft, allowed, width, text, gain, options);
        if (result != 1) return result;
        if (static_cast<int>(text.size()) + 1 > out_capacity) return -1;
        std::wmemcpy(out_text, text.data(), text.size());
        out_text[text.size()] = L'\0';
        *out_gain = gain;
        return 1;
    } catch (const std::exception& e) { SetError(error, capacity, Utf8ToWide(e.what())); }
    catch (...) { SetError(error, capacity, L"character LM correction failed"); }
    return -1;
}

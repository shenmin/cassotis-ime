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
    std::unique_ptr<Ort::Session> session;
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
        h->session = std::make_unique<Ort::Session>(Environment(), path.c_str(), options);
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

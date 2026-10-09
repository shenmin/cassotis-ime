// Shared character language model (nc_lm_*). Included after
// the ORT helpers.
//
// The graph (tools/char_lm_onnx.py) takes ids, positions, an attention mask that
// is combined with the causal mask, and per layer the keys and values of
// earlier tokens; it returns those of the new tokens. Scoring packs the
// candidates into one trie (every node after its ancestors, position = depth,
// mask = ancestors only), so shared prefixes are computed once and every
// candidate gets exactly the log-probability of a separate run: the model's
// activations have fixed ranges and its attention (nc_trie_attention.inc)
// computes a token from its own chain alone, so a token's output is the same
// bits whatever else a run holds and wherever the run puts it. A scoring call
// therefore keeps the tokens it computed, and a later call runs only the ones
// it does not find among them (CharLmMemo).
namespace {

constexpr int64_t kCharLmBos = 0;
constexpr int64_t kCharLmUnknown = 1;
constexpr size_t kCharLmMaxNodes = 1024;
constexpr int kCharLmMaxTexts = 256;
// Tokens a handle keeps between scoring calls (about 90 KiB each: eleven
// layers of keys and values).
constexpr size_t kCharLmMemoCapacity = 384;

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

// Keys and values of tokens kept between graph runs: one buffer per layer in
// the layout the attention operator reads, [2][heads][capacity][head size]. A
// run gets the whole buffer as its past and names in its mask the tokens it
// sees; a slot that holds nothing is named by no mask and never read.
class CharLmKeys {
    int64_t heads_{}, head_dim_{};
    size_t capacity_{}, count_{};
    std::vector<std::unique_ptr<float[]>> layers_;

    size_t LayerSize() const {
        return static_cast<size_t>(2 * heads_) * capacity_ * static_cast<size_t>(head_dim_);
    }

public:
    size_t count() const { return count_; }
    size_t capacity() const { return capacity_; }

    // Empties the store and makes room for at least `capacity` tokens.
    void Reset(int64_t layers, int64_t heads, int64_t head_dim, size_t capacity) {
        count_ = 0;
        if (layers_.size() == static_cast<size_t>(layers) && heads_ == heads && head_dim_ == head_dim &&
            capacity_ >= capacity) return;
        layers_.clear();
        heads_ = heads;
        head_dim_ = head_dim;
        capacity_ = capacity;
        for (int64_t layer = 0; layer < layers; ++layer)
            layers_.emplace_back(new float[LayerSize()]);
    }

    void Truncate(size_t count) { count_ = std::min(count_, count); }

    // Appends the rows `taken` of a run of `rows` tokens; outputs[1..] are its
    // per-layer keys and values, [2, 1, heads, rows, head size].
    void Append(const std::vector<Ort::Value>& outputs, size_t rows, const std::vector<size_t>& taken) {
        if (outputs.size() != layers_.size() + 1) throw std::runtime_error("character LM run without its cache");
        if (count_ + taken.size() > capacity_) throw std::runtime_error("character LM cache is full");
        const size_t dim = static_cast<size_t>(head_dim_), blocks = static_cast<size_t>(2 * heads_);
        for (size_t layer = 0; layer < layers_.size(); ++layer) {
            const auto shape = outputs[layer + 1].GetTensorTypeAndShapeInfo().GetShape();
            if (shape.size() != 5 || shape[0] != 2 || shape[1] != 1 || shape[2] != heads_ ||
                shape[3] != static_cast<int64_t>(rows) || shape[4] != head_dim_)
                throw std::runtime_error("unexpected character LM cache shape");
            const float* source = outputs[layer + 1].GetTensorData<float>();
            float* target = layers_[layer].get();
            for (size_t block = 0; block < blocks; ++block)
                for (size_t k = 0; k < taken.size(); ++k)
                    std::memcpy(target + (block * capacity_ + count_ + k) * dim,
                        source + (block * rows + taken[k]) * dim, sizeof(float) * dim);
        }
        count_ += taken.size();
    }

    // Keeps the listed tokens (ascending); they become tokens 0, 1, ...
    void Keep(const std::vector<int32_t>& kept) {
        const size_t dim = static_cast<size_t>(head_dim_), blocks = static_cast<size_t>(2 * heads_);
        for (auto& layer : layers_) {
            for (size_t block = 0; block < blocks; ++block) {
                float* rows = layer.get() + block * capacity_ * dim;
                for (size_t k = 0; k < kept.size(); ++k)
                    if (static_cast<size_t>(kept[k]) != k)
                        std::memcpy(rows + k * dim, rows + static_cast<size_t>(kept[k]) * dim, sizeof(float) * dim);
            }
        }
        count_ = kept.size();
    }

    // The buffers as the past of a run.
    std::vector<Ort::Value> Past() {
        auto memory = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
        const std::array<int64_t, 5> shape{2, 1, heads_, static_cast<int64_t>(capacity_), head_dim_};
        std::vector<Ort::Value> past;
        for (auto& layer : layers_)
            past.push_back(Ort::Value::CreateTensor<float>(memory, layer.get(), LayerSize(), shape.data(),
                shape.size()));
        return past;
    }
};

// The tokens of a handle's earlier scoring calls, as a trie below BOS: each
// with its log-probability after its ancestors and, in `keys`, what a later
// token needs to attend to it. A token's numbers do not depend on the run that
// computed them, so a call that finds its tokens here gets the scores of a
// run of its own, bit for bit.
struct CharLmMemo {
    struct Node {
        int64_t token;
        int32_t parent;    // -1 for BOS
        int32_t position;
        float logp;
    };
    std::vector<Node> nodes;  // each after its ancestors; node k is token k of `keys`
    std::unordered_map<uint64_t, int32_t> children;
    CharLmKeys keys;
    // The keys and values of the newest nodes (those from keys.count() on) are
    // not copied into `keys` when their run ends: they wait in the run's
    // outputs. The next call settles them: it takes over the ones it uses and
    // forgets the others, so a call that nothing follows up on costs no copy.
    std::vector<Ort::Value> waiting;
    size_t waiting_rows{};            // tokens of that run
    std::vector<size_t> waiting_row;  // the run's row of node keys.count() + k

    static uint64_t ChildKey(int32_t parent, int64_t token) {
        return (static_cast<uint64_t>(static_cast<uint32_t>(parent + 1)) << 32) | static_cast<uint32_t>(token);
    }

    void Clear() {
        nodes.clear();
        children.clear();
        keys.Truncate(0);
        waiting.clear();
        waiting_row.clear();
    }

    void Index() {
        children.clear();
        for (size_t i = 0; i < nodes.size(); ++i)
            children.emplace(ChildKey(nodes[i].parent, nodes[i].token), static_cast<int32_t>(i));
    }

    // Brings the waiting nodes that `used` marks into `keys` and forgets the
    // other waiting nodes (a node's ancestors are marked with it).
    void Settle(const std::vector<uint8_t>& used) {
        const size_t settled = keys.count();
        std::vector<size_t> taken;
        std::vector<int32_t> renumbered(nodes.size(), -1);
        std::vector<Node> remaining(nodes.begin(), nodes.begin() + static_cast<std::ptrdiff_t>(settled));
        for (size_t i = 0; i < settled; ++i) renumbered[i] = static_cast<int32_t>(i);
        for (size_t i = settled; i < nodes.size(); ++i) {
            if (!used[i]) continue;
            renumbered[i] = static_cast<int32_t>(remaining.size());
            taken.push_back(waiting_row[i - settled]);
            Node node = nodes[i];
            if (node.parent >= 0) node.parent = renumbered[static_cast<size_t>(node.parent)];
            remaining.push_back(node);
        }
        if (!taken.empty()) keys.Append(waiting, waiting_rows, taken);
        nodes.swap(remaining);
        Index();
        waiting.clear();
        waiting_row.clear();
    }

    // Keeps the nodes marked in `used` (a node's ancestors are marked with it).
    void Keep(const std::vector<uint8_t>& used) {
        std::vector<int32_t> kept, renumbered(nodes.size(), -1);
        std::vector<Node> remaining;
        for (size_t i = 0; i < nodes.size(); ++i) {
            if (!used[i]) continue;
            renumbered[i] = static_cast<int32_t>(kept.size());
            kept.push_back(static_cast<int32_t>(i));
            Node node = nodes[i];
            if (node.parent >= 0) node.parent = renumbered[static_cast<size_t>(node.parent)];
            remaining.push_back(node);
        }
        nodes.swap(remaining);
        Index();
        keys.Keep(kept);
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
    // What the scoring calls keep between them (CharLmScore), the chain of
    // the last correction with its keys and values (CharLmCorrect), and the
    // cache of one continuation. Of the correction's chain the first
    // correction_settled tokens are in `correction`; the rest wait in the
    // outputs of the run that computed them, as in the memo.
    CharLmMemo memo;
    bool memo_enabled{true};
    std::vector<int64_t> correction_chain;
    CharLmKeys correction;
    size_t correction_settled{};
    std::vector<Ort::Value> correction_waiting;
    size_t correction_waiting_rows{};
    CharLmKeys scratch;
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

// Runs the graph. past may be null (no earlier tokens). Returns logp_all, and
// the per-layer keys and values of the run's tokens when want_presents is set.
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
//
// The trie is looked up in the handle's memo first. Only the tokens it lacks
// are run, against the kept keys and values of their ancestors, together with
// the kept tokens whose distribution the call needs (the parent of a new
// token, the end of a text whose next characters are asked for); a call that
// finds everything runs nothing. The node budget counts the call's own trie,
// whatever the memo holds, so the texts taken do not depend on earlier calls.
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
    const size_t root_chain = 1 + context_ids.size();
    const size_t vocab = static_cast<size_t>(h.vocab_size);

    CharLmMemo& memo = h.memo;
    if (!h.memo_enabled) memo.Clear();
    if (memo.keys.capacity() == 0) memo.keys.Reset(h.layers, h.heads, h.head_dim, kCharLmMemoCapacity);
    // Laid out again after the memo changed under the call: once its waiting
    // nodes are settled, and once it has been cut down to the tokens the call
    // uses because it had no room for the new ones.
    for (bool cut = false;;) {
        const int32_t kept = static_cast<int32_t>(memo.nodes.size());
        // The call's tokens that the memo lacks, numbered after the kept ones.
        std::vector<CharLmMemo::Node> fresh;
        std::unordered_map<uint64_t, int32_t> fresh_children;
        std::vector<uint8_t> used(static_cast<size_t>(kept), 0);  // on a path of this call
        auto node_at = [&](int32_t i) -> const CharLmMemo::Node& {
            return i < kept ? memo.nodes[static_cast<size_t>(i)] : fresh[static_cast<size_t>(i - kept)];
        };
        auto find = [&](int32_t parent, int64_t token) {
            const uint64_t key = CharLmMemo::ChildKey(parent, token);
            const auto known = memo.children.find(key);
            if (known != memo.children.end()) return known->second;
            const auto added = fresh_children.find(key);
            return added == fresh_children.end() ? -1 : added->second;
        };
        auto step = [&](int32_t parent, int64_t token) {
            int32_t node = find(parent, token);
            if (node < 0) {
                node = kept + static_cast<int32_t>(fresh.size());
                const int32_t position = parent < 0 ? 0 : node_at(parent).position + 1;
                fresh.push_back({token, parent, position, 0.0f});
                fresh_children.emplace(CharLmMemo::ChildKey(parent, token), node);
                used.push_back(0);
            }
            used[static_cast<size_t>(node)] = 1;
            return node;
        };

        // The root chain is BOS, then the context; the trie hangs below its last token.
        int32_t root = step(-1, kCharLmBos);
        for (int64_t token : context_ids) root = step(root, token);
        std::vector<std::vector<int32_t>> paths;
        size_t trie_nodes = 0;
        for (int i = 0; i < count; ++i) {
            // Nodes this text would add to the call's trie; a text that does not fit ends the batch.
            size_t added = 0;
            int32_t node = root;
            const auto& text = encoded[static_cast<size_t>(i)];
            for (size_t t = 0; t < text.size(); ++t) {
                const int32_t next = find(node, text[t]);
                if (next < 0 || !used[static_cast<size_t>(next)]) {
                    added = text.size() - t;
                    break;
                }
                node = next;
            }
            const size_t limit = i < min_count ? kCharLmMaxNodes : std::min(max_nodes, kCharLmMaxNodes);
            if (root_chain + trie_nodes + added > limit) {
                if (i < min_count) return -1;
                break;
            }
            node = root;
            paths.emplace_back();
            for (int64_t token : text) {
                node = step(node, token);
                paths.back().push_back(node);
            }
            trie_nodes += added;
        }

        if (!memo.waiting.empty()) {
            used.resize(static_cast<size_t>(kept));
            memo.Settle(used);
            continue;
        }
        if (!cut && static_cast<size_t>(kept) + fresh.size() > memo.keys.capacity()) {
            used.resize(static_cast<size_t>(kept));
            if (std::find(used.begin(), used.end(), uint8_t{0}) != used.end()) {
                memo.Keep(used);
                cut = true;
                continue;
            }
        }
        // A call too large to keep is run against what is kept and leaves no trace.
        const bool store = static_cast<size_t>(kept) + fresh.size() <= memo.keys.capacity();

        // A kept token is run again where the call needs its distribution.
        std::vector<uint8_t> again(static_cast<size_t>(kept), 0);
        for (const auto& node : fresh)
            if (node.parent >= 0 && node.parent < kept) again[static_cast<size_t>(node.parent)] = 1;
        for (int j = 0; j < next_count; ++j) {
            const int i = next_indices[j];
            if (i < 0 || i >= static_cast<int>(paths.size()) || paths[static_cast<size_t>(i)].empty()) continue;
            const int32_t last = paths[static_cast<size_t>(i)].back();
            if (last < kept) again[static_cast<size_t>(last)] = 1;
        }
        std::vector<int32_t> row_of(static_cast<size_t>(kept) + fresh.size(), -1);
        std::vector<int32_t> row_nodes;
        for (int32_t i = 0; i < kept; ++i)
            if (again[static_cast<size_t>(i)]) {
                row_of[static_cast<size_t>(i)] = static_cast<int32_t>(row_nodes.size());
                row_nodes.push_back(i);
            }
        const size_t first_fresh = row_nodes.size();
        for (size_t k = 0; k < fresh.size(); ++k) {
            row_of[static_cast<size_t>(kept) + k] = static_cast<int32_t>(row_nodes.size());
            row_nodes.push_back(kept + static_cast<int32_t>(k));
        }

        std::vector<Ort::Value> outputs;
        const float* logp = nullptr;
        const size_t rows = row_nodes.size();
        if (rows > 0) {
            // A row sees itself as a token of this run and its ancestors where they are:
            // the kept ones in the memo (also one that is run again), the new ones in the run.
            const size_t past_width = kept > 0 ? memo.keys.capacity() : 0;
            std::vector<int64_t> ids(rows), positions(rows);
            std::vector<int32_t> mask(rows * (past_width + rows), 0);
            for (size_t r = 0; r < rows; ++r) {
                const auto& node = node_at(row_nodes[r]);
                ids[r] = node.token;
                positions[r] = node.position;
                int32_t* line = mask.data() + r * (past_width + rows);
                line[past_width + r] = 1;
                for (int32_t a = node.parent; a >= 0; a = node_at(a).parent)
                    line[a < kept ? static_cast<size_t>(a)
                         : past_width + static_cast<size_t>(row_of[static_cast<size_t>(a)])] = 1;
            }
            const bool want_keys = store && !fresh.empty();
            if (past_width > 0) {
                auto past = memo.keys.Past();
                outputs = CharLmRun(h, ids, positions, mask, static_cast<int64_t>(past_width), &past, want_keys,
                    options);
            } else {
                outputs = CharLmRun(h, ids, positions, mask, 0, nullptr, want_keys, options);
            }
            logp = outputs[0].GetTensorData<float>();
        }
        for (auto& node : fresh)
            if (node.parent >= 0)
                node.logp = logp[static_cast<size_t>(row_of[static_cast<size_t>(node.parent)]) * vocab +
                    static_cast<size_t>(node.token)];

        for (size_t i = 0; i < paths.size(); ++i) {
            double total = 0.0;
            for (int32_t node : paths[i]) total += node_at(node).logp;
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
            const size_t row = static_cast<size_t>(row_of[static_cast<size_t>(paths[static_cast<size_t>(i)].back())]);
            CharLmTopNext(h, logp + row * vocab, top_k, cps, lps);
        }

        if (store && !fresh.empty()) {
            // The new nodes join the memo; their keys and values wait in the outputs.
            try {
                memo.waiting_row.resize(fresh.size());
                for (size_t k = 0; k < fresh.size(); ++k) {
                    memo.waiting_row[k] = first_fresh + k;
                    memo.children.emplace(CharLmMemo::ChildKey(fresh[k].parent, fresh[k].token),
                        kept + static_cast<int32_t>(k));
                    memo.nodes.push_back(fresh[k]);
                }
                memo.waiting_rows = rows;
                outputs[0] = Ort::Value(nullptr);  // the distributions have been read
                memo.waiting = std::move(outputs);
            } catch (...) {
                memo.Clear();
                throw;
            }
        }
        return static_cast<int>(paths.size());
    }
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
    CharLmKeys& keys = h.scratch;
    keys.Reset(h.layers, h.heads, h.head_dim, ids.size() + static_cast<size_t>(max_chars));
    std::vector<size_t> every(ids.size());
    for (size_t i = 0; i < every.size(); ++i) every[i] = i;
    keys.Append(outputs, ids.size(), every);
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
        const std::vector<int64_t> next_ids{best}, next_positions{length};
        // Every kept token, and the new one itself (behind the buffer's width).
        std::vector<int32_t> next_mask(keys.capacity() + 1, 0);
        std::fill(next_mask.begin(), next_mask.begin() + static_cast<std::ptrdiff_t>(keys.count()), 1);
        next_mask[keys.capacity()] = 1;
        auto past = keys.Past();
        outputs = CharLmRun(h, next_ids, next_positions, next_mask, static_cast<int64_t>(keys.capacity()), &past,
            true, options);
        keys.Append(outputs, 1, {0});
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
    // The handle keeps the chain of its last correction with its keys and
    // values. While a sentence is typed the next chain begins the same (the
    // context and the syllables so far), so only the rest is run; a token's
    // numbers are the same either way. The rows from the last prompt token on
    // are needed below and always run.
    CharLmKeys& keys = h.correction;
    const size_t needed = static_cast<size_t>(total) + static_cast<size_t>(width) * n;
    if (keys.capacity() < needed) {
        keys.Reset(h.layers, h.heads, h.head_dim, needed);
        h.correction_chain.clear();
        h.correction_waiting.clear();
    }
    const int64_t room = static_cast<int64_t>(keys.capacity());
    size_t common = 0;
    if (h.memo_enabled)
        while (common < h.correction_chain.size() && common < static_cast<size_t>(prompt - 1) &&
            h.correction_chain[common] == ids[common]) ++common;
    if (common > h.correction_settled) {
        // The shared tokens beyond the settled ones wait in the previous run's outputs.
        keys.Truncate(h.correction_settled);
        std::vector<size_t> taken(common - h.correction_settled);
        for (size_t k = 0; k < taken.size(); ++k) taken[k] = k;
        keys.Append(h.correction_waiting, h.correction_waiting_rows, taken);
    } else {
        keys.Truncate(common);
    }
    h.correction_chain.clear();
    h.correction_waiting.clear();
    const int64_t shared = static_cast<int64_t>(common), run = total - shared;
    const std::vector<int64_t> run_ids(ids.begin() + shared, ids.end());
    const std::vector<int64_t> run_positions(positions.begin() + shared, positions.end());
    const int64_t past_width = shared > 0 ? room : 0;
    std::vector<int32_t> mask(static_cast<size_t>(run * (past_width + run)), 0);
    for (int64_t r = 0; r < run; ++r) {
        int32_t* line = mask.data() + r * (past_width + run);
        std::fill(line, line + shared, 1);
        std::fill(line + past_width, line + past_width + r + 1, 1);
    }
    std::vector<Ort::Value> outputs;
    if (shared > 0) {
        auto past = keys.Past();
        outputs = CharLmRun(h, run_ids, run_positions, mask, past_width, &past, true, options);
    } else {
        outputs = CharLmRun(h, run_ids, run_positions, mask, 0, nullptr, true, options);
    }
    const int64_t vocab = h.vocab_size;
    const float* logp = outputs[0].GetTensorData<float>();
    auto row = [&](int64_t r) { return logp + static_cast<size_t>((r - shared) * vocab); };

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
    h.correction_chain = ids;
    if (first == n) {
        // No search: the run's keys and values wait for the next correction.
        h.correction_settled = common;
        h.correction_waiting_rows = static_cast<size_t>(run);
        outputs[0] = Ort::Value(nullptr);
        h.correction_waiting = std::move(outputs);
        return 0;
    }
    // The search below reads the chain's keys and values, so they are copied now.
    std::vector<size_t> every(static_cast<size_t>(run));
    for (size_t i = 0; i < every.size(); ++i) every[i] = i;
    keys.Append(outputs, static_cast<size_t>(run), every);
    h.correction_settled = static_cast<size_t>(total);

    // The beams grow over the prompt and the draft before the first
    // disagreement (the first `kept` tokens of the chain); every step appends
    // its tokens behind the chain.
    const int64_t kept = prompt + static_cast<int64_t>(first);

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
            std::vector<int32_t> step_mask(static_cast<size_t>(s * (room + s)), 0);
            for (size_t j = 0; j < beams.size(); ++j) {
                for (int64_t k = 0; k < chain; ++k) {
                    const int64_t node = static_cast<int64_t>(j) * chain + k;
                    step_ids.push_back(k == 0 ? beams[j].tokens.back() : draft_ids[t - 1 + static_cast<size_t>(k)]);
                    step_positions.push_back(prompt + static_cast<int64_t>(t) - 1 + k);
                    int32_t* m = step_mask.data() + node * (room + s);
                    for (int64_t c = 0; c < kept; ++c) m[c] = 1;
                    for (int64_t prior : beams[j].nodes) m[prior] = 1;
                    for (int64_t q = 0; q <= k; ++q) m[room + static_cast<int64_t>(j) * chain + q] = 1;
                }
            }
            auto past = keys.Past();
            auto step = CharLmRun(h, step_ids, step_positions, step_mask, room, &past, false, options);
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
        std::vector<int32_t> step_mask(static_cast<size_t>(s * (room + s)), 0);
        const int64_t cached = static_cast<int64_t>(keys.count());
        std::vector<size_t> all(static_cast<size_t>(s));
        for (int64_t j = 0; j < s; ++j) {
            Beam& beam = beams[static_cast<size_t>(j)];
            step_ids.push_back(beam.tokens.back());
            step_positions.push_back(prompt + static_cast<int64_t>(t) - 1);
            int32_t* m = step_mask.data() + j * (room + s);
            for (int64_t c = 0; c < kept; ++c) m[c] = 1;
            for (int64_t node : beam.nodes) m[node] = 1;
            m[room + j] = 1;
            beam.nodes.push_back(cached + j);
            all[static_cast<size_t>(j)] = static_cast<size_t>(j);
        }
        auto past = keys.Past();
        auto step = CharLmRun(h, step_ids, step_positions, step_mask, room, &past, true, options);
        keys.Append(step, static_cast<size_t>(s), all);
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
        nc_trie_attention::Register(options);
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
        // The caches here append what a run returns: the graph has to return
        // the keys and values of its new tokens only, and a token's numbers
        // must not depend on the run (tools/char_lm_onnx.py static_int8).
        const auto cache = h->session->GetModelMetadata().LookupCustomMetadataMapAllocated(
            "cassotis_lm_cache", allocator);
        if (!cache || std::string(cache.get()) != "new_tokens")
            throw std::runtime_error("character LM graph is not in the runtime form (export it as int8_static)");
        // CASSOTIS_LM_NO_MEMO=1: every scoring call and correction runs all of its tokens (tests).
        char no_memo[8];
        const DWORD no_memo_length = GetEnvironmentVariableA("CASSOTIS_LM_NO_MEMO", no_memo, sizeof(no_memo));
        h->memo_enabled = !(no_memo_length == 1 && no_memo[0] == '1');
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

// Attention of the character language model as a custom operator
// (cassotis:TrieAttention). Included after the ORT headers.
//
// The graph packs candidates into a trie: a token sees the tokens its mask
// names, which are its own chain (BOS, the context, its ancestors, itself),
// laid out among the tokens of other branches and of earlier runs. ONNX
// Runtime's attention works on all tokens of a run alike, so the rounding of
// a token's sums followed where the run had put its chain, and with it now
// and then one step of the eight-bit activations after it: the same text got
// a slightly different score in another run. Here a token is computed from
// its chain alone, in the order of the chain. Its result is the same bits in
// every run and layout, so what one run computed can be kept for the next.
// A token also costs its chain's length, not the run's.
//
// Inputs:  qkv   float [1, S, 3 * H * D]   query, key and value of each new token
//          mask  int32 [1, S, P + S]       non-zero: the token sees that one; of the
//                                          new tokens, only those up to itself count
//          past  float [2, 1, H, P, D]     keys and values of earlier tokens; the
//                                          ones no mask names are not read
// Outputs: out     float [1, S, H * D]
//          present float [2, 1, H, S, D]   keys and values of the new tokens, in
//                                          the layout of past
// Attribute: num_heads (H).
//
// The earlier tokens are read where they lie and not copied: the caller keeps
// them in one buffer per layer and appends the new ones (CharLmKeys).
namespace nc_trie_attention {

constexpr const char* kDomain = "cassotis";
constexpr const char* kOperator = "TrieAttention";

inline bool CpuHasAvx2Fma() {
    static const bool value = [] {
        int info[4];
        __cpuid(info, 0);
        if (info[0] < 7) return false;
        __cpuidex(info, 1, 0);
        const bool fma = (info[2] & (1 << 12)) != 0;
        const bool os_saves = (info[2] & (1 << 27)) != 0;
        const bool avx = (info[2] & (1 << 28)) != 0;
        if (!fma || !os_saves || !avx || (_xgetbv(0) & 6) != 6) return false;
        __cpuidex(info, 7, 0);
        return (info[1] & (1 << 5)) != 0;
    }();
    return value;
}

}  // namespace nc_trie_attention

// One head for processors with AVX2 and FMA (nc_trie_attention_avx2.cpp); dim
// must be a multiple of eight, and weights needs room for four times the
// longest list rounded up to eight.
extern "C" void nc_trie_attention_head_avx2(const float* query, size_t query_stride, const float* past_keys,
    const float* past_values, size_t past_count, const float* new_keys, const float* new_values,
    const uint32_t* seen, const size_t* seen_start, size_t first, size_t last, size_t dim, float scale,
    size_t longest, float* weights, float* out, size_t out_stride);

namespace nc_trie_attention {

// The tokens `first` to `last` - 1 of one head. Token r has its query at
// query + r * query_stride and its result at out + r * out_stride, and sees
// the tokens seen[seen_start[r]] to seen[seen_start[r + 1] - 1]: a number
// below past_count is a token of an earlier run (a row of past_keys and
// past_values), the others are the run's own tokens (rows of new_keys and
// new_values); a row holds dim numbers.
//
// Every sum runs over a token's list in its order, so a result depends on the
// numbers of the token's own chain and on nothing else. This is the code for
// a processor without AVX2 and FMA, or a head size that is not a multiple of
// eight.
inline void AttendHeadPlain(const float* query, size_t query_stride, const float* past_keys,
    const float* past_values, size_t past_count, const float* new_keys, const float* new_values,
    const uint32_t* seen, const size_t* seen_start, size_t first, size_t last, size_t dim, float scale,
    float* weights, float* out, size_t out_stride) {
    for (size_t row = first; row < last; ++row) {
        const uint32_t* list = seen + seen_start[row];
        const size_t count = seen_start[row + 1] - seen_start[row];
        const float* q = query + row * query_stride;
        float* result = out + row * out_stride;
        std::fill(result, result + dim, 0.0f);
        if (count == 0) continue;
        float best = -FLT_MAX;
        for (size_t i = 0; i < count; ++i) {
            const size_t j = list[i];
            const float* key = j < past_count ? past_keys + j * dim : new_keys + (j - past_count) * dim;
            float score = 0.0f;
            for (size_t d = 0; d < dim; ++d) score += q[d] * key[d];
            score *= scale;
            weights[i] = score;
            if (score > best) best = score;
        }
        float sum = 0.0f;
        for (size_t i = 0; i < count; ++i) {
            weights[i] = std::exp(weights[i] - best);
            sum += weights[i];
        }
        const float inverse = 1.0f / sum;
        for (size_t i = 0; i < count; ++i) {
            const float weight = weights[i] * inverse;
            const size_t j = list[i];
            const float* value = j < past_count ? past_values + j * dim : new_values + (j - past_count) * dim;
            for (size_t d = 0; d < dim; ++d) result[d] += weight * value[d];
        }
    }
}

constexpr size_t kFetchAhead = 6;

struct Problem {
    const float* qkv{};
    const float* past{};
    float* out{};
    float* present{};
    const uint32_t* seen{};
    const size_t* seen_start{};
    size_t rows{}, past_count{}, heads{}, head_dim{}, longest{};
    bool vector{};
};

// One head: the keys and values of its new tokens go to the output, in the
// layout the sums then read them from; the head's numbers stay with the
// thread that works on it.
inline void AttendHead(void* data, size_t head) {
    static thread_local std::vector<float> weights;
    const Problem& p = *static_cast<const Problem*>(data);
    const size_t dim = p.head_dim, width = p.heads * dim;
    float* fresh[2];
    for (size_t part = 0; part < 2; ++part) {
        float* target = p.present + (part * p.heads + head) * p.rows * dim;
        fresh[part] = target;
        // A head's numbers lie a whole token apart in qkv, further than the
        // processor fetches ahead by itself.
        const float* source = p.qkv + (part + 1) * width + head * dim;
        for (size_t row = 0; row < p.rows; ++row) {
            if (row + kFetchAhead < p.rows) {
                const char* ahead = reinterpret_cast<const char*>(source + (row + kFetchAhead) * 3 * width);
                for (size_t byte = 0; byte < sizeof(float) * dim; byte += 64)
                    _mm_prefetch(ahead + byte, _MM_HINT_T0);
            }
            std::memcpy(target + row * dim, source + row * 3 * width, sizeof(float) * dim);
        }
    }
    const float* past_keys = p.past ? p.past + head * p.past_count * dim : nullptr;
    const float* past_values = p.past ? p.past + (p.heads + head) * p.past_count * dim : nullptr;
    if (weights.size() < 4 * (p.longest + 8)) weights.resize(4 * (p.longest + 8));
    const float scale = 1.0f / std::sqrt(static_cast<float>(dim));
    if (p.vector)
        nc_trie_attention_head_avx2(p.qkv + head * dim, 3 * width, past_keys, past_values, p.past_count,
            fresh[0], fresh[1], p.seen, p.seen_start, 0, p.rows, dim, scale, p.longest, weights.data(),
            p.out + head * dim, width);
    else
        AttendHeadPlain(p.qkv + head * dim, 3 * width, past_keys, past_values, p.past_count,
            fresh[0], fresh[1], p.seen, p.seen_start, 0, p.rows, dim, scale, weights.data(),
            p.out + head * dim, width);
}

struct Kernel {
    int64_t heads{};
    bool vector{};

    Kernel(const OrtKernelInfo* info) {
        heads = Ort::ConstKernelInfo(info).GetAttribute<int64_t>("num_heads");
        if (heads <= 0) throw std::runtime_error("TrieAttention: num_heads must be positive");
        // CASSOTIS_LM_PLAIN_ATTENTION=1 selects the plain code on any processor (tests).
        char plain[8];
        const DWORD length = GetEnvironmentVariableA("CASSOTIS_LM_PLAIN_ATTENTION", plain, sizeof(plain));
        vector = CpuHasAvx2Fma() && !(length == 1 && plain[0] == '1');
    }

    OrtStatusPtr ComputeV2(OrtKernelContext* raw) {
        try {
            Ort::KernelContext context(raw);
            const Ort::ConstValue qkv = context.GetInput(0), mask = context.GetInput(1), past = context.GetInput(2);
            const auto qkv_shape = qkv.GetTensorTypeAndShapeInfo().GetShape();
            const auto mask_shape = mask.GetTensorTypeAndShapeInfo().GetShape();
            const auto past_shape = past.GetTensorTypeAndShapeInfo().GetShape();
            if (qkv_shape.size() != 3 || qkv_shape[0] != 1 || qkv_shape[2] <= 0 || qkv_shape[2] % (3 * heads) != 0)
                throw std::runtime_error("TrieAttention: qkv must be [1, tokens, 3 * heads * head size]");
            const int64_t rows = qkv_shape[1], width = qkv_shape[2] / 3, head_dim = width / heads;
            if (past_shape.size() != 5 || past_shape[0] != 2 || past_shape[1] != 1 || past_shape[2] != heads ||
                past_shape[4] != head_dim)
                throw std::runtime_error("TrieAttention: past must be [2, 1, heads, tokens, head size]");
            const int64_t past_count = past_shape[3];
            if (mask_shape.size() != 3 || mask_shape[0] != 1 || mask_shape[1] != rows ||
                mask_shape[2] != past_count + rows)
                throw std::runtime_error("TrieAttention: mask must be [1, tokens, past tokens + tokens]");
            const std::array<int64_t, 3> out_shape{1, rows, width};
            const std::array<int64_t, 5> present_shape{2, 1, heads, rows, head_dim};
            Ort::UnownedValue out = context.GetOutput(0, out_shape.data(), out_shape.size());
            Ort::UnownedValue present = context.GetOutput(1, present_shape.data(), present_shape.size());
            if (rows == 0) return nullptr;

            Problem p;
            p.rows = static_cast<size_t>(rows);
            p.past_count = static_cast<size_t>(past_count);
            p.heads = static_cast<size_t>(heads);
            p.head_dim = static_cast<size_t>(head_dim);
            p.vector = vector && head_dim % 8 == 0;
            p.qkv = qkv.GetTensorData<float>();
            p.past = past_count > 0 ? past.GetTensorData<float>() : nullptr;
            p.out = out.GetTensorMutableData<float>();
            p.present = present.GetTensorMutableData<float>();

            // What each token sees, once for all heads. The lists belong to the
            // calling thread: handles that share a session run it at the same time.
            static thread_local std::vector<uint32_t> seen_;
            static thread_local std::vector<size_t> seen_start_;
            const size_t total = p.past_count + p.rows;
            const int32_t* visible = mask.GetTensorData<int32_t>();
            seen_.clear();
            seen_start_.assign(p.rows + 1, 0);
            for (size_t row = 0; row < p.rows; ++row) {
                const int32_t* line = visible + row * total;
                for (size_t j = 0; j < p.past_count + row + 1; ++j)
                    if (line[j]) seen_.push_back(static_cast<uint32_t>(j));
                seen_start_[row + 1] = seen_.size();
                p.longest = std::max(p.longest, seen_start_[row + 1] - seen_start_[row]);
            }
            p.seen = seen_.data();
            p.seen_start = seen_start_.data();

            // A few tokens with short chains are done sooner than the threads are woken.
            if (seen_.size() * p.head_dim < kInlineWork || p.heads == 1) {
                for (size_t head = 0; head < p.heads; ++head) AttendHead(&p, head);
            } else {
                context.ParallelFor(AttendHead, p.heads, 0, &p);
            }
            return nullptr;
        } catch (const Ort::Exception& e) {
            return Ort::Status(e).release();
        } catch (const std::exception& e) {
            return Ort::Status(e.what(), ORT_FAIL).release();
        }
    }

private:
    static constexpr size_t kInlineWork = 2048;
};

struct Operator : Ort::CustomOpBase<Operator, Kernel, true> {
    OrtStatusPtr CreateKernelV2(const OrtApi&, const OrtKernelInfo* info, void** kernel) const {
        try {
            *kernel = new Kernel(info);
            return nullptr;
        } catch (const Ort::Exception& e) {
            return Ort::Status(e).release();
        } catch (const std::exception& e) {
            return Ort::Status(e.what(), ORT_FAIL).release();
        }
    }
    const char* GetName() const { return kOperator; }
    size_t GetInputTypeCount() const { return 3; }
    ONNXTensorElementDataType GetInputType(size_t index) const {
        return index == 1 ? ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32 : ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT;
    }
    size_t GetOutputTypeCount() const { return 2; }
    ONNXTensorElementDataType GetOutputType(size_t) const { return ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT; }
};

// Makes the operator known to sessions created with these options. The domain
// lives as long as the module.
inline void Register(OrtSessionOptions* options) {
    static const Operator op;
    static Ort::CustomOpDomain domain = [] {
        Ort::CustomOpDomain value(kDomain);
        value.Add(&op);
        return value;
    }();
    Ort::UnownedSessionOptions(options).Add(domain);
}

}  // namespace nc_trie_attention

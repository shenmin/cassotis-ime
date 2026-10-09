// One head of cassotis:TrieAttention (nc_trie_attention.inc) for processors
// with AVX2 and FMA. This file alone is compiled with /arch:AVX2, so that none
// of its instructions mixes with the SSE encoding of the rest; the caller
// checks the processor first. It includes no shared inline code.
//
// A token's result depends on the numbers of its own list and on nothing
// else: a score is computed from its key alone, the normalizer is summed in
// eight lanes by the place in the list, and each element of the result is one
// chain of multiply-adds over the list in its order.
#include <cfloat>
#include <cstddef>
#include <cstdint>
#include <immintrin.h>

namespace {

constexpr size_t kTogether = 4;

// The keys or the values of one head: the tokens of earlier runs, then the
// new ones. row(j) is token j's numbers.
struct Rows {
    uintptr_t past;
    uintptr_t fresh;  // moved back by the earlier tokens, so that both are indexed by j
    size_t past_count;
    size_t bytes;     // of one token's numbers

    Rows(const float* past_rows, size_t count, const float* new_rows, size_t dim)
        : past(reinterpret_cast<uintptr_t>(past_rows)),
          fresh(reinterpret_cast<uintptr_t>(new_rows) - count * dim * sizeof(float)),
          past_count(count), bytes(dim * sizeof(float)) {}

    const float* row(uint32_t j) const {
        return reinterpret_cast<const float*>((j < past_count ? past : fresh) + j * bytes);
    }
};

alignas(32) const int32_t kLanes[16] = {-1, -1, -1, -1, -1, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0};

// All ones in the first `count` lanes (count < 8).
inline __m256 FirstLanes(size_t count) {
    return _mm256_castsi256_ps(_mm256_loadu_si256(reinterpret_cast<const __m256i*>(kLanes + (8 - count))));
}

inline float HorizontalSum(__m256 v) {
    __m128 low = _mm_add_ps(_mm256_castps256_ps128(v), _mm256_extractf128_ps(v, 1));
    low = _mm_add_ps(low, _mm_movehl_ps(low, low));
    low = _mm_add_ss(low, _mm_shuffle_ps(low, low, 1));
    return _mm_cvtss_f32(low);
}

// exp(x) for x <= 0, every lane by the same operations (Cephes expf).
inline __m256 ExpNonPositive(__m256 x) {
    x = _mm256_max_ps(x, _mm256_set1_ps(-87.33654f));
    const __m256 n = _mm256_round_ps(_mm256_mul_ps(x, _mm256_set1_ps(1.44269504088896341f)),
        _MM_FROUND_TO_NEAREST_INT | _MM_FROUND_NO_EXC);
    __m256 r = _mm256_fnmadd_ps(n, _mm256_set1_ps(0.693359375f), x);
    r = _mm256_fnmadd_ps(n, _mm256_set1_ps(-2.12194440e-4f), r);
    __m256 p = _mm256_set1_ps(1.9875691500e-4f);
    p = _mm256_fmadd_ps(p, r, _mm256_set1_ps(1.3981999507e-3f));
    p = _mm256_fmadd_ps(p, r, _mm256_set1_ps(8.3334519073e-3f));
    p = _mm256_fmadd_ps(p, r, _mm256_set1_ps(4.1665795894e-2f));
    p = _mm256_fmadd_ps(p, r, _mm256_set1_ps(1.6666665459e-1f));
    p = _mm256_fmadd_ps(p, r, _mm256_set1_ps(5.0000001201e-1f));
    const __m256 y = _mm256_add_ps(_mm256_fmadd_ps(p, _mm256_mul_ps(r, r), r), _mm256_set1_ps(1.0f));
    const __m256i power = _mm256_slli_epi32(
        _mm256_add_epi32(_mm256_cvtps_epi32(n), _mm256_set1_epi32(127)), 23);
    return _mm256_mul_ps(y, _mm256_castsi256_ps(power));
}

// weights[i] = scale * (q . key of list[i]); returns the largest.
inline float Scores(const float* q, const Rows& keys, const uint32_t* list, size_t count, size_t dim,
    float scale, float* weights) {
    float best = -FLT_MAX;
    for (size_t i = 0; i < count; ++i) {
        const float* key = keys.row(list[i]);
        __m256 a0 = _mm256_setzero_ps(), a1 = _mm256_setzero_ps();
        size_t d = 0;
        for (; d + 16 <= dim; d += 16) {
            a0 = _mm256_fmadd_ps(_mm256_loadu_ps(q + d), _mm256_loadu_ps(key + d), a0);
            a1 = _mm256_fmadd_ps(_mm256_loadu_ps(q + d + 8), _mm256_loadu_ps(key + d + 8), a1);
        }
        if (d < dim) a0 = _mm256_fmadd_ps(_mm256_loadu_ps(q + d), _mm256_loadu_ps(key + d), a0);
        const float score = HorizontalSum(_mm256_add_ps(a0, a1)) * scale;
        weights[i] = score;
        if (score > best) best = score;
    }
    return best;
}

// The same for the usual head of sixty-four numbers: the query stays in
// registers and a score is eight multiply-adds in four short chains.
inline float Scores64(const float* q, const Rows& keys, const uint32_t* list, size_t count, float scale,
    float* weights) {
    const __m256 q0 = _mm256_loadu_ps(q), q1 = _mm256_loadu_ps(q + 8);
    const __m256 q2 = _mm256_loadu_ps(q + 16), q3 = _mm256_loadu_ps(q + 24);
    const __m256 q4 = _mm256_loadu_ps(q + 32), q5 = _mm256_loadu_ps(q + 40);
    const __m256 q6 = _mm256_loadu_ps(q + 48), q7 = _mm256_loadu_ps(q + 56);
    float best = -FLT_MAX;
    for (size_t i = 0; i < count; ++i) {
        const float* key = keys.row(list[i]);
        __m256 a0 = _mm256_mul_ps(q0, _mm256_loadu_ps(key));
        __m256 a1 = _mm256_mul_ps(q1, _mm256_loadu_ps(key + 8));
        __m256 a2 = _mm256_mul_ps(q2, _mm256_loadu_ps(key + 16));
        __m256 a3 = _mm256_mul_ps(q3, _mm256_loadu_ps(key + 24));
        a0 = _mm256_fmadd_ps(q4, _mm256_loadu_ps(key + 32), a0);
        a1 = _mm256_fmadd_ps(q5, _mm256_loadu_ps(key + 40), a1);
        a2 = _mm256_fmadd_ps(q6, _mm256_loadu_ps(key + 48), a2);
        a3 = _mm256_fmadd_ps(q7, _mm256_loadu_ps(key + 56), a3);
        const float score = HorizontalSum(_mm256_add_ps(_mm256_add_ps(a0, a1), _mm256_add_ps(a2, a3))) * scale;
        weights[i] = score;
        if (score > best) best = score;
    }
    return best;
}

// Scores to shares: exp(score - best) over their sum; zero after the list
// (whatever the buffer held there).
inline void Normalize(float* weights, size_t count, float best) {
    const __m256 shift = _mm256_set1_ps(best);
    __m256 sum = _mm256_setzero_ps();
    for (size_t i = 0; i < count; i += 8) {
        __m256 e = ExpNonPositive(_mm256_sub_ps(_mm256_loadu_ps(weights + i), shift));
        if (i + 8 > count) e = _mm256_and_ps(e, FirstLanes(count - i));
        _mm256_storeu_ps(weights + i, e);
        sum = _mm256_add_ps(sum, e);
    }
    const __m256 inverse = _mm256_set1_ps(1.0f / HorizontalSum(sum));
    for (size_t i = 0; i < count; i += 8)
        _mm256_storeu_ps(weights + i, _mm256_mul_ps(_mm256_loadu_ps(weights + i), inverse));
}

// result = sum of weights[i] * (value of list[i]). Sixty-four elements at a
// time keep both multiply-add units busy.
inline void Combine(const Rows& values, const uint32_t* list, size_t count, size_t dim, const float* weights,
    float* result) {
    size_t d = 0;
    for (; d + 64 <= dim; d += 64) {
        __m256 a0 = _mm256_setzero_ps(), a1 = _mm256_setzero_ps();
        __m256 a2 = _mm256_setzero_ps(), a3 = _mm256_setzero_ps();
        __m256 a4 = _mm256_setzero_ps(), a5 = _mm256_setzero_ps();
        __m256 a6 = _mm256_setzero_ps(), a7 = _mm256_setzero_ps();
        for (size_t i = 0; i < count; ++i) {
            const __m256 w = _mm256_broadcast_ss(weights + i);
            const float* value = values.row(list[i]) + d;
            a0 = _mm256_fmadd_ps(w, _mm256_loadu_ps(value), a0);
            a1 = _mm256_fmadd_ps(w, _mm256_loadu_ps(value + 8), a1);
            a2 = _mm256_fmadd_ps(w, _mm256_loadu_ps(value + 16), a2);
            a3 = _mm256_fmadd_ps(w, _mm256_loadu_ps(value + 24), a3);
            a4 = _mm256_fmadd_ps(w, _mm256_loadu_ps(value + 32), a4);
            a5 = _mm256_fmadd_ps(w, _mm256_loadu_ps(value + 40), a5);
            a6 = _mm256_fmadd_ps(w, _mm256_loadu_ps(value + 48), a6);
            a7 = _mm256_fmadd_ps(w, _mm256_loadu_ps(value + 56), a7);
        }
        _mm256_storeu_ps(result + d, a0);
        _mm256_storeu_ps(result + d + 8, a1);
        _mm256_storeu_ps(result + d + 16, a2);
        _mm256_storeu_ps(result + d + 24, a3);
        _mm256_storeu_ps(result + d + 32, a4);
        _mm256_storeu_ps(result + d + 40, a5);
        _mm256_storeu_ps(result + d + 48, a6);
        _mm256_storeu_ps(result + d + 56, a7);
    }
    for (; d < dim; d += 8) {
        __m256 a0 = _mm256_setzero_ps();
        for (size_t i = 0; i < count; ++i)
            a0 = _mm256_fmadd_ps(_mm256_broadcast_ss(weights + i),
                _mm256_loadu_ps(values.row(list[i]) + d), a0);
        _mm256_storeu_ps(result + d, a0);
    }
}

}  // namespace

// The tokens `first` to `last` - 1 of one head. Token r has its query at
// query + r * query_stride and its result at out + r * out_stride, and sees
// the tokens seen[seen_start[r]] to seen[seen_start[r + 1] - 1]: a number
// below past_count is a token of an earlier run (a row of past_keys and
// past_values), the others are the run's own tokens (rows of new_keys and
// new_values); a row holds dim numbers, a multiple of eight. No list is longer
// than `longest`; weights has room for four times `longest` rounded up to
// eight.
//
// The tokens are taken four at a time: the normalizer of a token is one long
// chain of operations, and four of them run side by side. It also reads the
// scores eight at a time, which waits on scores stored one by one unless
// other work has passed since.
extern "C" void nc_trie_attention_head_avx2(const float* query, size_t query_stride, const float* past_keys,
    const float* past_values, size_t past_count, const float* new_keys, const float* new_values,
    const uint32_t* seen, const size_t* seen_start, size_t first, size_t last, size_t dim, float scale,
    size_t longest, float* weights, float* out, size_t out_stride) {
    const Rows keys(past_keys, past_count, new_keys, dim), values(past_values, past_count, new_values, dim);
    const size_t room = (longest + 7) & ~static_cast<size_t>(7);
    for (size_t group = first; group < last; group += kTogether) {
        const size_t end = group + kTogether < last ? group + kTogether : last;
        float best[kTogether];
        for (size_t row = group; row < end; ++row) {
            const size_t count = seen_start[row + 1] - seen_start[row];
            if (count == 0) continue;
            const float* q = query + row * query_stride;
            float* scores = weights + (row - group) * room;
            best[row - group] = dim == 64 ? Scores64(q, keys, seen + seen_start[row], count, scale, scores)
                : Scores(q, keys, seen + seen_start[row], count, dim, scale, scores);
        }
        for (size_t row = group; row < end; ++row) {
            const size_t count = seen_start[row + 1] - seen_start[row];
            if (count > 0) Normalize(weights + (row - group) * room, count, best[row - group]);
        }
        for (size_t row = group; row < end; ++row) {
            const size_t count = seen_start[row + 1] - seen_start[row];
            float* result = out + row * out_stride;
            if (count > 0) {
                Combine(values, seen + seen_start[row], count, dim, weights + (row - group) * room, result);
            } else {
                for (size_t d = 0; d < dim; d += 8) _mm256_storeu_ps(result + d, _mm256_setzero_ps());
            }
        }
    }
}

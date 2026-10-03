#define NOMINMAX
#define ORT_API_MANUAL_INIT
#include <onnxruntime_cxx_api.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <cwchar>
#include <float.h>
#include <fstream>
#include <limits>
#include <memory>
#include <map>
#include <mutex>
#include <set>
#include <xmmintrin.h>
#include <string>
#include <string_view>
#include <tuple>
#include <unordered_map>
#include <utility>
#include <vector>
#include <windows.h>

namespace {

std::mutex& InitializationMutex() {
    static std::mutex value;
    return value;
}

template <typename T>
bool ReadBinary(std::ifstream& stream, T& value) {
    return static_cast<bool>(stream.read(
        reinterpret_cast<char*>(&value), static_cast<std::streamsize>(sizeof(value))));
}

class FloatingPointMaskGuard {
public:
    FloatingPointMaskGuard() : old_mxcsr_(_mm_getcsr()) {
        _controlfp_s(&old_control_, 0, 0);
        _controlfp_s(nullptr, _MCW_EM, _MCW_EM);
        _mm_setcsr(old_mxcsr_ | _MM_MASK_MASK);
    }

    ~FloatingPointMaskGuard() {
        _controlfp_s(nullptr, old_control_, _MCW_EM);
        _mm_setcsr(old_mxcsr_);
    }

private:
    unsigned int old_control_{};
    unsigned int old_mxcsr_{};
};

Ort::Env& Environment() {
    static Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "cassotis_pinyin_transformer");
    return env;
}

// The default initializer arena is one contiguous block per session. Kernels
// pre-pack most weights, but that block cannot release the originals, so each
// model would stay resident twice. Individually allocated initializers are
// freed once packed; inference still uses the same packed weights.
void UseReleasableInitializers(Ort::SessionOptions& options) {
    options.AddConfigEntry("session.use_device_allocator_for_initializers", "1");
}

void SetError(wchar_t* destination, int capacity, const std::wstring& message) {
    if (destination == nullptr || capacity <= 0) {
        return;
    }
    const size_t copy_length = std::min(message.size(), static_cast<size_t>(capacity - 1));
    if (copy_length > 0) {
        std::wmemcpy(destination, message.data(), copy_length);
    }
    destination[copy_length] = L'\0';
}

std::wstring Utf8ToWide(const char* message) {
    if (message == nullptr || *message == '\0') {
        return L"unknown ONNX Runtime error";
    }
    const int required = MultiByteToWideChar(CP_UTF8, 0, message, -1, nullptr, 0);
    if (required <= 1) {
        return L"ONNX Runtime error";
    }
    std::wstring result(static_cast<size_t>(required), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, message, -1, result.data(), required);
    result.resize(static_cast<size_t>(required - 1));
    return result;
}

}  // namespace

#include "nc_char_lm_ort.inc"

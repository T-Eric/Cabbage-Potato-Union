#pragma once
#include <array>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <iterator>
#include <memory>
#include <new>
#include <serial/serial.h>
#include <stdexcept>
#include <string>
#include <string_view>
#include <type_traits>

namespace debug {

inline bool info_enabled = false;

template <typename... _Args>
inline auto info(const char *str, const _Args &...args) -> void {
    if (info_enabled) {
        std::printf(str, args...);
    }
}

template <typename... _Args>
inline auto error(const char *str, const _Args &...args) -> void {
    std::fprintf(stderr, str, args...);
}

template <typename... _Args>
inline auto assert(bool cond, const char *str = "", const _Args &...args) -> void {
    if (!cond) {
        error("Assertion failed: ");
        error(str, args...);
        error("\n");
        throw std::runtime_error("Assertion failed");
    }
}

} // namespace debug

namespace config {

static constexpr int baud_rate                = 115200;
static constexpr serial::bytesize_t byte_size = serial::eightbits;
static constexpr serial::parity_t parity      = serial::parity_odd;
static constexpr serial::stopbits_t stopbits  = serial::stopbits_one;
static constexpr int inter_byte_timeout       = 50;
static constexpr int read_timeout_constant    = 50;
static constexpr int read_timeout_multiplier  = 10;
static constexpr int write_timeout_constant   = 50;
static constexpr int write_timeout_multiplier = 10;

} // namespace config

using byte  = std::uint8_t;
using word  = std::uint16_t;
using dword = std::uint32_t;

template <typename _Tp>
inline static constexpr bool is_byte_v = std::is_same_v<_Tp, byte> || std::is_same_v<_Tp, char>;

template <typename _Target, typename _Char>
inline auto pointer_cast(_Char *ptr) -> _Target * {
    static_assert(is_byte_v<_Char>, "Data type must be a char or byte");
    return std::launder(reinterpret_cast<_Target *>(ptr));
}

template <typename _Target, typename _Char>
inline auto pointer_cast(const _Char *ptr) -> const _Target * {
    static_assert(is_byte_v<_Char>, "Data type must be a char or byte");
    return std::launder(reinterpret_cast<const _Target *>(ptr));
}

template <typename _Src, std::size_t _Size = std::size_t(-1), typename _Char>
inline auto unaligned_write(_Char *dst, const _Src &data) -> void {
    if constexpr (_Size == std::size_t(-1)) {
        std::memcpy(dst, &data, sizeof(_Src));
    } else {
        static_assert(_Size <= sizeof(_Src), "Data size exceeds the specified size");
        std::memcpy(dst, &data, _Size);
    }
}

template <typename _Dst, std::size_t _Size = std::size_t(-1), typename _Char>
inline auto unaligned_read(const _Char *src) -> _Dst {
    _Dst data{};
    if constexpr (_Size == std::size_t(-1)) {
        std::memcpy(&data, src, sizeof(_Dst));
    } else {
        static_assert(_Size <= sizeof(_Dst), "Data size exceeds the specified size");
        std::memcpy(&data, src, _Size);
    }
    return data;
}

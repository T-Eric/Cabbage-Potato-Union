#pragma once

#include "utility.h"
#include <cstddef>
#include <cstring>
#include <iterator>

namespace __details {

template <std::size_t _Size, std::size_t _Size_Offset>
struct package_base {
public:
    static_assert(_Size >= 1 + sizeof(word), "Size must be at least 1 + sizeof(word)");
    static_assert(_Size_Offset + sizeof(word) <= _Size, "Size offset exceeds package size");

    package_base(const package_base &)            = delete;
    package_base &operator=(const package_base &) = delete;

    auto area() -> std::pair<char *, std::size_t> {
        return std::make_pair(_M_reserved, _M_size() + std::size(_M_reserved));
    }

    auto area() const -> std::pair<const char *, std::size_t> {
        return std::make_pair(_M_reserved, _M_size() + std::size(_M_reserved));
    }

private:
    auto _M_size() const -> word {
        return unaligned_read<word>(_M_reserved + _Size_Offset);
    }

protected:
    explicit package_base(byte first) {
        _M_reserved[0] = first;
    }

    auto _M_unsafe_set_length(word len) -> void {
        unaligned_write(_M_reserved + _Size_Offset, len);
    }

    template <typename _Tp>
    auto _M_unsafe_copy_data(const _Tp *data, std::size_t len) -> void {
        std::memcpy(std::end(_M_reserved), data, len);
    }

    static constexpr auto _M_padding_size() -> std::size_t {
        return _Size - 1 - sizeof(word);
    }

    auto _M_padding_ptr() -> char * {
        return _M_reserved + 1;
    }

private:
    char _M_reserved[_Size] = {};
};

template <std::size_t _Max_Len, typename _Base>
struct package : _Base {
public:
    static_assert(_Max_Len >= 0, "Length must be non-negative");

    explicit package(byte first = 0) : _Base(first) {}

    static constexpr auto max_size() -> std::size_t {
        return _Max_Len;
    }

    auto unsafe_set_length(std::size_t len) -> package & {
        // set length without checking
        this->_M_unsafe_set_length(len);
        return *this;
    }

    auto set_string(std::string_view str) -> package & {
        return this->set_data(str.data(), str.size());
    }

    template <typename _Char>
    auto set_data(const _Char *data, std::size_t len) & -> package & {
        static_assert(is_byte_v<_Char>, "Data type must be a char or byte");
        _M_check_length(len);
        this->_M_unsafe_set_length(len);
        this->_M_unsafe_copy_data(data, len);
        return *this;
    }

private:
    auto _M_check_length(word len) -> void {
        debug::assert(len <= _Max_Len, "Data length exceeds maximum length");
    }

private:
    char _M_storage[_Max_Len] = {};
};

} // namespace __details

namespace normal {

struct base : __details::package_base<3, 1> {
    using __details::package_base<3, 1>::package_base;
};

template <std::size_t _Max_Len>
using package = __details::package<_Max_Len, base>;

static_assert(sizeof(package<1>) == 3 + 1, "Invalid package size");

} // namespace normal

namespace memory {

struct base : __details::package_base<6, 4> {
    using __details::package_base<6, 4>::package_base;
    auto set_offset(std::size_t offset) -> base & {
        constexpr auto kSize = _M_padding_size();
        unaligned_write<dword, kSize>(_M_padding_ptr(), offset);
        return *this;
    }
};

template <std::size_t _Max_Len>
using package = __details::package<_Max_Len, base>;

static_assert(sizeof(package<1>) == 6 + 1, "Invalid package size");

} // namespace memory

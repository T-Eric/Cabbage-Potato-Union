#pragma once
#include <cstddef>
#include <iterator>

struct integer_iterator {
public:
    using value_type        = std::size_t;
    using difference_type   = std::ptrdiff_t;
    using pointer           = value_type *;
    using reference         = value_type &;
    using iterator_category = std::input_iterator_tag;

    explicit integer_iterator(std::size_t value) : _M_value(value) {}

    auto operator*() const -> value_type {
        return _M_value;
    }

    auto operator++() -> integer_iterator & {
        ++_M_value;
        return *this;
    }

    auto operator++(int) -> integer_iterator {
        auto copy = *this;
        ++_M_value;
        return copy;
    }

    auto operator==(const integer_iterator &other) const -> bool {
        return _M_value == other._M_value;
    }

    auto operator!=(const integer_iterator &other) const -> bool {
        return _M_value != other._M_value;
    }

private:
    std::size_t _M_value;
};

struct integer_range {
public:
    explicit integer_range(std::size_t begin, std::size_t end) : _M_begin(begin), _M_end(end) {}

    auto begin() const -> integer_iterator {
        return integer_iterator(_M_begin);
    }

    auto end() const -> integer_iterator {
        return integer_iterator(_M_end);
    }

private:
    std::size_t _M_begin;
    std::size_t _M_end;
};

/** Return a range of integers from 0 to len */
inline auto irange(std::size_t len) -> integer_range {
    return integer_range(0, len);
}

/** Return a range of integers from begin to end */
inline auto irange(std::size_t begin, std::size_t end) -> integer_range {
    return integer_range(begin, end);
}

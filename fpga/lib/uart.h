#pragma once
#include "package.h"
#include "utility.h"
#include <array>
#include <cstddef>
#include <iterator>
#include <optional>
#include <serial/serial.h>
#include <string>
#include <type_traits>

namespace uart {

inline serial::Serial serial_port;

using opt_size_t = std::optional<std::size_t>;

template <std::size_t _S1, std::size_t _S2>
inline auto send_pkg(const __details::package_base<_S1, _S2> &pkg, opt_size_t len = {}) -> void {
    auto [ptr, size] = pkg.area();
    serial_port.write(pointer_cast<const byte>(ptr), len.value_or(size));
}

template <std::size_t _Max_Len>
inline auto recv_pkg(opt_size_t len = {}) -> std::array<char, _Max_Len> {
    auto array = std::array<char, _Max_Len>{};
    serial_port.read(pointer_cast<byte>(array.data()), len.value_or(_Max_Len));
    return array;
}

inline auto send_byte(byte ptr) -> void {
    serial_port.write(&ptr, 1);
}

inline auto recv_byte() -> byte {
    auto ptr = byte{};
    serial_port.read(&ptr, 1);
    return ptr;
}

inline auto init_port(const std::string &port) -> void {
    using namespace config;
    serial_port.setPort(port);
    serial_port.setBaudrate(baud_rate);
    serial_port.setBytesize(byte_size);
    serial_port.setParity(parity);
    serial_port.setStopbits(stopbits);
    serial_port.setTimeout(
        inter_byte_timeout, read_timeout_constant, read_timeout_multiplier, write_timeout_constant,
        write_timeout_multiplier
    );
    serial_port.open();
    debug::info("initialized UART port on: %s\n", port);
}

inline auto available() -> std::size_t {
    return serial_port.available();
}

inline auto shutdown() -> void {
    serial_port.close();
}

} // namespace uart

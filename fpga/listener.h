#include "lib/irange.h"
#include "lib/package.h"
#include "lib/uart.h"
#include <algorithm>
#include <array>
#include <chrono>
#include <cstddef>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <string>
#include <string_view>
#include <thread>
#include <vector>

// methods
inline auto on_init() -> void {
    using namespace std::chrono_literals;
    uart::recv_pkg<8>(); // Read 8 bytes of rubbish.
    std::this_thread::sleep_for(1s);

    constexpr char test[] = "UART";
    normal::package<5> test_pkg{0x00};
    uart::send_pkg(test_pkg.set_string(test));

    const auto recv = uart::recv_pkg<4>();
    debug::assert(std::memcmp(test, recv.data(), 4) == 0, "UART assertion failed\n");
}

inline auto upload_ram(const byte *ram_data, int ram_size) -> void {
    if (!ram_size)
        return;

    using namespace std::chrono_literals;

    const std::size_t blk_size = 0x400;
    memory::package<blk_size> payload{0x0A};

    const auto blk_cnt = (ram_size + blk_size - 1) / blk_size;
    debug::info("uploading RAM: %zx blks:%zu\n", ram_size, blk_cnt);

    for (const auto i : irange(blk_cnt)) {
        const auto offset   = i * blk_size;
        const auto rem_size = std::min(ram_size - offset, blk_size);
        debug::info("blk: %zu offset: %04zx\n size: %zu\n", i, offset, rem_size);
        uart::send_pkg(payload.set_data(ram_data + offset, rem_size).set_offset(offset));
    }

    debug::info("RAM uploaded\n");
    std::this_thread::sleep_for(1s);
}

inline auto upload_input(const byte *in_data, std::size_t in_size) -> void {
    if (!in_size)
        return;

    using namespace std::chrono_literals;

    const std::size_t blk_size = 0x400;
    normal::package<blk_size> payload{0x05};
    uart::send_pkg(payload.set_string("  ")); // 2 spaces

    const auto blk_cnt = (in_size + blk_size - 1) / blk_size;
    debug::info("uploading INPUT: %zx blks: %zu\n", in_size, blk_cnt);

    for (const auto i : irange(blk_cnt)) {
        const auto offset   = i * blk_size;
        const auto rem_size = std::min(in_size - offset, blk_size);
        debug::info("blk: %zu offset: %04zx\n size: %zu\n", i, offset, rem_size);
        uart::send_pkg(payload.set_data(in_data + offset, rem_size));
    }

    debug::info("INPUT uploaded\n");
    std::this_thread::sleep_for(1s);
}

inline auto verify_ram(const byte *ram_data, std::size_t ram_size) -> void {
    const std::size_t blk_size = 0x400;

    memory::package<1> payload{0x09};
    const auto blk_cnt = (ram_size + blk_size - 1) / blk_size;

    debug::info("verifying RAM: %x blks:%d\n", ram_size, blk_cnt);
    for (const auto i : irange(blk_cnt)) {
        const auto offset   = i * blk_size;
        const auto rem_size = std::min(ram_size - offset, blk_size);
        debug::info("blk: %zu offset: %04zx\n size: %zu\n", i, offset, rem_size);

        // Send the offset and length, then receive the data.
        uart::send_pkg(payload.unsafe_set_length(rem_size).set_offset(offset), sizeof(payload));
        const auto recv = uart::recv_pkg<blk_size>(rem_size);

        // Compare the received data with the RAM data.
        if (const auto result = std::memcmp(ram_data + offset, recv.data(), rem_size)) {
            debug::error("RAM error: addr:%08x\n", offset + result);
            debug::assert(false, "RAM verification failed\n");
        }
    }

    debug::info("RAM verification complete\n");
    std::this_thread::sleep_for(std::chrono::seconds(1));
}

inline auto on_recv(byte data) -> int {
    debug::info("%c", data);
    fflush(stdout);
    return data == 0;
}

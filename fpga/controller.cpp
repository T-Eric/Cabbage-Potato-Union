#include "lib/irange.h"
#include "lib/package.h"
#include "lib/uart.h"
#include "lib/utility.h"
#include "listener.h"
#include <chrono>
#include <cstddef>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <fstream>
#include <optional>
#include <serial/serial.h>
#include <string>
#include <vector>

static auto load_ram(const std::string &rom_path) -> std::vector<char> {
    std::ifstream fin(rom_path);
    debug::assert(fin.is_open(), "failed to read ram file: \"%s\"", rom_path.c_str());

    fin.seekg(0, std::ios_base::end);
    const std::size_t ram_size = fin.tellg();
    fin.seekg(0, std::ios_base::beg);

    // Read the entire file into a vector
    debug::info("RAM size: %zu\n", ram_size);
    std::vector<char> ram_data(ram_size);
    fin.read(ram_data.data(), ram_size);

    // Print the first 0x40 bytes of the ROM at 0x1000
    for (const auto i : irange(0x40)) {
        if (i + 0x1000 >= ram_size)
            break;
        debug::info("%02x ", (byte)ram_data[i + 0x1000]);
        if (!((i + 1) % 16))
            debug::info("\n");
    }

    return ram_data;
}

static auto load_input(const std::string &in_path) -> std::vector<char> {
    // Open the input file and read its file size
    std::ifstream fin(in_path);
    debug::assert(fin.is_open(), "failed to read input file: \"%s\"", in_path.c_str());

    fin.seekg(0, std::ios_base::end);
    const std::size_t in_size = fin.tellg();
    fin.seekg(0, std::ios_base::beg);

    debug::info("INPUT size: %x\n", in_size);
    std::vector<char> in_data(in_size);
    fin.read(in_data.data(), in_size);

    // Print the first 0x10 bytes of the input
    for (const auto i : irange(0x10)) {
        if (i >= in_size)
            break;
        debug::info("%02x ", (byte)in_data[i]);
        if (!((i + 1) % 16))
            debug::info("\n");
    }

    return in_data;
}

static auto run() -> void {
    // demo

    // debug packet format: see hci.v or README.md
    // send[0] is always OPCODE
    // to send debug packets, use uart_send(send,send_count)
    // to receive data after send, use uart_send(send,send_count,recv,recv_count)
    bool run = 0;
    while (1) {
        debug::info("Enter r to run, q to quit, p to get cpu PC(demo)\n");
        const char c = getchar();
        if (c == 'q') {
            break;
        } else if (c == 'p') {
            // demo for debugging cpu
            // add support in hci.v to allow more debug operations
            uart::send_byte(0x01);

            const auto pc_bytes = uart::recv_pkg<4>();
            auto pc             = unaligned_read<int>(pc_bytes.data());
            debug::info("pc:%08x\n", pc);

            memory::package<6> payload{0x09};
            uart::send_pkg(payload.unsafe_set_length(16).set_offset(0), sizeof(payload));

            const auto data = uart::recv_pkg<16>();

            for (int i = 0; i < 16; ++i) {
                debug::info("%02x ", data[i]);
            }
            debug::info("\n");
        } else if (c == 'r') {
            debug::info("CPU start\n");
            uart::send_byte(run ? 0x03 : 0x04);
            run = !run;

            const auto tic = std::chrono::high_resolution_clock::now();
            // receive output bytes from fpga
            while (1) {
                // to debug cpu at the same time, implement separate thread
                while (!uart::available())
                    ;
                if (on_recv(uart::recv_byte()))
                    break;
            }
            const auto toc = std::chrono::high_resolution_clock::now();
            const auto elapsed_time =
                std::chrono::duration_cast<std::chrono::duration<double>>(toc - tic).count();
            debug::info("\nCPU returned with running time: %f\n", elapsed_time);

            // manually pressing reset button is recommended

            // or pause and reset cpu through uart (TODO)
            // send[0]=(run?0x03:0x04);
            // run = !run;
            // uart_send(send,1);

            return;
        }
    }
}

static auto run_auto() -> void {
    uart::send_byte(0x04);
    while (1) {
        while (!uart::available())
            ;
        if (const auto data = uart::recv_byte())
            putchar(data);
        else // data == 0x00
            break;
    }
}

using std::string;

static auto work(string ram_path, std::optional<string> input_path, string com_port, char mode)
    -> void {
    if (mode == 'I') {
        debug::info_enabled = true;
    } else if (mode == 'T') {
        debug::info_enabled = false;
    } else {
        std::string msg = "invalid mode:  ";
        msg.back()      = mode;
        throw std::runtime_error(msg);
    }

    auto ram_data = std::vector<char>{};
    auto in_data  = std::vector<char>{};

    try {
        ram_data = load_ram(ram_path);
    } catch (const std::exception &e) {
        throw std::runtime_error("failed to read ram file: " + ram_path);
    }

    try {
        in_data = input_path ? load_input(*input_path) : std::vector<char>{};
    } catch (const std::exception &e) {
        throw std::runtime_error("failed to read input file: " + *input_path);
    }

    uart::init_port(com_port);

    try {
        on_init();
        upload_ram(pointer_cast<byte>(ram_data.data()), ram_data.size());
        upload_input(pointer_cast<byte>(in_data.data()), in_data.size());
        verify_ram(pointer_cast<byte>(ram_data.data()), ram_data.size());
    } catch (const std::exception &e) { throw std::runtime_error("failed to initialize"); }

    // run the program depending on the mode
    try {
        if (mode == 'I') {
            run();
        } else {
            run_auto();
        }
    } catch (const std::exception &e) { throw std::runtime_error("failed to run"); }

    uart::shutdown();
}

int main(int argc, char **argv) {
    if (argc < 4) {
        debug::error("usage: path-to-ram [path-to-input] com-port -I(interactive)/-T(testing)\n");
        return 1;
    }

    try {
        auto input_path = argc < 5 ? std::nullopt : std::optional(argv[2]);
        work(argv[1], input_path, argv[argc - 2], argv[argc - 1][1]);
    } catch (const std::exception &e) {
        debug::error("Fatal error: %s\n", e.what());
        return 1;
    } catch (...) {
        debug::error("Unknown fatal error\n");
        return 1;
    }
}

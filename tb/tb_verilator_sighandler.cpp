#include <csignal>
#include <unistd.h>
#include "verilated.h"

static void sigint_handler(int) {
    Verilated::gotFinish(true);
}

__attribute__((constructor))
static void install_sigint_handler() {
    std::signal(SIGINT, sigint_handler);
    std::signal(SIGTERM, sigint_handler);
}

#include <memory>
#include <iostream>
#include <chrono>
#include <verilated.h>

#ifndef TRACE
#define TRACE 0
#endif

#if TRACE
#include <verilated_fst_c.h>
#endif

#include "VPhiversTB.h"

int main(int argc, char** argv, char** env) {
    const auto contextp = std::make_unique<VerilatedContext>();
    contextp->debug(0);
    contextp->commandArgs(argc, argv);

    const char *flag_to = contextp->commandArgsPlusMatch("timeout=");
    unsigned long int timeout = 0;
    if (flag_to != nullptr) 
        timeout = std::stoul(&flag_to[9])*1'000'000;

    if (timeout)
        std::cout << "Simulating until " << timeout/1'000'000 << "ms" << std::endl;

    const auto top = std::make_unique<VPhiversTB>(contextp.get());

    #if TRACE
        contextp->traceEverOn(true);
        const auto tfp = std::make_unique<VerilatedFstC>();
        top->trace(tfp.get(), 99);
        tfp->open("trace.fst");
    #endif

    auto then = std::chrono::high_resolution_clock::now();

    // Simulate until $finish
    top->rst_n = 0;
    top->clk   = 0;
    while (!contextp->gotFinish()) {
        contextp->timeInc(5);
        top->clk = !top->clk;

        // Toggle control signals on an edge that doesn't correspond
        // to where the controls are sampled; in this example we do
        // this only on a negedge of clk, because we know
        // reset is not sampled there.
        if(!top->clk){
            if (contextp->time() >= 100)
                top->rst_n = 1;
        }

        // Evaluate model
        top->eval();

        #if TRACE
            tfp->dump(contextp->time());
        #endif

        if (timeout && (contextp->time() >= timeout)) {
            std::cerr << std::endl << "Simulation ending due to timeout" << std::endl;
            break;
        }
    }

    #if TRACE
        tfp->close();
    #endif

    auto now = std::chrono::high_resolution_clock::now();
	auto diff = now - then;
	std::cout << std::endl << "Simulation time: " << (contextp->time() / 1'000'000.0) << "ms" << std::endl;
	std::cout << "Wall time: " << std::chrono::duration_cast<std::chrono::duration<double>>(diff).count() << "s" << std::endl;

    return 0;
}

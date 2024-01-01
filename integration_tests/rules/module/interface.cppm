module;

#include <iostream>

export module test;

export void hello() {
    std::cout << "Hello from module\n";
}
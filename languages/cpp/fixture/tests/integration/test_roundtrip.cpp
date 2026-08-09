#include "add.hpp"

int main() {
    if (add(add(1, 1), 3) != 5) {
        return 1;
    }
    return 0;
}

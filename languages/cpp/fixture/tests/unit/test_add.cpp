#include "add.hpp"

// Explicit return codes, not assert(): RelWithDebInfo defines NDEBUG, which compiles every
// assert() to nothing. A test suite built that way passes unconditionally.
int main() {
    if (add(2, 3) != 5) {
        return 1;
    }
    return 0;
}

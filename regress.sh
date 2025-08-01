#!/bin/sh

if [ "$#" -gt 0 ]; then
    make -C tests/regression/ test TESTS="$*"
else
    make -C tests/regression/ test
fi

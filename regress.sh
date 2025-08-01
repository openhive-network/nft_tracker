#!/bin/sh

VERBOSE=""
while getopts "hv" opt; do
    case "$opt" in
        v)
            VERBOSE="VERBOSE=1"
            ;;
        h|\?)
            echo "Usage: $0 [-v] [test_names...]" >&2
            echo "  -v: verbose output for debuging" >&2
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

if [ "$#" -gt 0 ]; then
    make -C tests/regression/ test TESTS="$*" $VERBOSE
else
    make -C tests/regression/ test $VERBOSE
fi

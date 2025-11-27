#!/bin/sh

VERBOSE=""
KEEP_DB=""
while getopts "hvk" opt; do
    case "$opt" in
        v)
            VERBOSE="VERBOSE=1"
            ;;
        k)
            KEEP_DB="KEEP_DB=1"
            ;;
        h|\?)
            echo "Usage: $0 [-v] [-k] [test_names...]" >&2
            echo "  -v: verbose output for debuging" >&2
            echo "  -k: keep test database after completion" >&2
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

if [ "$#" -gt 0 ]; then
    SQLS="$*"
else
    SQLS=$(cd tests/regression && find sql/test_*.sql -print0 | xargs -0 -I{} basename {} .sql | paste -s -d ' ')
fi

for s in $SQLS; do
    expected_file="tests/regression/expected/${s}.out"
    if [ ! -f "$expected_file" ]; then
        touch "$expected_file"
    fi
done

if [ "$#" -gt 0 ]; then
    make -C tests/regression/ test TESTS="$*" $VERBOSE $KEEP_DB
else
    make -C tests/regression/ test $VERBOSE $KEEP_DB
fi

#!/usr/bin/env python3
"""Write a junit report of one pg_regress run: one case per test.

    pg_regress_junit.py JUNIT SUITE PG_REGRESS_LOG

PG_REGRESS_LOG is pg_regress's output (PostgreSQL 16+ TAP-style lines:
``ok 3 - test_issue  21 ms`` / ``not ok 4 - test_modify  30 ms``). A failing case's
body is the test's hunk of tests/regression/regression.diffs, when there is one.
"""
import os
import re
import sys
from xml.sax.saxutils import escape, quoteattr

LINE = re.compile(r"^(not ok|ok)\s+\d+\s+[-+]\s+(\S+)\s+(\d+)\s+ms")


def diffs_by_test(path: str) -> dict:
    """The hunks of regression.diffs, keyed by test name."""
    hunks: dict = {}
    if not os.path.isfile(path):
        return hunks
    current = None
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = re.match(r"^diff .*/(?:expected|results)/([^/\s]+)\.out", line)
            if match:
                current = match.group(1)
                hunks.setdefault(current, [])
            if current:
                hunks[current].append(line)
    return {name: "".join(lines[-200:]) for name, lines in hunks.items()}


def main(junit: str, suite: str, out_file: str) -> None:
    cases = []
    with open(out_file, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = LINE.match(line.strip())
            if match:
                cases.append((match.group(2), match.group(1) == "ok", int(match.group(3)) / 1000))
    diffs = diffs_by_test("tests/regression/regression.diffs")
    body = []
    for name, passed, seconds in cases:
        head = f"<testcase classname={quoteattr(suite)} name={quoteattr(name)} time=\"{seconds}\">"
        if passed:
            body.append(f"{head}</testcase>")
        else:
            body.append(f"{head}<failure message=\"output differs\">{escape(diffs.get(name, ''))}</failure></testcase>")
    failures = sum(1 for case in cases if not case[1])
    os.makedirs(os.path.dirname(junit) or ".", exist_ok=True)
    with open(junit, "w", encoding="utf-8") as handle:
        handle.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        handle.write(
            f"<testsuite name={quoteattr(suite)} tests=\"{len(cases)}\" failures=\"{failures}\" "
            f"errors=\"0\" skipped=\"0\" time=\"{sum(case[2] for case in cases)}\">\n"
        )
        handle.write("\n".join(body) + "\n</testsuite>\n")
    print(f"{len(cases)} pg_regress tests, {failures} failed")


if __name__ == "__main__":
    main(*sys.argv[1:4])

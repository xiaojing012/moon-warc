#!/usr/bin/env python3
"""Count source and test lines of the moon-warc repository.

Usage: python scripts/count_code.py

Counts physical lines, code lines (non-blank, non-comment) and the
number of tests for every .mbt file in the repository, then prints a
summary. Python 3 standard library only.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TEST_RE = re.compile(r"^test\s+")


def mbt_files():
    out = []
    for dirpath, _dirnames, filenames in os.walk(ROOT):
        if ".git" in dirpath or os.sep + "_build" in dirpath:
            continue
        for name in filenames:
            if name.endswith(".mbt"):
                out.append(os.path.join(dirpath, name))
    out.sort()
    return out


def analyze(path):
    physical = 0
    code = 0
    tests = 0
    in_block_comment = False
    with open(path, encoding="utf-8") as f:
        for line in f:
            physical += 1
            stripped = line.strip()
            if in_block_comment:
                if stripped.endswith("*/"):
                    in_block_comment = False
                continue
            if stripped.startswith("/*"):
                if not stripped.endswith("*/"):
                    in_block_comment = True
                continue
            if stripped == "" or stripped.startswith("//"):
                continue
            code += 1
            if TEST_RE.match(stripped):
                tests += 1
    return physical, code, tests


def main():
    rows = []
    total_physical = total_code = total_tests = 0
    for path in mbt_files():
        physical, code, tests = analyze(path)
        total_physical += physical
        total_code += code
        total_tests += tests
        rows.append((os.path.relpath(path, ROOT), physical, code, tests))
    src = [(r[0], r[1], r[2]) for r in rows if not r[0].endswith("_test.mbt")]
    tst = [(r[0], r[1], r[2], r[3]) for r in rows if r[0].endswith("_test.mbt")]
    src_physical = sum(r[1] for r in src)
    src_code = sum(r[2] for r in src)
    tst_physical = sum(r[1] for r in tst)
    tst_code = sum(r[2] for r in tst)
    print(f"files: {len(rows)} (source {len(src)}, test {len(tst)})")
    print(f"source lines: {src_physical} physical, {src_code} code")
    print(f"test lines:   {tst_physical} physical, {tst_code} code")
    print(f"total lines:  {total_physical} physical, {total_code} code")
    print(f"tests: {total_tests}")
    print()
    for rel, physical, code, tests in tst:
        print(f"  {rel:<28} {tests:>3} tests  {code:>5} code lines")
    return 0


if __name__ == "__main__":
    sys.exit(main())

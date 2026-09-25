#!/usr/bin/env bash
# Checks the basic functionality of meta-jq against the reference data in
# test/data, with every jq engine given as argument (default: jq, gojq and fq,
# the ones found on PATH).
#
# By default the repo itself is used as module (as in the "simple setup").
# To test an installed copy, set:
#   META_JQ_LIB     search path to pass to -L (e.g. jq_modules, lib)
#   META_JQ_MODULE  module name to import (e.g. miguel76/meta-jq, meta-jq)
# fq does not look for `name/name.jq` when importing `name`, so for fq the
# last path component is appended to the module name automatically.

set -u

cd "$(dirname "$0")"
DATA="$PWD/data"

if [ -z "${META_JQ_LIB:-}" ]; then
    META_JQ_LIB="$(mktemp -d)"
    trap 'rm -rf "$META_JQ_LIB"' EXIT
    ln -s "$(cd .. && pwd)" "$META_JQ_LIB/meta-jq"
    META_JQ_MODULE="meta-jq"
fi
META_JQ_LIB="$(cd "$META_JQ_LIB" && pwd)"
META_JQ_MODULE="${META_JQ_MODULE:-meta-jq}"

if [ $# -eq 0 ]; then
    for engine in jq gojq fq; do
        command -v "$engine" >/dev/null && set -- "$@" "$engine"
    done
fi
[ $# -gt 0 ] || { echo "no jq engine found" >&2; exit 1; }

failures=0

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" == "$actual" ]; then
        echo "  ok    $name"
    else
        echo "  FAIL  $name"
        diff <(echo "$expected") <(echo "$actual") | head -20 | sed 's/^/        /'
        failures=$((failures + 1))
    fi
}

for engine in "$@"; do
    module="$META_JQ_MODULE"
    [ "$(basename "$engine")" = fq ] && module="$module/${module##*/}"
    run() { "$engine" -L "$META_JQ_LIB" "import \"$module\" as meta; $1" "${@:2}" 2>&1; }

    echo "== $engine ($("$engine" --version 2>&1 | head -1)), import \"$module\" from $META_JQ_LIB"

    check "AST to algebra" \
        "$(jq -S . "$DATA/flow-async.fq-algebra.json")" \
        "$(run 'meta::ast_to_algebra' "$DATA/flow-async.fq.json" | jq -S . 2>&1)"

    check "algebra to string (pretty)" \
        "$(cat "$DATA/flow-async-out.fq.jq")" \
        "$(run 'meta::algebra_tostring(4)' -r "$DATA/flow-async.fq-algebra.json")"

    check "AST to string (identity traversal)" \
        '.a|.b' \
        "$(run 'meta::ast_to_algebra | meta::traverse_expr(.; .; .; .) | meta::algebra_tostring' -r \
            <<<'{"left":{"term":{"index":{"name":"a"},"type":"TermTypeIndex"}},"op":"|","right":{"term":{"index":{"name":"b"},"type":"TermTypeIndex"}}}')"

    check "traversal rewriting an expression" \
        '.a|.c' \
        "$(run 'meta::traverse_expr(if .type == "Key" and .name == "b" then .name = "c" end; .; .; .) | meta::algebra_tostring' -r \
            <<<'{"op":"|","operands":[{"name":"a","type":"Key"},{"name":"b","type":"Key"}],"type":"NaryOp"}')"

    if [ "$(basename "$engine")" = fq ]; then
        check "text to text round trip (fq _query_fromstring)" \
            '.a|.b' \
            "$(run '$q | _query_fromstring | meta::ast_to_algebra | meta::algebra_tostring' -rn --arg q '.a | .b')"
    fi
done

if [ $failures -gt 0 ]; then
    echo "$failures check(s) failed"
    exit 1
fi
echo "all checks passed"

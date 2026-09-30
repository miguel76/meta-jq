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

if [ -n "${META_JQ_LIB:-}" ]; then
    META_JQ_LIB="$(cd "$META_JQ_LIB" && pwd)" || exit 1
fi

cd "$(dirname "$0")"
DATA="$PWD/data"

if [ -z "${META_JQ_LIB:-}" ]; then
    META_JQ_LIB="$(mktemp -d)"
    trap 'rm -rf "$META_JQ_LIB"' EXIT
    ln -s "$(cd .. && pwd)" "$META_JQ_LIB/meta-jq"
    META_JQ_MODULE="meta-jq"
fi
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

        # query, then its expected serialization (without pretty printing);
        # the serialization must also be parsed back to the same algebra
        while IFS=$'\t' read -r query expected; do
            check "round trip: $query" \
                "$expected" \
                "$(run '($q | _query_fromstring | meta::ast_to_algebra) as $a |
                    ($a | meta::algebra_tostring) as $s |
                    if ($s | _query_fromstring | meta::ast_to_algebra) == $a then $s
                    else "\($s) (parsed back to a different algebra)"
                    end' -rn --arg q "$query")"
        done <<'EOF'
(1 + 2) * 3	(1+2)*3
1 - (2 - 3)	1-(2-3)
(1 - 2) - 3	1-2-3
(1, 2) // 3	(1,2)//3
- (1 + 2)	-(1+2)
a and (b or c)	a and (b or c)
.[]?	.[]?
f?	f?
.[1]?	.[1]?
(.a | .b)? | .c	(.a|.b)?|.c
."a"	.a
.a."b"	.a|.b
."a b"	."a b"
.a."b\(.c)"	.a|."b\(.c)"
{"a\(.b)": 1, "y\(.)": 2, "c": 3}	{"a\(.b)":1,"y\(.)":2,"c":3}
{a: 1 + 2, b: -1, c: .d}	{a:(1+2),b:(-1),c:.d}
"a\"b\(.x)\n"	"a\"b\(.x)\n"
null	null
.[] as {"a": $x, "b\(.c)": $y, (.k): $z} ?// [$x] | $x	.[] as {"a":$x,"b\(.c)":$y,(.k):$z} ?// [$x] | $x
(.a | length) as $n | $n	(.a|length) as $n | $n
1 + (. as $x | $x)	1+(. as $x | $x)
reduce (.a | .[]) as $x (0; . + $x)	reduce (.a|.[]) as $x (0;.+$x)
(try 1) + 2	try 1+2
try (1 + 2) catch (3 | 4)	try (1+2) catch (3|4)
1 + (def f: 2; f)	1+(def f: 2; f)
def f: 1;	def f: 1;
import "a" as a; def f: a::g;	import "a" as a; def f: a::g;
EOF
    fi
done

if [ $failures -gt 0 ]; then
    echo "$failures check(s) failed"
    exit 1
fi
echo "all checks passed"

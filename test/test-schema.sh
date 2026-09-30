#!/usr/bin/env bash
# Validates jq algebra documents against schema/jq-algebra.schema.json:
# the reference data in test/data and, when fq is available (on PATH, or given
# as argument), the algebra of a set of sample queries parsed with fq.
#
# Requires python3 with the jsonschema package (pip install jsonschema).

set -u

cd "$(dirname "$0")"
SCHEMA="$PWD/../schema/jq-algebra.schema.json"
FQ="${1:-fq}"

python3 -c 'import jsonschema' 2>/dev/null ||
    { echo "python3 with the jsonschema package is required" >&2; exit 1; }

# Reads lines `{"name": ..., "algebra": ...}` and validates each algebra.
validate() {
    python3 -c '
import json, sys
from jsonschema import Draft202012Validator
schema = json.load(open(sys.argv[1]))
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema)
failures = 0
for line in sys.stdin:
    doc = json.loads(line)
    errors = list(validator.iter_errors(doc["algebra"]))
    if errors:
        failures += 1
        print("  FAIL  %s" % doc["name"])
        for error in errors[:3]:
            print("        %s: %s" % ("/".join(map(str, error.absolute_path)), error.message[:200]))
    else:
        print("  ok    %s" % doc["name"])
sys.exit(1 if failures else 0)
' "$SCHEMA"
}

failures=0

echo "== reference data"
for file in data/*algebra.json; do
    jq -c --arg name "$file" '{name: $name, algebra: .}' "$file"
done | validate || failures=$((failures + 1))

# Documents that must be rejected.
echo "== invalid documents (must fail)"
while read -r doc; do
    if jq -c '{name: tojson, algebra: .}' <<<"$doc" | validate >/dev/null; then
        echo "  FAIL  accepted $doc"
        failures=$((failures + 1))
    else
        echo "  ok    rejected $doc"
    fi
done <<'EOF'
{}
{"type": "Nope"}
{"type": "Identity", "name": "a"}
{"type": "NaryOp", "op": "|", "operands": [{"type": "Identity"}]}
{"type": "NaryOp", "op": "+", "operands": [{"type": "Identity"}, {"type": "Identity"}]}
{"type": "Key", "name": "a", "query": {"type": "Identity"}}
{"type": "Bind", "value": {"type": "Identity"}, "patterns": [{"name": "x"}], "scope": {"type": "Identity"}}
{"type": "Null"}
{"type": "Literal", "value": [1]}
{"type": "Object", "key_vals": [{"key_string": {"str": "a"}, "val": {"type": "Identity"}}]}
{"type": "Object", "key_vals": [{"key_string": {"type": "Identity"}, "val": {"type": "Identity"}}]}
{"type": "Bind", "value": {"type": "Identity"}, "patterns": [{"object": [{"key_query": {"term": {"type": "TermTypeIdentity"}}, "val": {"name": "$x"}}]}], "scope": {"type": "Identity"}}
{"type": "Bind", "value": {"type": "Identity"}, "patterns": [{"object": [{"key_string": {"str": "a"}, "val": {"name": "$x"}}]}], "scope": {"type": "Identity"}}
{"func_defs": []}
{"func_defs": [{"name": "f", "body": {"type": "Identity"}}], "optional": true}
EOF

if command -v "$FQ" >/dev/null; then
    lib="$(mktemp -d)"
    trap 'rm -rf "$lib"' EXIT
    ln -s "$(cd .. && pwd)" "$lib/meta-jq"
    echo "== sample queries parsed with $FQ"
    while IFS= read -r query; do
        "$FQ" -L "$lib" -nc --arg q "$query" \
            'import "meta-jq/meta-jq" as meta; {name: $q, algebra: ($q | _query_fromstring | meta::ast_to_algebra)}' ||
            echo "{\"name\": $(jq -Rn --arg q "$query" '$q | tojson'), \"algebra\": null}"
    done <<'EOF' | validate || failures=$((failures + 1))
.
..
.[]?
.a.b[0]
.a?
.[1]?
."a"
.a."b"
.a."b\(.c)"
.[1:]
.[:2]
null
[null, true, false]
42
"abc"
"a\(.x)b"
@base64
@uri "x=\(.x)"
$__loc__
f(.; 1)
-.a
[]
[.[] | .id]
{a, $b, "c": 1, (.d): 2, $x: 3, "e"}
{"a\(.b)": 1, "y\(.)": 2}
(1 + 2) * 3
(.a | .b)? | .c
.a |= . + 1
1 // 2 // 3
1, 2 | 3
a and b or c
if . then 1 elif 2 then 3 else 4 end
try error catch .
f?
(1, 2)?
label $out | 1, break $out
reduce .[] as [$a, $b] (0; . + $a)
foreach .[] as $x (0; . + 1; [$x])
foreach .[] as {a: $x, $y, $w: [$v]} (0; .)
.[] as [$a] ?// $a | $a
. as {"a": $x, "b\(.c)": $y, (.k): $z, $w: [$v]} | $x
reduce .[] as {(.k): $x} (0; . + $x)
def f: 1;
module {name: "lib"}; import "a" as a; def f: a::g;
def inc($n): . + $n; def twice(f): f | f; twice(inc(1))
module {name: "example"}; import "lib" as lib; import "data" as $data {search: "./"}; include "helpers"; .
EOF
else
    echo "== sample queries skipped ($FQ not found)"
fi

if [ $failures -gt 0 ]; then
    echo "$failures group(s) of checks failed"
    exit 1
fi
echo "all checks passed"

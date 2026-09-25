#!/usr/bin/env bash
# Regenerates the reference data in test/data with fq (see test.sh for the checks)

set -e
cd "$(dirname "$0")"

lib="$(mktemp -d)"
trap 'rm -rf "$lib"' EXIT
ln -s "$(cd .. && pwd)" "$lib/meta-jq"

fq --raw-input --slurp '_query_fromstring' <data/flow-async.jq >data/flow-async.fq.json
fq -L "$lib" 'import "meta-jq/meta-jq" as meta; meta::ast_to_algebra' <data/flow-async.fq.json >data/flow-async.fq-algebra.json
fq -L "$lib" --raw-output 'import "meta-jq/meta-jq" as meta; meta::algebra_tostring(4)' <data/flow-async.fq-algebra.json >data/flow-async-out.fq.jq

#!/usr/bin/env bash

fq --raw-input --slurp '_query_fromstring' <data/flow-async.jq >data/flow-async.fq.json
# fq --from-file 'test-traverse.jq' <test/flow-async.json >test/traverse-output.json
fq --raw-output --from-file 'jq/test-serialize.jq' <data/flow-async.fq.json >data/flow-async-out.fq.jq
#!/usr/bin/env bash

fq --raw-input --slurp '_query_fromstring' <data/flow-async.jq >data/flow-async.fq.json
# fq --from-file 'test-traverse.jq' <test/flow-async.json >test/traverse-output.json
#fq --raw-output --from-file 'jq/test-serialize.jq' <data/flow-async.fq.json >data/flow-async-out.fq.jq
#fq -L '.' --raw-output 'import "test" as t; t::test_serialize' <data/flow-async.fq.json >data/flow-async-out.fq.jq
fq -L '.' 'import "test" as t; t::test_to_algebra' <data/flow-async.fq.json >data/flow-async.fq-algebra.json
fq -L '.' --raw-output 'import "test" as t; t::test_serialize' <data/flow-async.fq-algebra.json >data/flow-async-out.fq.jq
#fq 'import "jq/test" as t; t::module_info' <data/flow-async.fq.json >data/modulemeta.json

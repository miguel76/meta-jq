def ast_to_algebra:
    {
        "|": {
            identity: {type: "Identity"}
        },
        ",": {
            identity: {type: "Func", name: "empty"}
        },
        "//": {
            identity: {type: "Func", name: "empty"}
        }
    } as $nary_ops |

    def meta_to_json:
        def internal_to_json:
            if .object then
                [ .object.keyvals[] | {
                    key,
                    value: (.val | internal_to_json)
                } ] | from_entries
            elif .array then
                [.array.elems[] | internal_to_json]
            elif .str then .str
            elif .number then .number | tonumber
            elif .true then true
            elif .false then false
            elif .null then null
            end;
        {object: .} | internal_to_json;

    def simplify_op:
        if .type == "NaryOp" then
            .op as $op |
            $nary_ops[$op].identity as $identity |
            (.operands |= [ .[] |
                if . == $identity then
                    empty
                elif .type == "NaryOp" and .op == $op then
                    .operands[]
                end
            ]) |
            if .operands | length == 0 then
                $identity
            elif .operands | length == 1 then
                .operands[0]
            end
        end;

    def _f:
        def convert_str:
            if .queries then
                {
                    type: "StringInterpolation",
                    fragments: .queries | [
                        .[] |
                        if .term.type == "TermTypeString" then
                            {
                                type: "FixedString",
                                value: .term.str.str
                            }
                        else 
                            {
                                type: "InterpolatedString",
                                query: (. | _f)
                            }
                        end
                    ]
                }
            elif .str then
                {type: "Literal", value: .str}
            end;

        def _index:
            if .is_slice then
                . as $source |
                {
                    type: "Slice",
                } |
                if $source.start then .start = ($source.start | _f) end |
                if $source.end then .end = ($source.end | _f) end
            elif .start then
                {
                    type: "Index",
                    index: .start | _f
                }
            elif .name then
                {
                    type: "Key",
                    name: .name
                }
            elif .str then
                {
                    type: "Key",
                    query: .str | _f
                }
            else error("unsupported type of index: \(.)")
            end;

        (.meta | if . then meta_to_json end) as $module_meta | 
        (.imports | if . then [.[] | .meta |= meta_to_json] end) as $imports |
        if .func_defs then
            .func_defs | [.[] | .body |= _f]
        else
            null
        end as $func_defs |
        if .term.type then
            .term | (
                .type[8:] as $type |
                del(.type) |
                .suffix_list as $suffix_list |
                if $type == "String" then .str |
                    convert_str
                elif $type == "Format" then
                    if .str then .str |= convert_str end
                elif $type == "Number" then
                    {type: "Literal", value: .number | tonumber}
                elif $type == "True" then
                    {type: "Literal", value: true}
                elif $type == "False" then
                    {type: "Literal", value: false}
                elif $type == "Unary" then
                    .unary | {
                        type: "UnaryOp",
                        op: .op,
                        operand: {term:.term} | _f
                    }
                elif $type == "Index" then
                    .index | _index
                elif $type == "Func" then .func |
                    if .args then
                        .args |= [.[] | _f]
                    end
                elif $type == "Object" then .object |
                    .key_vals |= [
                        .[] |
                        if .key_query then .key_query |= _f end |
                        if .val then .val |=
                            if .queries then
                                .queries |= [.[] | _f]
                            else _f
                            end
                        end
                    ]
                elif $type == "Array" then .array |
                    if .query then .query |= _f end
                elif $type == "If" then 
                    .if |
                        (.cond |= _f) |
                        (.then |= _f) |
                        if .elif then .elif |= [
                            .[] |
                            (.cond |= _f) |
                            (.then |= _f)
                        ] end |
                        if .else then .else |= _f end
                elif $type == "Reduce" then
                    .reduce |
                        (.term |= _f) |
                        (.start |= _f) |
                        (.update |= _f)
                elif $type == "Foreach" then
                    .foreach |
                        (.term |= _f) |
                        (.start |= _f) |
                        (.update |= _f)
                elif $type == "Query" then
                    .query | _f
                elif $type == "Try" then
                    .try |
                        (.body |= _f) |
                        if .catch then .catch |= _f end
                end |
                if .type | not then
                    .type = ($type | if . == "Unary" then "UnaryOp" end)
                end |
                if $suffix_list then
                    {
                        type: "NaryOp",
                        op: "|",
                        operands: reduce(
                            $suffix_list.[] |
                            if .index then .index | _index
                            elif .bind then empty
                            end
                        ) as $suffix (
                            [.];
                            if $suffix.iter then [.[],{type: "Iterator"}]
                            elif $suffix.optional then .[-1] |= (.optional = true)
                            else [.[], $suffix]
                            end
                        ) | del(.[0].suffix_list)
                    } |
                    if $suffix_list[-1].bind then
                        {
                            type: "Bind",
                            value: . | simplify_op,
                            scope: $suffix_list[-1].bind.body | _f,
                            patterns: $suffix_list[-1].bind.patterns
                        }
                    end
                end 
            )
        elif .op then 
            if .op | in($nary_ops) then {
                type: "NaryOp",
                op: .op,
                operands: [(.left | _f), (.right | _f)]
            } else {
                type: "BinaryOp",
                op: .op,
                leftOperand: .left | _f,
                rightOperand: .right | _f
            } end
        else error("unsupported term: \(.)")
        end |
        if $module_meta then
            .meta = $module_meta
        end |
        if $imports then
            .imports = $imports
        end |
        if $func_defs then
            .func_defs = $func_defs
        end |
        simplify_op;

    _f;

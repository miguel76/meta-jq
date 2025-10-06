def traverse_expr(visit_expr; visit_pattern; visit_import; visit_func_def):
    def _pattern:
        if .array then .array |= [.[] | _pattern]
        elif .object then .object |= [.[] |
            if .val then
                .val |= _pattern
            end
        ]
        end | visit_pattern;
    def _f:
        if .imports then
            .imports |= [.[] | visit_import]
        end |
        if .func_defs then
            .func_defs |= [.[] | .body |= _f | visit_func_def]
        end |
        if .type == "Format" then
            if .str then
                .str |= _f
            end
        elif .type == "StringInterpolation" then
            if .fragments then
                .fragments |= [.[] | _f]
            end
        elif .type == "InterpolatedString" then
            .query |= _f
        elif .type == "Index" then
            .index |= _f 
        elif .type == "Key" then
            if .query then .query |= _f end
        elif .type == "Slice" then
            if .start then .start |= _f end |
            if .end then .end |= _f end
        elif .type == "Func" then
            if .args then
                .args |= [.[] | _f]
            end
        elif .type == "Object" then
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
        elif .type == "Array" then
            if .query then .query |= _f end
        elif .type == "If" then 
            (.cond |= _f) |
            (.then |= _f) |
            if .elif then .elif |= [
                .[] |
                (.cond |= _f) |
                (.then |= _f)
            ] end |
            if .else then .else |= _f end
        elif .type == "Foreach" then
            (.term |= _f) |
            (.pattern |= _pattern) |
            (.start |= _f) |
            (.update |= _f)
        elif .type == "Reduce" then
            (.query |= _f) |
            (.pattern |= _pattern) |
            (.start |= _f) |
            (.update |= _f)
        elif .type == "Bind" then
            (.scope |= _f) |
            (.value |= _f) |
            (.patterns |= [.[] | _pattern])
        elif .type == "Try" then
            (.body |= _f) |
            if .catch then .catch |= _f end
        elif .type == "Label" then
            (.body |= _f)
        elif .type == "UnaryOp" then
            .operand |= _f
        elif .type == "BinaryOp" then
            (.leftOperand |= _f) |
            (.rightOperand |= _f)
        elif .type == "NaryOp" then
            .operands |= [.[] | _f]
        end |
        visit_expr;
    _f;

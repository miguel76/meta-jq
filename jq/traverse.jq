def traverse_expr(visit_expr; visit_pattern; visit_import; visit_func_def):
    def _pattern:
        if .array then .array |= [.[] | _pattern]
        elif .object then .object |= [.[] | .val |= _pattern]
        end | visit_pattern;
    def _f:
        debug |
        if .imports then
            .imports |= [.[] | visit_import]
        end |
        if .func_defs then
            .func_defs |= [.[] | .body |= _f | visit_func_def]
        end |
        if .type == "String" or .type == "Format" then
            if .queries then
                .queries |= [.[] | _f]
            end
        elif .type == "Index" then
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
        elif .type == "Reduce" or .type == "Foreach" then
            (.term |= _f) |
            (.pattern |= _pattern) |
            (.start |= _f) |
            (.update |= _f)
        elif .type == "Try" then
            (.body |= _f) |
            if .catch then .catch |= _f end
        elif .type == "UnaryOp" then
            .operand |= _f
        elif .type == "BinaryOp" then
            (.leftOperand |= _f) |
            (.rightOperand |= _f)
        elif .type == "NaryOp" then
            .operands |= [.[] | _f] | debug
        end |
        visit_expr;
    _f;

def traverse_ast(visit_expr; visit_pattern; visit_index; visit_suffix; visit_func_def):
    def _pattern:
        if .array then .array |= [.[] | _pattern]
        elif .object then .object |= [.[] | .val |= _pattern]
        end | visit_pattern;
    def _f:
        def _index:
            if .start then .start |= _f end |
            if .end then .end |= _f end |
            visit_index;
        if .func_defs then
            .func_defs |= [.[] | .body |= _f | visit_func_def]
        end |
        if .term.type then
            .term |= (
                if .type == "TermTypeString" or .type == "TermTypeFormat" then .str |=
                    if .queries then
                        .queries |= [.[] | _f]
                    end
                elif .type == "TermTypeUnary" then
                    .unary |= _f
                elif .type == "TermTypeIndex" then
                    .index |= _index
                elif .type == "TermTypeFunc" then
                    if .func.args then
                        .func.args |= [.[] | _f]
                    end
                elif .type == "TermTypeObject" then
                    .object.key_vals |= [
                        .[] |
                        if .key_query then .key_query |= _f end |
                        if .val then .val |=
                            if .queries then
                                .queries |= [.[] | _f]
                            else _f
                            end
                        end
                    ]
                elif .type == "TermTypeArray" then
                    if .array.query then .array.query |= _f end
                elif .type == "TermTypeIf" then 
                    .if |=
                        (.cond |= _f) |
                        (.then |= _f) |
                        if .elif then .elif |= [
                            .[] |
                            (.cond |= _f) |
                            (.then |= _f)
                        ] end |
                        if .else then .else |= _f end
                elif .type == "TermTypeReduce" then
                    .reduce |=
                        (.term |= _f) |
                        (.pattern |= _pattern) |
                        (.start |= _f) |
                        (.update |= _f)
                elif .type == "TermTypeForeach" then
                    .foreach |=
                        (.term |= _f) |
                        (.pattern |= _pattern) |
                        (.start |= _f) |
                        (.update |= _f)
                elif .type == "TermTypeQuery" then
                    .query |= _f
                elif .type == "TermTypeTry" then
                    .try |=
                        (.body |= _f) |
                        if .catch then .catch |= _f end
                end |
                if .suffix_list then
                    .suffix_list |= [
                        .[] |
                        if .index then .index |= _index
                        elif .bind then .bind |=
                            (.body |= _f) |
                            (.patterns |= [.[] | _pattern])
                        end |
                        visit_suffix
                    ]
                end
            )
        elif .op then
            (.left |= _f) |
            (.right |= _f)
        else error("unsupported query: \(.)")
        end |
        visit_expr;
    _f;

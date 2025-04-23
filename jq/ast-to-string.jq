import "traverse" as t;

def ast_tostring($space):

    ($space | (numbers | . * " ") // .) as $indent_str | 


    def new_line:
        if $indent_str then "\n" else "" end;

    def indent_block:
        if $indent_str then
            "\([splits("\n") | $indent_str + . | rtrimstr(" ")] | join("\n"))\n"
        end;

    def serialize_str:
        if .str then
            .str | tojson
        else [
            .queries[] |
            if .[0:1] == "\""
                then .[1:-1]
                else "\\\(.)"
            end
        ] | join("") | "\"\(.)\""
        end;

    def serialize_expr: "\(
        if .func_defs then
            "\(.func_defs | join(""))"
        else ""
        end
    )\(
        if .term.type then
            .term | "\(
                if .type == "TermTypeNull" then "null"
                elif .type == "TermTypeNumber" then .number | tostring
                elif .type == "TermTypeString" then .str | serialize_str
                elif .type == "TermTypeFormat" then "\(.format) \(.str | serialize_str)" 
                elif .type == "TermTypeTrue" then "true"
                elif .type == "TermTypeFalse" then "false"
                elif .type == "TermTypeIdentity" then "."
                elif .type == "TermTypeUnary" then .unary | "\(.op)\({term: .term})"
                elif .type == "TermTypeIndex" then .index
                elif .type == "TermTypeFunc" then "\(.func.name)\(
                    if .func.args then
                        .func.args | join("; ") | "(\(.))"
                    else
                        ""
                    end
                )"
                elif .type == "TermTypeObject" then
                    ( .object.key_vals | "{\(
                        [ .[] |
                            "\(new_line)\(
                                if .key then .key
                                elif .key_string then .key_string.str | tojson
                                else "(\(.key_query))"
                                end
                            )\(
                                if .val then 
                                    .val |
                                    if [objects] | any and .queries then
                                        .queries | join(", ")
                                    end |
                                    ": \(.)"
                                else ""
                                end
                            )"
                        ] | join(", ") | indent_block
                    )}" )
                elif .type == "TermTypeArray" then .array | "[\(if .query then .query else "" end)]"
                elif .type == "TermTypeIf" then .if |
                    "\(new_line)if \(.cond) then \(.then) \(
                        if .elif then [
                            .elif.[] |
                            "\(new_line)elif \(.cond) then \(.then) "
                        ] | join("")
                        else ""
                        end
                    )\(
                        if .else then "\(new_line)else \(.else) " else "" end
                    )\(new_line)end"
                elif .type == "TermTypeReduce" then .reduce |
                    "reduce \({term: .term}) as \(.pattern) (\(.start);\(.update))"
                elif .type == "TermTypeForeach" then .foreach |
                    "foreach \({term: .term}) as \(.pattern) (\(.start);\(.update)\(
                        if .extract then ";\(.extract)" else "" end
                    ))"
                elif .type == "TermTypeQuery" then "(\(.query))"
                elif .type == "TermTypeTry" then .try |
                    "try \(.body)\(if .catch then " catch \(.catch)" else "" end)" 
                else error("unsupported term: \(.)")
                end
            )\(
                if .suffix_list then
                    .suffix_list | join("")
                else ""
                end
            )"
        elif .op then
            (if .op | . == "," then "" else " " end) as $pad |
            "\(.left)\($pad)\(.op) \(.right)"
        else error("unsupported query: \(.)")
        end
    )";

    def serialize_pattern:
        if .name then .name
        elif .array then "[\(.array | join(", "))]"
        elif .object then
        "{\(
            [.object[] | "\(
            if .key then .key else .key_string.str | tojson end
            )\(
            if .val then ": \(.val)" else "" end
            )"] |
            join(", ")
        )}"
        else error("unsupported type of pattern: \(.)")
        end;

    def serialize_index:
        ".\(
            if .start or .is_slice then
            "[\(
                if .start then .start else "" end
            )\(
                if .is_slice then ":" else "" end
            )\(
                if .end then .end else "" end
            )]"
            elif .name then .name
            elif .str then .str.str | tojson
            else error("unsupported type of index: \(.)")
            end
        )";

    def serialize_suffix:
        if .index then .index
        elif .bind then .bind | " as \(.patterns | join(", ")) | \(.body)"
        elif .iter then "[]"
        elif .optional then "?"
        else error("unsupported suffix type: \(.)")
        end;

    def serialize_func_def:
        "def \(.name)\(
            if .args then "(\(.args | join("; ")))"
            else ""
            end
        ):\("\(new_line)\(.body); " | indent_block)\(new_line)";

    t::traverse_ast(serialize_expr; serialize_pattern; serialize_index; serialize_suffix; serialize_func_def);

def ast_tostring:
    ast_tostring(null);
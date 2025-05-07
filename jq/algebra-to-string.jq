import "traverse" as t;

def algebra_tostring($space):

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

    def serialize_json:
        to_entries | "{\(
            [ .[] | 
                "\(new_line)\(.key): \(.value)"
            ] | join(", ") | indent_block
        )}";

    def serialize_keyvals:
        "{\(
            [ .[] |
                "\(new_line)\(
                    if .key then .key
                    elif .key_string then .key_string.str | tojson
                    else "(\(.key_query))"
                    end | debug
                )\(
                    if .val then 
                        .val |
                        if .queries then
                            .queries | join(", ")
                        end |
                        ": \(.)"
                    else ""
                    end
                )" | debug 
            ] | join(", ") | indent_block
        )}";

    def serialize_expr:
        if .meta then
            "module \(.meta | serialize_json);\(new_line)\(new_line)"
        else 
            empty
        end as $module_decl |
        "\(
            [$module_decl, .imports[]?, .func_defs[]?] | join("")
        )\(
            if .type == "Null" then "null"
            elif .type == "Number" then .number | tostring
            elif .type == "String" then .str | serialize_str
            elif .type == "Format" then "\(.format) \(.str | serialize_str)" 
            elif .type == "True" then "true"
            elif .type == "False" then "false"
            elif .type == "Identity" then "."
            elif .type == "UnaryOp" then "\(.op)\(.operand)"
            elif .type == "BinaryOp" then "\(.leftOperand)\(.op)\(.rightOperand)"
            elif .type == "NaryOp" then .op as $op | .operands | join($op)
            elif .type == "Index" then
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
                )"
            elif .type == "Func" then "\(.func.name)\(
                if .func.args then
                    .func.args | join("; ") | "(\(.))"
                else
                    ""
                end
            )"
            elif .type == "Object" then .key_vals | serialize_keyvals
            elif .type == "Array" then "[\(if .query then .query else "" end)]"
            elif .type == "If" then
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
            elif .type == "Reduce" then
                "reduce \({term: .term}) as \(.pattern) (\(.start);\(.update))"
            elif .type == "Foreach" then
                "foreach \({term: .term}) as \(.pattern) (\(.start);\(.update)\(
                    if .extract then ";\(.extract)" else "" end
                ))"
            elif .type == "Try" then
                "try \(.body)\(if .catch then " catch \(.catch)" else "" end)" 
            else error("unsupported expression: \(.)")
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

    def serialize_suffix:
        if .index then .index
        elif .bind then .bind | " as \(.patterns | join(", ")) | \(.body)"
        elif .iter then "[]"
        elif .optional then "?"
        else error("unsupported suffix type: \(.)")
        end;

    def serialize_import:
        "\(
            if .import_path then
                "import \(.import_path) as \(.import_alias)"
            elif .include_path then
                "include \(.include_path)"
            else error("unsupported import type: \(.)")
            end
        )\(
            if .meta then " \(.meta | serialize_json)"
            else ""
            end
        );\(new_line)\(new_line)";

    def serialize_func_def:
        "def \(.name)\(
            if .args then "(\(.args | join("; ")))"
            else ""
            end
        ):\("\(new_line)\(.body); " | indent_block)\(new_line)";

    t::traverse_expr(serialize_expr; serialize_pattern; serialize_import; serialize_func_def);

def algebra_tostring:
    algebra_tostring(null);
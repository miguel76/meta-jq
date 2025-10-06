import "traverse" as t;

def algebra_tostring($space):

    # https://github.com/jqlang/jq/wiki/jq-Language-Description#operators-priority
    # TODO: check https://github.com/jqlang/jq/issues/2425#issue-1199153017

# Operator	Description

# x?	Error Suppression
# -x	Negative
# *, /, %	Multiplication, Division, Modulo
# +, -	Addition, Subtraction
# ==, !=, <, >,<=, >=	Comparisons
# and	Boolean AND
# or	Boolean OR
# =, |=, +=, -=, *=, /=, %=	Update-assignment
# //	Alternative
# ,	Comma
# |	Pipe
# label $variable	Labels
# try … catch …	Try expression
# if … then … end	Conditional expression
# foreach … as … (…)	Loop expression
# reduce … as … (…)	Reduce expression
# … as $variable	Variable definition expression
# def … ; …	Function expression

[
    {
        type: "UnaryOp",
        op: "-"
    },
    {
        type: "BinaryOp",
        op: [
            ["*", "/", "%"],
            ["+", "-"],
            ["==", "!=", "<", ">", "<=", ">="],
            ["and"],
            ["or"],
            ["=", "|=", "+=", "-=", "*=", "/=", "%=", "//="],
            ["//"],
            [","],
            ["|"]
        ]
    },
# label $variable	Labels
    "Try",
    "If",
    "Foreach",
    "Reduce",
    "Bind"
] as $expr_types_by_prec |

    [
        ["?//"],
        ["?"],
        ["-"],
        ["*", "/", "%"],
        ["+", "-"],
        ["==", "!=", "<", ">", "<=", ">="],
        ["and"],
        ["or"],
        ["=", "|=", "+=", "-=", "*=", "/=", "%=", "//="],
        ["//"],
        [","],
        ["|"]
    ] as $op_lists_by_prec | 

    (
        $op_lists_by_prec | keys |
        [
            .[] |
            . as $prec |
            $op_lists_by_prec[.].[] |
            {key: ., value: $prec}
        ] |
        from_entries
    ) as $op_prec |

    ($space | (numbers | . * " ") // .) as $indent_str | 

    def new_line:
        if $indent_str then "\n" else "" end;

    def indent_block:
        if $indent_str then
            "\([splits("\n") | $indent_str + . | rtrimstr(" ")] | join("\n"))\n"
        end;

    def sep:
        if $indent_str then " " else "" end;

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
        if $indent_str then
            (objects |
                to_entries | "{\(
                    [ .[] | 
                        "\(new_line)\(.key): \(.value | serialize_json)"
                    ] | join(", ") | indent_block
                )}"
            ) //
            "[\(arrays | join(", "))]" //
            tojson
        else
            tojson
        end;

    def serialize_keyvals:
        "{\(
            [ .[] |
                "\(new_line)\(
                    if .key then .key
                    elif .key_string then .key_string.str | tojson
                    else "(\(.key_query))"
                    end
                )\(
                    if .val then 
                        .val |
#                        if .queries then
#                            .queries | join(", ")
#                        end |
                        ":\(sep)\(.)"
                    else ""
                    end
                )" 
            ] | join(",\(sep)") | indent_block
        )}";

    def serialize_expr:
        if .meta then
            "module \(.meta | serialize_json);\(new_line)\(new_line)"
        else 
            ""
        end as $module_decl |
        "\(
            [$module_decl, .imports[]?, .func_defs[]?] | join("")
        )\(
            if .type == "Null" then "null"
            elif .type == "Literal" then .value | tojson
            elif .type == "FixedString" then .value
            elif .type == "InterpolatedString" then "\\(\(.query))"
            elif .type == "StringInterpolation" then
                "\"\(.fragments | join(""))\""
            elif .type == "Format" then "\(.format)\(if .str then " \(.str)" else "" end)" 
            elif .type == "True" then "true"
            elif .type == "False" then "false"
            elif .type == "Identity" then "."
            elif .type == "Iterator" then ".[]"
            elif .type == "UnaryOp" then "\(.op)\(.operand)"
            elif .type == "BinaryOp" then "\(.leftOperand)\(sep)\(.op)\(sep)\(.rightOperand)"
            elif .type == "NaryOp" then .op as $op | .operands | join("\(sep)\($op)\(sep)")
            elif .type == "Index" then ".[\(.index)]"
            elif .type == "Key" then 
                .optional as $optional |
                if .name then
                    ".\(.name)"
                elif .query then
                    ".[\(.query)]"
                else
                    error("Unsupported type of Key: \(.)")
                end |
                if $optional then "\(.)?" end
            elif .type == "Slice" then ".[\(.start // ""):\(.end // "")]"
            elif .type == "Func" then "\(.name)\(
                if .args then
                    .args | join(";\(sep)") | "(\(.))"
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
                "reduce \(.query) as \(.pattern) (\(.start);\(.update))"
            elif .type == "Foreach" then
                "foreach \({term: .term}) as \(.pattern) (\(.start);\(.update)\(
                    if .extract then ";\(.extract)" else "" end
                ))"
            elif .type == "Try" then
                "try \(.body)\(if .catch then " catch \(.catch)" else "" end)" 
            elif .type == "Label" then
                "label \(.ident) | \(.body)" 
            elif .type == "Break" then
                "break \(.break)" 
            elif .type == "Bind" then
                "\(.value) as \(.patterns | join(", ")) | \(.scope)" 
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
#    t::traverse_expr(debug("expr: \(.)"); debug("pattern: \(.)"); debug("import: \(.)"); debug("func_def: \(.)"));

def algebra_tostring:
    algebra_tostring(null);
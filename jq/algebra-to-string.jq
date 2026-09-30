import "traverse" as t {search: "./"};

# String serialization of a jq algebra expression
# - `$space`, optional parameter to pretty print the output jq query:
#    - if omitted or `null`, the function does not attempt to pretty print the output;
#    - if it is a string, it is used as "tab unit" for indentation;
#    - if it is a number, the tab unit is composed by that number of spaces.

def algebra_tostring($space):

    # Operators priority, from the lowest
    # (https://github.com/jqlang/jq/wiki/jq-Language-Description#operators-priority)
    #
    # def … ; …                  Function expression
    # … as $variable | …         Variable definition expression
    # label $variable | …        Labels
    # |                          Pipe (right-associative)
    # ,                          Comma (left-associative)
    # //                         Alternative (right-associative)
    # =, |=, +=, -=, *=, /=, %=, //=
    #                            Update-assignment (non-associative)
    # or                         Boolean OR (left-associative)
    # and                        Boolean AND (left-associative)
    # ==, !=, <, >, <=, >=       Comparisons (non-associative)
    # +, -                       Addition, Subtraction (left-associative)
    # *, /, %                    Multiplication, Division, Modulo (left-associative)
    # -x                         Negative
    # try … catch …, if … end, reduce …, foreach …
    #                            (closed, but not accepted everywhere a term is)
    # x?, .a, f, [...], {...}    Terms (postfix)
    #
    # While serializing, every expression becomes an object `{str, prec}` with
    # its text and its priority, so that the enclosing expression can add
    # parentheses where needed.

    [
        ["|"],
        [","],
        ["//"],
        ["=", "|=", "+=", "-=", "*=", "/=", "%=", "//="],
        ["or"],
        ["and"],
        ["==", "!=", "<", ">", "<=", ">="],
        ["+", "-"],
        ["*", "/", "%"]
    ] as $op_lists_by_prec |

    (
        [
            $op_lists_by_prec | to_entries[] |
            .key as $index |
            .value[] |
            {key: ., value: ($index + 1)}
        ] |
        from_entries
    ) as $op_prec |

    # right-open expressions (definitions, bindings, labels)
    0 as $bind_prec |
    10 as $unary_prec |
    11 as $closed_prec |
    12 as $term_prec |

    ["=", "|=", "+=", "-=", "*=", "/=", "%=", "//=", "==", "!=", "<", ">", "<=", ">="] as $nonassoc_ops |

    [
        "__loc__", "and", "as", "catch", "def", "elif", "else", "end", "foreach",
        "if", "import", "include", "label", "module", "or", "reduce", "then", "try"
    ] as $keywords |

    ($space | (numbers | . * " ") // .) as $indent_str |

    def sep:
        if $indent_str then " " else "" end;

    def indent:
        if $indent_str then
            [splits("\n") | if . == "" then . else $indent_str + . end] | join("\n")
        end;

    # `$items` enclosed by `$open` and `$close`, one per line if pretty printing
    def block($open; $close):
        if length == 0 then
            "\($open)\($close)"
        elif $indent_str then
            "\($open)\n\(join(",\n") | indent)\n\($close)"
        else
            "\($open)\(join(","))\($close)"
        end;

    def is_identifier:
        test("^[a-zA-Z_][a-zA-Z_0-9]*$") and (. as $name | $keywords | index($name) | not);

    # text of a serialized expression, in a context requiring at least priority `$min`
    def paren($min):
        if .prec < $min then "(\(.str))" else .str end;

    def full: paren($bind_prec);
    def term: paren($term_prec);

    def serialize_json:
        if type == "object" then
            [
                to_entries[] |
                "\(.key | if is_identifier then . else tojson end):\(sep)\(.value | serialize_json)"
            ] | block("{"; "}")
        elif type == "array" then
            "[\([.[] | serialize_json] | join(",\(sep)"))]"
        else
            tojson
        end;

    def serialize_keyvals:
        [
            .[] |
            "\(
                if .key then .key
                elif .key_string then .key_string.str
                else "(\(.key_query | full))"
                end
            )\(
                if .val then ":\(sep)\(.val | term)" else "" end
            )"
        ] | block("{"; "}");

    # branch of an `if`
    def branch:
        if $indent_str then "\n\(indent)\n" else " \(.) " end;

    # end of a module directive or a function definition
    def directive_end:
        if $indent_str then ";\n\n" else "; " end;

    def serialize_core:
        if .type == "Literal" then
            .value | tojson |
            {str: ., prec: (if startswith("-") then $unary_prec else $term_prec end)}
        elif .type == "FixedString" then
            {str: (.value | tojson | .[1:-1])}
        elif .type == "InterpolatedString" then
            {str: "\\(\(.query | full))"}
        elif .type == "StringInterpolation" then
            {str: "\"\([.fragments[].str] | join(""))\""}
        elif .type == "Format" then
            {str: "\(.format)\(if .str then " \(.str.str)" else "" end)"}
        elif .type == "Identity" then {str: "."}
        elif .type == "Recurse" then {str: ".."}
        elif .type == "Iterator" then {str: ".[]"}
        elif .type == "Key" then
            if .name then
                {str: ".\(.name | if is_identifier then . else tojson end)"}
            elif .query then
                if .query.str | startswith("\"") then
                    {str: ".\(.query.str)"}
                else
                    {str: ".[\(.query | full)]"}
                end
            else
                error("Unsupported type of Key: \(.)")
            end
        elif .type == "Index" then {str: ".[\(.index | full)]"}
        elif .type == "Slice" then
            {str: ".[\(.start // null | if . then full else "" end):\(.end // null | if . then full else "" end)]"}
        elif .type == "Func" then
            {str: "\(.name)\(
                if .args then
                    [.args[] | full] | join(";\(sep)") | "(\(.))"
                else
                    ""
                end
            )"}
        elif .type == "Object" then {str: (.key_vals | serialize_keyvals)}
        elif .type == "Array" then {str: "[\(if .query then .query | full else "" end)]"}
        elif .type == "UnaryOp" then
            {str: "\(.op)\(.operand | term)", prec: $unary_prec}
        elif .type == "BinaryOp" then
            .op as $op |
            $op_prec[$op] as $prec |
            (if $nonassoc_ops | index([$op]) then $prec + 1 else $prec end) as $left_prec |
            {
                str: "\(.leftOperand | paren($left_prec))\(
                    if .op == "and" or .op == "or" then " \(.op) " else "\(sep)\(.op)\(sep)" end
                )\(.rightOperand | paren($prec + 1))",
                prec: $prec
            }
        elif .type == "NaryOp" then
            .op as $op |
            $op_prec[$op] as $prec |
            (.operands | length - 1) as $last |
            {
                str: (
                    [
                        .operands | to_entries[] |
                        if $op == "|" and .key == $last then
                            # a binding (or a label) can end a pipe: its scope extends to the right
                            .value | full
                        else
                            .value | paren($prec + 1)
                        end
                    ] |
                    join(if $op == "," then ",\(sep)" else "\(sep)\($op)\(sep)" end)
                ),
                prec: $prec
            }
        elif .type == "If" then
            {
                str: "if \(.cond | full) then\(.then | full | branch)\(
                    [.elif[]? | "elif \(.cond | full) then\(.then | full | branch)"] | join("")
                )\(
                    if .else then "else\(.else | full | branch)" else "" end
                )end",
                prec: $closed_prec
            }
        elif .type == "Reduce" then
            {
                str: "reduce \(.query | term) as \(.pattern) (\(.start | full);\(sep)\(.update | full))",
                prec: $closed_prec
            }
        elif .type == "Foreach" then
            {
                str: "foreach \(.query | term) as \(.pattern) (\(.start | full);\(sep)\(.update | full)\(
                    if .extract then ";\(sep)\(.extract | full)" else "" end
                ))",
                prec: $closed_prec
            }
        elif .type == "Try" then
            {
                str: "try \(.body | term)\(if .catch then " catch \(.catch | term)" else "" end)",
                prec: $closed_prec
            }
        elif .type == "Label" then
            {str: "label \(.ident) | \(.body | full)", prec: $bind_prec}
        elif .type == "Break" then
            {str: "break \(.break)"}
        elif .type == "Bind" then
            {
                str: "\(.value | term) as \(.patterns | join(" ?// ")) | \(.scope | full)",
                prec: $bind_prec
            }
        elif .type == null then
            # module with no main expression
            {str: "", prec: $bind_prec}
        else error("unsupported expression: \(.)")
        end |
        .prec //= $term_prec;

    def serialize_expr:
        (if .meta then
            "module \(.meta | serialize_json)\(directive_end)"
        else
            ""
        end) as $module_decl |
        (.optional == true) as $optional |
        [($module_decl | select(. != "")), .imports[]?, .func_defs[]?] as $header |
        serialize_core |
        if $optional then {str: "\(term)?", prec: $term_prec} end |
        if $header != [] then
            {
                str: (
                    "\($header | join(""))\(.str)" |
                    # no trailing space for a module with no main expression
                    sub("\\s+$"; "")
                ),
                prec: $bind_prec
            }
        end;

    def serialize_pattern:
        if .name then .name
        elif .array then "[\(.array | join(",\(sep)"))]"
        elif .object then
            "{\(
                [
                    .object[] |
                    "\(
                        if .key then .key
                        elif .key_string then .key_string.str
                        else "(\(.key_query | full))"
                        end
                    )\(
                        if .val then ":\(sep)\(.val)" else "" end
                    )"
                ] |
                join(",\(sep)")
            )}"
        else error("unsupported type of pattern: \(.)")
        end;

    def serialize_import:
        "\(
            if .import_path then
                "import \(.import_path | tojson) as \(.import_alias)"
            elif .include_path then
                "include \(.include_path | tojson)"
            else error("unsupported import type: \(.)")
            end
        )\(
            if .meta then " \(.meta | serialize_json)"
            else ""
            end
        )\(directive_end)";

    def serialize_func_def:
        "def \(.name)\(
            if .args then "(\(.args | join(";\(sep)")))"
            else ""
            end
        ):\(
            .body | full |
            if $indent_str then "\n\(indent)" else " \(.)" end
        )\(
            directive_end
        )";

    t::traverse_expr(serialize_expr; serialize_pattern; serialize_import; serialize_func_def) |
    .str;

def algebra_tostring:
    algebra_tostring(null);

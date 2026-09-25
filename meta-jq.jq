# Entry point of the meta-jq module: `import "meta-jq" as meta;`
#
# Internal modules are imported with `{search: "./"}`, which makes them
# resolve relative to this file in jq, gojq and fq, wherever the package
# has been installed (plain copy, jqpm, yarn, ...).
# Definitions are re-exported explicitly, as standard jq does not re-export
# definitions brought in by `include`.

# fq fails to resolve a module imported by several files unless the outermost
# import comes first and uses the same alias: keep "jq/traverse" first, as `t`,
# as in jq/algebra-to-string.jq.
import "jq/traverse" as t {search: "./"};
import "jq/ast-to-algebra" as a2a {search: "./"};
import "jq/algebra-to-string" as a2s {search: "./"};

def ast_to_algebra: a2a::ast_to_algebra;

def algebra_tostring($space): a2s::algebra_tostring($space);
def algebra_tostring: a2s::algebra_tostring;

def traverse_expr(visit_expr; visit_pattern; visit_import; visit_func_def):
    t::traverse_expr(visit_expr; visit_pattern; visit_import; visit_func_def);

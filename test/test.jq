import "../jq/main" as meta;

def test_serialize:
    meta::algebra_tostring(4);
#.;

def traverse_id:
    # meta::traverse_ast(map_block; map_pattern; map_index; map_suffix; map_func_def)
    #meta::traverse_ast(.; .; .; .; .);
    .;

#def module_info:
#    "../jq/traverse" | modulemeta;

def test_to_algebra:
    meta::ast_to_algebra;

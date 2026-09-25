# meta-jq
Tools for processing [jq](https://jqlang.org/) queries using jq itself (via a JSON representation of jq queries).

## Why

### jq

[jq](https://jqlang.org/) is a declarative language to transform JSON.
It is described by its authors as being "like sed for JSON data".
It can also be seen as being to JSON what languages like XQuery and XSLT are to XML.

### jq Queries as JSON

Declarative languages like jq are not tied to specific implementations and execution contexts.
It thus possible to manipulate the structure of scripts (which in the case of jq are called queries) for a number of reasons: perform pre-execution optimizations, adapt to different contexts, port to different languages, conform to specific rules, ...

If we are able to represent jq queries as JSON, jq queries can be used to manipulate other jq queries, avoiding dependencies from other tool/languages.
There is currently no established convention on how to represent jq queries as JSON. But the jq implementation [gojq](https://github.com/itchyny/gojq) offers a JSON based representation of the abstract syntax tree (AST) that can be considered as starting point. [jqjq](https://github.com/wader/jqjq) is a jq implementation based on jq itself that outputs the same AST representation (with a few exceptions). 

This representation has some quirks that complicate direct manipulation.
We propose a represention that we call __jq algebra__ and it is meant to expose jq structure with a more direct mapping of semantics.

## Install

meta-jq is a jq module with a single entry point, `meta-jq.jq`, and works with standard [jq](https://jqlang.org/) (1.7+), [gojq](https://github.com/itchyny/gojq) and [fq](https://github.com/wader/fq).
Whatever the installation mode, it is imported with `import "<name>" as meta;`, passing the folder where it has been installed to jq with `-L`.

Note: fq does not look for `<name>/<name>.jq` when importing `<name>`, so with fq the entry file must be named explicitly, e.g. `import "meta-jq/meta-jq" as meta;` instead of `import "meta-jq" as meta;`.

### From textual jq to AST: fq

A jq query can be parsed and transformed to JSON AST with jqjq or tools based on gojq.
I suggest installing fq, as described [here](https://github.com/wader/fq#install).

### Simple setup

Clone/download this repo into a folder named `meta-jq`, inside some folder on the jq search path (e.g., `lib` in your project, or `~/.jq`):

```shell
git clone https://github.com/miguel76/meta-jq.git lib/meta-jq
jq -L lib 'import "meta-jq" as meta; meta::ast_to_algebra' <path/to/ast.json
```

### jqpm

Install with [jqpm](https://pypi.org/project/jqpm/) inside your jq project:

```shell
jqpm init   # if the project has no jqpackage.json yet
jqpm add miguel76/meta-jq
```

The module is installed under `jq_modules/miguel76/meta-jq` and can be used as follows:

```shell
jq -L jq_modules 'import "miguel76/meta-jq" as meta; meta::ast_to_algebra' <path/to/ast.json
# or, with jq_modules already on the search path (jq options go after `--`)
jqpm run -- -r 'import "miguel76/meta-jq" as meta; meta::ast_to_algebra | meta::algebra_tostring' <path/to/ast.json
```

### yarn (experimental)

Install with yarn inside your (nodejs or pure jq) project:

```shell
yarn add miguel76/meta-jq --modules-folder lib
jq -L lib 'import "meta-jq" as meta; meta::ast_to_algebra' <path/to/ast.json
```

Note: if you have just jq dependencies you can add a line with `--modules-folder lib` to a file named `.yarnrc` in your project's root.

### pip (experimental)

Install with pip (e.g., inside the virtual environment of your Python project):

```shell
pip install git+https://github.com/miguel76/meta-jq.git
```

The module is installed under `<prefix>/lib/jq/meta-jq`, where `<prefix>` is the Python environment's prefix (e.g., `.venv`, as given by `python -c 'import sys; print(sys.prefix)'`):

```shell
jq -L .venv/lib/jq 'import "meta-jq" as meta; meta::ast_to_algebra' <path/to/ast.json
```

### Testing

`test/test.sh` checks the basic functionality with the jq engines found on the `PATH` (jq, gojq, fq), or with the ones given as arguments.
It tests the repo itself; set `META_JQ_LIB` (the folder to pass to `-L`) and `META_JQ_MODULE` (the name to import) to test an installed copy:

```shell
test/test.sh
META_JQ_LIB=jq_modules META_JQ_MODULE=miguel76/meta-jq path/to/meta-jq/test/test.sh jq gojq fq
```

## Usage

### Standard jq 

Convert with an external tool (fq or jqjq) from textual jq to AST JSON:

```shell
fq --raw-input --slurp '_query_fromstring' <path/to/query/file.jq >path/to/output.json
```

Manipulate query and serialize it back as text:

```jq
import "meta-jq" as meta;

# AST => algebra
meta::ast_to_algebra |

# manipulate query (with visitor filters)
meta::traverse_expr(visit_expr; visit_pattern; visit_import; visit_func_def) |

# algebra => textual jq
meta::algebra_tostring
```

### With fq or jqjq

Everything in jq, as `_query_fromstring` is available (note the fq import name):

```jq
import "meta-jq/meta-jq" as meta;

# textual jq => AST
_query_fromstring | 

# AST => algebra
meta::ast_to_algebra |

# manipulate query (with visitor filters)
meta::traverse_expr(visit_expr; visit_pattern; visit_import; visit_func_def) |

# algebra => textual jq
meta::algebra_tostring
```

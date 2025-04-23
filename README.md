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

## Install

### Parser for jq: fq

A jq query can be parsed and transformed to JSON with jqjq or tools based on gojq.
I suggest installing fq, as described [here](https://github.com/wader/fq#install).

### Manipulation and Serialization

This repository offers tools for manipulating and serializing the JSON obtained by parsing jq queries.

#### Simple setup

Clone/download ths repo and copy/paste the files under the jq directory in some place where the jq engine can find them: e.g., relative path `../lib/meta-jq/` or `../lib/jq/meta-jq/`.

#### yarn (experimental)

Install with yarn inside your (nodejs or pure jq) project:

```shell
yarn add miguel76/meta-jq --modules-folder lib
```

Note: if you have just jq dependencies you can add a line with `--modules-folder lib` to a file named `.yarnrc` in your project's root.

#### pip (more experimental...)

Install with pip inside your Python project:

```shell
pip install git+https://github.com/miguel76/meta-jq.git
```

## Usage

### jq to JSON

Call the parser:

```shell
fq --raw-input --slurp '_query_fromstring' <paht/to/query/file.jq >path/to/output.json
```

## Manipulating jq as JSON

```jq
import "meta-jq" as meta;

...

meta::traverse_ast(visit_expr; visit_pattern; visit_index; visit_suffix; visit_func_def);
```

Where `visit_expr`, `visit_pattern`, `visit_index`, `visit_suffix`, and `visit_func_def` are functions that perform some operation on the corresponding nodes of the AST.

## JSON to jq

```jq
import "meta-jq" as meta;

...

meta::ast_tostring($space)
```

Where `$space` is an optional parameter to pretty print the output jq query:
- if omitted or `null`, the function does not attempt to pretty print the output;
- if it is a string, it is used as "tab unit" for indentation;
- if it is a number, the tab unit is composed by that number of spaces.
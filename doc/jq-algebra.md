# jq algebra

The *jq algebra* is the JSON representation of jq queries used by meta-jq.
`meta::ast_to_algebra` builds it from the AST produced by gojq/fq/jqjq, `meta::traverse_expr` walks and rewrites it, and `meta::algebra_tostring` turns it back into jq text.

Compared to the AST, the algebra:

- drops the `term`/`TermType...` wrapping: every expression is an object with a `type`;
- turns suffixes (`.a.b[0]`, `.[]`, `?`, `as $x | ...`) into ordinary expressions;
- represents the associative operators `|`, `,` and `//` as a single operator with a flat list of operands;
- decodes constants (`null`, numbers, booleans, strings, module metadata) into plain JSON values.

The formal definition is the JSON Schema [`schema/jq-algebra.schema.json`](../schema/jq-algebra.schema.json) (draft 2020-12).
This page describes the same thing with examples.

## General structure

A jq query is represented by an **expression**: a JSON object whose `type` says what kind of expression it is.
Sub-expressions are nested expressions.

```jq
.a | length
```

```json
{
  "type": "NaryOp",
  "op": "|",
  "operands": [
    {"type": "Key", "name": "a"},
    {"type": "Func", "name": "length"}
  ]
}
```

Besides the properties of its type, every expression may have:

| Property    | Value                         | Meaning |
|-------------|-------------------------------|---------|
| `optional`  | `true`                        | the expression is followed by `?` (error suppression), e.g. `.a?`, `.[]?`, `f?` |
| `func_defs` | array of [function definitions](#function-definitions) | `def`s preceding the expression, visible in it |
| `meta`      | object                        | module metadata (`module {...};`), root expression only |
| `imports`   | array of [module directives](#module-directives) | `import`s and `include`s, root expression only |

Naming conventions shared by all types:

- variables, labels and value parameters keep their leading `$` (`"$x"`);
- a variable reference is a function call whose name starts with `$` (see [`Func`](#function-calls-and-variables)).

## Expression types

### Paths and constants

| jq | algebra |
|----|---------|
| `.` | `{"type": "Identity"}` |
| `..` | `{"type": "Recurse"}` |
| `.[]` | `{"type": "Iterator"}` |
| `.[]?` | `{"type": "Iterator", "optional": true}` |
| `.a`, `."a"` | `{"type": "Key", "name": "a"}` |
| `."a b"` | `{"type": "Key", "name": "a b"}` |
| `.a?` | `{"type": "Key", "name": "a", "optional": true}` |
| `."a\(.b)"` | `{"type": "Key", "query": {"type": "StringInterpolation", ...}}` |
| `.[q]` | `{"type": "Index", "index": q}` |
| `.[s:e]`, `.[s:]`, `.[:e]` | `{"type": "Slice", "start": s, "end": e}` (either bound may be missing) |
| `null`, `42`, `true`, `false`, `"abc"` | `{"type": "Literal", "value": 42}` (`value` is `null`, a number, a boolean or a string) |

A path such as `.a.b[0]` is a pipe of its components:

```json
{
  "type": "NaryOp",
  "op": "|",
  "operands": [
    {"type": "Key", "name": "a"},
    {"type": "Key", "name": "b"},
    {"type": "Index", "index": {"type": "Literal", "value": 0}}
  ]
}
```

`Key` has either a `name` (any string: `.a` and `."a"` are the same) or a `query`, an expression computing the key (the interpolated string of `."a\(.b)"`).

### Strings and formats

A string without interpolation is a `Literal`.
A string with interpolations is a `StringInterpolation`, made of `fragments` that are either `FixedString` (constant text) or `InterpolatedString` (a `\(...)`):

```jq
"Hello \(.name)!"
```

```json
{
  "type": "StringInterpolation",
  "fragments": [
    {"type": "FixedString", "value": "Hello "},
    {"type": "InterpolatedString", "query": {"type": "Key", "name": "name"}},
    {"type": "FixedString", "value": "!"}
  ]
}
```

A format (`@base64`, `@uri`, ...) is a `Format`, with the format name (including `@`) in `format`.
When the format is applied to a string, `str` holds that string (a `Literal` or a `StringInterpolation`):

| jq | algebra |
|----|---------|
| `@base64` | `{"type": "Format", "format": "@base64"}` |
| `@uri "x=\(.x)"` | `{"type": "Format", "format": "@uri", "str": {"type": "StringInterpolation", ...}}` |

### Function calls and variables

`Func` is a call of a function, with its `name` and, if any, its `args` (one expression per `;`-separated argument).
Variables are represented in the same way, with a name starting with `$`.

| jq | algebra |
|----|---------|
| `length` | `{"type": "Func", "name": "length"}` |
| `empty` | `{"type": "Func", "name": "empty"}` |
| `f(.; 1)` | `{"type": "Func", "name": "f", "args": [{"type": "Identity"}, {"type": "Literal", "value": 1}]}` |
| `$x`, `$ENV`, `$__loc__` | `{"type": "Func", "name": "$x"}` |

### Object and array construction

`Array` has an optional `query`, absent for `[]`:

| jq | algebra |
|----|---------|
| `[]` | `{"type": "Array"}` |
| `[.[] \| .id]` | `{"type": "Array", "query": {"type": "NaryOp", "op": "\|", ...}}` |

`Object` has a list of `key_vals`.
Each entry has one key property and, unless it is a shorthand, a `val` expression:

| jq entry | entry |
|----------|-------|
| `a: v`, `if: v` | `{"key": "a", "val": v}` |
| `a` (shorthand for `a: .a`) | `{"key": "a"}` |
| `$x` (shorthand for `x: $x`) | `{"key": "$x"}` |
| `$x: v` | `{"key": "$x", "val": v}` |
| `"a": v` | `{"key_string": {"type": "Literal", "value": "a"}, "val": v}` |
| `"a"` (shorthand) | `{"key_string": {"type": "Literal", "value": "a"}}` |
| `"a\(.b)": v` | `{"key_string": {"type": "StringInterpolation", ...}, "val": v}` |
| `(q): v` | `{"key_query": q, "val": v}` |

`key_string` is a string expression: a `Literal` with a string value or a `StringInterpolation`.

### Operators

Unary minus is a `UnaryOp`:

```json
{"type": "UnaryOp", "op": "-", "operand": {"type": "Key", "name": "a"}}
```

The pipe `|`, the comma `,` and the alternative `//` are associative and are represented by an `NaryOp` with a flat list of `operands`: `a | b | c` is one `NaryOp` with three operands, whatever the parenthesization of the original query.
In addition, the identity elements of these operators are dropped (`.` from `|`, `empty` from `,` and `//`), so that:

- an `NaryOp` has at least two operands;
- `. | .a` becomes just `{"type": "Key", "name": "a"}`, and `(empty, 1)` just `{"type": "Literal", "value": 1}`.

All other binary operators are a `BinaryOp`, with `leftOperand` and `rightOperand`:

- arithmetic: `*`, `/`, `%`, `+`, `-`
- comparison: `==`, `!=`, `<`, `>`, `<=`, `>=`
- boolean: `and`, `or`
- update-assignment: `=`, `|=`, `+=`, `-=`, `*=`, `/=`, `%=`, `//=`

```jq
.a |= . + 1
```

```json
{
  "type": "BinaryOp",
  "op": "|=",
  "leftOperand": {"type": "Key", "name": "a"},
  "rightOperand": {
    "type": "BinaryOp",
    "op": "+",
    "leftOperand": {"type": "Identity"},
    "rightOperand": {"type": "Literal", "value": 1}
  }
}
```

The algebra has no node for parentheses: the tree structure makes them unnecessary.

### Control flow

| jq | algebra |
|----|---------|
| `if c then t end` | `{"type": "If", "cond": c, "then": t}` |
| `if c1 then t1 elif c2 then t2 else e end` | `{"type": "If", "cond": c1, "then": t1, "elif": [{"cond": c2, "then": t2}], "else": e}` |
| `try b` | `{"type": "Try", "body": b}` |
| `try b catch c` | `{"type": "Try", "body": b, "catch": c}` |
| `label $out \| b` | `{"type": "Label", "ident": "$out", "body": b}` |
| `break $out` | `{"type": "Break", "break": "$out"}` |
| `reduce q as p (s; u)` | `{"type": "Reduce", "query": q, "pattern": p, "start": s, "update": u}` |
| `foreach q as p (s; u)` | `{"type": "Foreach", "query": q, "pattern": p, "start": s, "update": u}` |
| `foreach q as p (s; u; x)` | `{"type": "Foreach", "query": q, "pattern": p, "start": s, "update": u, "extract": x}` |

The postfix `?` is not a `Try`: it is the `optional` flag of the expression it follows.

### Variable binding

`value as pattern | scope` is a `Bind`.
`patterns` is a list, as a binding may have [destructuring alternatives](https://jqlang.org/manual/#destructuring-alternative-operator) (`value as p1 ?// p2 | scope`).

```jq
.[] as [$a, $b] | $a + $b
```

```json
{
  "type": "Bind",
  "value": {"type": "Iterator"},
  "patterns": [{"array": [{"name": "$a"}, {"name": "$b"}]}],
  "scope": {
    "type": "BinaryOp",
    "op": "+",
    "leftOperand": {"type": "Func", "name": "$a"},
    "rightOperand": {"type": "Func", "name": "$b"}
  }
}
```

The scope extends as far right as possible: in `1 as $x | 2 as $y | $x + $y` the second `Bind` is the scope of the first one.

## Patterns

Patterns are used by `Bind`, `Reduce` and `Foreach`.
They are not expressions (they have no `type`) and have exactly one of these properties:

| jq | pattern |
|----|---------|
| `$x` | `{"name": "$x"}` |
| `[p1, p2]` | `{"array": [p1, p2]}` |
| `{...}` | `{"object": [entries]}` |

Entries of object patterns:

| jq entry | entry |
|----------|-------|
| `$x` (binds the value of key `x`) | `{"key": "$x"}` |
| `$x: p` (binds `$x` and destructures it with `p`) | `{"key": "$x", "val": p}` |
| `a: p` | `{"key": "a", "val": p}` |
| `"a": p` | `{"key_string": {"type": "Literal", "value": "a"}, "val": p}` |
| `"a\(.b)": p` | `{"key_string": {"type": "StringInterpolation", ...}, "val": p}` |
| `(q): p` | `{"key_query": q, "val": p}` |

As in object construction, `key_string` is a `Literal` string or a `StringInterpolation`, and `key_query` is an expression.

## Function definitions

Function definitions are attached, as `func_defs`, to the expression that follows them (their scope):

```jq
def inc($n): . + $n; def twice(f): f | f;
twice(inc(1))
```

```json
{
  "type": "Func",
  "name": "twice",
  "args": [{"type": "Func", "name": "inc", "args": [{"type": "Literal", "value": 1}]}],
  "func_defs": [
    {
      "name": "inc",
      "args": ["$n"],
      "body": {"type": "BinaryOp", "op": "+", "leftOperand": {"type": "Identity"}, "rightOperand": {"type": "Func", "name": "$n"}}
    },
    {
      "name": "twice",
      "args": ["f"],
      "body": {"type": "NaryOp", "op": "|", "operands": [{"type": "Func", "name": "f"}, {"type": "Func", "name": "f"}]}
    }
  ]
}
```

A function definition has a `name`, a `body` expression and, if it has parameters, `args`: the list of parameter names, with a leading `$` for value parameters.

A library module, made only of definitions, has no main expression: its root is an object with `func_defs` (and possibly [`meta` and `imports`](#module-directives)) but no `type`.

```jq
def inc: . + 1;
```

```json
{
  "func_defs": [
    {"name": "inc", "body": {"type": "BinaryOp", "op": "+", "leftOperand": {"type": "Identity"}, "rightOperand": {"type": "Literal", "value": 1}}}
  ]
}
```

## Module directives

The module header is attached to the root expression: `meta` for `module {...};` and `imports` for the `import` and `include` directives, in order.
Metadata is decoded into a plain JSON object.

```jq
module {name: "example"};
import "lib" as lib;
import "data" as $data {search: "./"};
include "helpers";
.
```

```json
{
  "type": "Identity",
  "meta": {"name": "example"},
  "imports": [
    {"import_path": "lib", "import_alias": "lib"},
    {"import_path": "data", "import_alias": "$data", "meta": {"search": "./"}},
    {"include_path": "helpers"}
  ]
}
```

## Serialization

`meta::algebra_tostring` prints an algebra document back as jq text, which parses back to the same algebra.
As the algebra has no parentheses, it adds them according to the operator priorities, only where they are needed (`(1 + 2) * 3`, `(.a | length) as $n | ...`), and around object values that are not simple terms (`{a: (1 + 2)}`), which jq requires.

## Known limitations

The algebra is a normalized form of the query, so some details of the source text are not kept:

- formatting, comments and redundant parentheses;
- equivalent forms of the same expression: `.a` and `."a"`, `.a.b` and `.a | .b`, `. | f` and `f`, nested definition scopes (`def f: 1; (def g: 2; g)` is `def f: 1; def g: 2; g`);
- repeated error suppression: `.a??` is the same as `.a?`;
- the key order of metadata objects may change, depending on the jq implementation used for the conversion (gojq and fq sort the keys).

## Validating

Any JSON Schema (draft 2020-12) validator can check a document against the schema, for example with Python's `jsonschema`:

```shell
fq --raw-input --slurp '_query_fromstring' <query.jq |
    jq -L lib 'import "meta-jq" as meta; meta::ast_to_algebra' >query.algebra.json
python3 -c 'import json, sys, jsonschema; jsonschema.validate(json.load(open(sys.argv[1])), json.load(open(sys.argv[2])))' \
    query.algebra.json lib/meta-jq/schema/jq-algebra.schema.json
```

`test/test-schema.sh` validates the test data this way.

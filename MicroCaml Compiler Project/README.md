## Updates
- 11/02 - Corrected typos in introduction example AST and tokenize example
- 11/03 - Added clarification on example mutop directives
- 11/09 - Corrected typo in tokenize example

# Project 4a: MicroCaml Lexer and Parser
Due: November 16th, 2021, 11:59PM (Late: November 17th, 2021, 11:59PM)

Points: 48 public, 52 semipublic

## Introduction

Over the course of Projects 4a and 4b, you will implement MicroCaml — a *dynamically-typed* version of OCaml with a subset of its features. Because MicroCaml is dynamically typed, it is not type checked at compile time; like Ruby, type checking will take place when the program runs. As part of your implementation of MicroCaml, you will also implement parts of `mutop` (μtop or Microtop), a version of `utop` for MicroCaml.

In Project 4a, you will implement a lexer and parser for MicroCaml. Your lexer function will convert an input string of MicroCaml into a list of tokens, and your parser function will consume these tokens to produce an abstract symbol tree (AST), either for a MicroCaml expression, or for a `mutop` directive. In Project 4b, you will implement an interpreter to actually execute the produced AST.

Here is an example call to the lexer and parser on a MicroCaml `mutop` directive (as a string):

```ocaml
parse_mutop (tokenize "def b = let x = true in x;;")
```

This will return the AST as the following OCaml value (which we will explain in due course):

```ocaml
 Def ("b", Let ("x", false, Value (Bool true), ID "x"))
```

### Ground Rules

In your code, you may use any OCaml modules and features we have taught in this class **except imperative OCaml** features like references, mutable records, and arrays. This means that you'll have to adjust the approach of the `match_tok` etc. functions given in lecture; these functions will take and return a token list, rather than modify a global list in place; we provide helper functions in the project to do this. Also, we have changed the definition of `lookahead` from the one given in lecture; the version presented here returns an `option` type, which is critical for your parser to work properly.

### Testing & Submitting

You can submit through `gradescope-submit` from the project directory and the project will be automatically submitted.

You can also manually submit to [Gradescope](https://www.gradescope.com/courses/298347/assignments/1627770/).  You may only submit the **lexer.ml** and **parser.ml** files.  To test locally, run `dune runtest -f`.

All tests will be run on direct calls to your code, comparing your return values to the expected return values. Any other output (e.g., for your own debugging) will be ignored. You are free and encouraged to have additional output. The only requirement for error handling is that input that cannot be lexed/parsed according to the provided rules should raise an `InvalidInputException`. We recommend using relevant error messages when raising these exceptions, to make debugging easier. We are not requiring intelligent messages that pinpoint an error to help a programmer debug, but as you do this project you might find you see where you could add those.

You can run your lexer or parser directly on a MicroCaml program by running `dune exec bin/interface.bc lex [filename]` or `dune exec bin/interface.bc parse [filename]` where the `[filename]` argument is required.

To test from the toplevel, run `dune utop src`. The necessary functions and types will automatically be imported for you.

You can write your own tests which only test the parser by feeding it a custom token list. For example, to see how the expression `let x = true in x` would be parsed, you can construct the token list manually (e.g. in `utop`):

```ocaml
parse_expr [Tok_Let; Tok_ID "x"; Tok_Equal; Tok_Bool true; Tok_In; Tok_ID "x"];;
```

This way, you can work on the parser even if your lexer is not complete yet.

## Part 1: The Lexer (aka Scanner or Tokenizer)

Your parser will take as input a list of tokens; this list is produced by the *lexer* (also called a *scanner*) as a result of processing the input string. Lexing is readily implemented by use of regular expressions, as demonstrated in **[lecture][lecture] slides 3-5**. Information about OCaml's regular expressions library can be found in the [`Str` module documentation][str doc]. You aren't required to use it, but you may find it helpful.

Your lexer must be written in [lexer.ml](./src/lexer.ml). You will need to implement the following function: 

#### `tokenize`

- **Type:** `string -> token list` 
- **Description:** Converts MicroCaml syntax (given as a string) to a corresponding token list.
- **Examples:**
  ```ocaml
  tokenize "1 + 2" = [Tok_Int 1; Tok_Add; Tok_Int 2]

  tokenize "1 (-1)" = [Tok_Int 1; Tok_Int (-1)]

  tokenize ";;" = [Tok_DoubleSemi]

  tokenize "+ - let def" = [Tok_Add; Tok_Sub; Tok_Let; Tok_Def]

  tokenize "let rec ex = fun x -> x || true;;" = 
    [Tok_Let; Tok_Rec; Tok_ID "ex"; Tok_Equal; Tok_Fun; Tok_ID "x"; Tok_Arrow; Tok_ID "x"; Tok_Or; Tok_Bool true; Tok_DoubleSemi]
  ```

The `token` type is defined in [tokenTypes.ml](./src/tokenTypes.ml).

Notes:
- The lexer input is case sensitive.
- Tokens can be separated by arbitrary amounts of whitespace, which your lexer should discard. Spaces, tabs ('\t') and newlines ('\n') are all considered whitespace.
- When excaping characters with `\` within Ocaml strings/regexp you must use `\\` to escape from the string and regexp.
- If the beginning of a string could match multiple tokens, the **longest** match should be preferred, for example:
  - "let0" should not be lexed as `Tok_Let` followed by `Tok_Int 0`, but as `Tok_ID("let0")`, since it is an identifier.
  - "330dlet" should be tokenized as `[Tok_Int 330; Tok_ID "dlet"]`. Arbitrary amounts of whitespace also includes no whitespace.
  - "(-1)" should not be lexed as `[Tok_LParen; Tok_Sub; Tok_Int(1); Tok_LParen]` but as `Tok_Int(-1)`. (This is further explained below)
- There is no "end" token (like `Tok_END` the [lecture][lecture] slides 3-5)  -- when you reach the end of the input, you are done lexing.

Most tokens only exist in one form (for example, the only way for `Tok_Concat` to appear in the program is as `^` and the only way for `Tok_Let` to appear in the program is as `let`). However, a few tokens have more complex rules. The regular expressions for these more complex rules are provided here:

- `Tok_Bool of bool`: The value will be set to `true` on the input string "true" and `false` on the input string "false".
  - *Regular Expression*: `true|false`
- `Tok_Int of int`: Valid ints may be positive or negative and consist of 1 or more digits. **Negative integers must be surrounded by parentheses** (without extra whitespace) to differentiate from subtraction (examples below). You may find the functions `int_of_string` and `String.sub` useful in lexing this token type.
  - *Regular Expression*: `[0-9]+` OR `(-[0-9]+)`
  - *Examples of int parenthesization*:
    - `tokenize "x -1" = [Tok_ID "x"; Tok_Sub; Tok_Int 1]`
    - `tokenize "x (-1)" = [Tok_ID "x"; Tok_Int (-1)]`
- `Tok_String of string`: Valid string will always be surrounded by `""` and **should accept any character except quotes** within them (as well as nothing). You have to "sanitize" the matched string to remove surrounding escaped quotes.
  - *Regular Expression*: `\"[^\"]*\"`
  - *Examples*:
    - `tokenize "330" = [Tok_Int 330]`
    - `tokenize "\"330\"" = [Tok_String "330"]`
    - `tokenize "\"\"\"" (* InvalidInputException *)`
- `Tok_ID of string`: Valid IDs must start with a letter and can be followed by any number of letters or numbers. **Note: Keywords may be substrings of IDs**.
  - *Regular Expression*: `[a-zA-Z][a-zA-Z0-9]*`
  - *Valid examples*:
    - "a"
    - "ABC"
    - "a1b2c3DEF6"
    - "fun1"
    - "ifthenelse"

MicroCaml syntax with its corresponding token is shown below, excluding the four literal token types specified above.

Token Name | Lexical Representation
--- | ---
`Tok_LParen` | `(`
`Tok_RParen` | `)`
`Tok_Equal` | `=`
`Tok_NotEqual` | `<>`
`Tok_Greater` | `>`
`Tok_Less` | `<`
`Tok_GreaterEqual` | `>=`
`Tok_LessEqual` | `<=`
`Tok_Or` | `\|\|`
`Tok_And` | `&&`
`Tok_Not` | `not`
`Tok_If` | `if`
`Tok_Then` | `then`
`Tok_Else` | `else`
`Tok_Add` | `+`
`Tok_Sub` | `-`
`Tok_Mult` | `*`
`Tok_Div` | `/`
`Tok_Concat` | `^`
`Tok_Let` | `let`
`Tok_Def` | `def`
`Tok_In` | `in`
`Tok_Rec` | `rec`
`Tok_Fun` | `fun`
`Tok_Arrow` | `->`
`Tok_DoubleSemi` | `;;`

Notes:
- Your lexing code will feed the tokens into your parser, so a broken lexer can cause you to fail tests related to parsing. 
- In grammars given below, the syntax matching tokens (lexical representation) is used instead of the token name. For example, the grammars below will use `(` instead of `Tok_LParen`. 

## Part 2: Parsing MicroCaml Expressions

In this part, you will implement `parse_expr`, which takes a stream of tokens and outputs as AST for the input expression of type `expr`. Put all of your parser code in [parser.ml](./src/parser.ml) in accordance with the signature found in [parser.mli](./src/parser.mli). 

We present a quick overview of `parse_expr` first, then the definition of AST types it should return, and finally the grammar it should parse.

### `parse_expr`
- **Type:** `token list -> token list * expr`
- **Description:** Takes a list of tokens and returns an AST representing the MicroCaml expression corresponding to the given tokens, along with any tokens left in the token list.
- **Exceptions:** Raise `InvalidInputException` if the input fails to parse i.e does not match the MicroCaml expression grammar.
- **Examples** (more below):
  ```ocaml
  parse_expr [Tok_Int(1); Tok_Add; Tok_Int(2)] =  ([], Binop (Add, Value (Int 1), Value (Int 2)))

  parse_expr [Tok_Int(1)] = ([], Value (Int 1))

  parse_expr [Tok_Let; Tok_ID("x"); Tok_Equal; Tok_Bool(true); Tok_In; Tok_ID("x")] = 
  ([], Let ("x", false, Value (Bool true), ID "x"))

  parse_expr [Tok_DoubleSemi] (* raises InvalidInputException *)
  ```

You will likely want to implement your parser using the the `lookahead` and `match_tok` functions that we have provided; more about them is at the end of this README.

### AST and Grammar for `parse_expr`

Below is the AST type `expr`, which is returned by `parse_expr`. **Note** that the `environment` and `Closure of environment * var * expr` parts are only relevant to Project 4b, so you can ignore them for now.

```ocaml
type op = Add | Sub | Mult | Div | Concat | Greater | Less | GreaterEqual | LessEqual | Equal | NotEqual | Or | And

type var = string

type value =
  | Int of int
  | Bool of bool
  | String of string
  | Closure of environment * var * expr (* not used in P4A *)

and environment = (var * value) list (* not used in P4A *)

and expr =
  | Value of value
  | ID of var
  | Fun of var * expr (* an anonymous function: var is the parameter and expr is the body *)
  | Not of expr
  | Binop of op * expr * expr
  | If of expr * expr * expr
  | FunctionCall of expr * expr
  | Let of var * bool * expr * expr (* bool determines whether var is recursive *)
```

The CFG below describes the language of MicroCaml expressions. This CFG is right-recursive, so something like `1 + 2 + 3` will parse as `Add (Int 1, Add (Int 2, Int 3))`, essentially implying parentheses in the form `(1 + (2 + 3))`.) In the given CFG note that all non-terminals are capitalized, all syntax literals (terminals) are formatted `as non-italicized code` and will come in to the parser as tokens from your lexer. Variant token types (i.e. `Tok_Bool`, `Tok_Int`, `Tok_String` and `Tok_ID`) will be printed *`as italicized code`*.

- Expr -> LetExpr | IfExpr | FunctionExpr | OrExpr
- LetExpr -> `let` Recursion *`Tok_ID`* `=` Expr `in` Expr
  -	Recursion -> `rec` | ε
- FunctionExpr -> `fun` *`Tok_ID`* `->` Expr
- IfExpr -> `if` Expr `then` Expr `else` Expr
- OrExpr -> AndExpr `||` OrExpr | AndExpr
- AndExpr -> EqualityExpr `&&` AndExpr | EqualityExpr
- EqualityExpr -> RelationalExpr EqualityOperator EqualityExpr | RelationalExpr
  - EqualityOperator -> `=` | `<>`
- RelationalExpr -> AdditiveExpr RelationalOperator RelationalExpr | AdditiveExpr
  - RelationalOperator -> `<` | `>` | `<=` | `>=`
- AdditiveExpr -> MultiplicativeExpr AdditiveOperator AdditiveExpr | MultiplicativeExpr
  - AdditiveOperator -> `+` | `-`
- MultiplicativeExpr -> ConcatExpr MultiplicativeOperator MultiplicativeExpr | ConcatExpr
  - MultiplicativeOperator -> `*` | `/`
- ConcatExpr -> UnaryExpr `^` ConcatExpr | UnaryExpr
- UnaryExpr -> `not` UnaryExpr | FunctionCallExpr
- FunctionCallExpr -> PrimaryExpr PrimaryExpr | PrimaryExpr
- PrimaryExpr -> *`Tok_Int`* | *`Tok_Bool`* | *`Tok_String`* | *`Tok_ID`* | `(` Expr `)`

Notice that this grammar is not actually quite compatible with recursive descent parsing. In particular, the first sets of the productions of many of the non-terminals overlap. For example:

- OrExpr -> AndExpr `||` OrExpr | AndExpr

defines two productions for nonterminal OrExpr, separated by |. Notice that both productions starting with AndExpr, so we can't use the lookahead (via FIRST sets) to determine which one to take. This is clear when we rewrite the two productions thus:

- OrExpr -> AndExpr `||` OrExpr
- OrExpr -> AndExpr

When my parser is handling OrExpr, which production should it use? From the above, you cannot tell. The solution is: **You need to refactor the grammar, as shown in [lecture][lecture]** slides 35-37.

To illustrate `parse_expr` in action, we show several examples of input and their output AST.

### Example 1: Basic math

**Input:**
```ocaml
(1 + 2 + 3) / 3
```

**Output (after lexing and parsing):**
```ocaml
Binop (Div,
  Binop (Add, Value (Int 1), Binop (Add, Value (Int 2), Value (Int 3))),
  Value (Int 3))
```

In other words, if we run `parse_expr (tokenize "(1 + 2 + 3) / 3")` it will return the AST above.

### Example 2: `let` expressions

**Input:**
```ocaml
let x = 2 * 3 / 5 + 4 in x - 5
```

**Output (after lexing and parsing):**
```ocaml
Let ("x", false,
  Binop (Add,
    Binop (Mult, Value (Int 2), Binop (Div, Value (Int 3), Value (Int 5))),
    Value (Int 4)),
  Binop (Sub, ID "x", Value (Int 5)))
```

### Example 3: `if then ... else ...`

**Input:**
```ocaml
let x = 3 in if not true then x > 3 else x < 3
```

**Output (after lexing and parsing):**
```ocaml
Let ("x", false, Value (Int 3),
  If (Not (Value (Bool true)), Binop (Greater, ID "x", Value (Int 3)),
   Binop (Less, ID "x", Value (Int 3))))
```

### Example 4: Anonymous functions

**Input:**
```ocaml
let rec f = fun x -> x ^ 1 in f 1
```

**Output (after lexing and parsing):**
```ocaml
Let ("f", true, Fun ("x", Binop (Concat, ID "x", Value (Int 1))),
  FunctionCall (ID "f", Value (Int 1)))
```

Keep in mind that the parser is not responsible for finding type errors. This is the job of the interpreter (Project 4b). For example, while the AST for `1 1` should be parsed as `FunctionCall (Value (Int 1), Value (Int 1))`; if it is executed by the interpreter, it will at that time be flagged as a type error.

### Example 5: Recursive anonymous functions

Notice how the AST for `let` expressions uses a `bool` flag to determine whether a function is recursive or not. When a recursive anonymous function `let rec f = fun x -> ... in ...` is defined, `f` will bind to `fun x -> ...` when evaluating the function. The interpreter will be responsible for handling this. In Project 4b, you will also handle the cases where `rec` is used without anonymous functions as well as attempting recursion without using `rec`.

For now, let's create an infinite recursive loop for fun. 

**Input:**
```ocaml
let rec f = fun x -> f (x*x) in f 2
```

**Output (after lexing and parsing):**
```ocaml
Let ("f", true,
  Fun ("x", FunctionCall (ID "f", Binop (Mult, ID "x", ID "x"))),
  FunctionCall (ID "f", Value (Int 2))))
```

### Example 6: Currying

We will **ONLY** be currying to create multivariable functions as well as passing multiple arguments to them. Here is an example:

**Input:**
```ocaml
let f = fun x -> fun y -> x + y in (f 1) 2
```

**Output (after lexing and parsing):**
```ocaml
Let ("f", false, 
  Fun ("x", Fun ("y", Binop (Add, ID "x", ID "y"))),
  FunctionCall (FunctionCall (ID "f", Value (Int 1)), Value (Int 2)))
```

## Part 3: Parsing `mutop` directives

In this part, you will implement `parse_mutop` (putting your code in [parser.ml](./src/parser.ml)) in accordance with the signature found in [parser.mli](./src/parser.mli). Thus function takes a token list produced by lexing a string that is a mutop (top-level) MicroCaml directive, and returns an AST of OCaml type `mutop`. Your implementation of `parse_mutop` will reuse your `parse_expr` implementation, and will not be much extra work.

We present a quick overview of the function first, then the definition of AST types it should return, and finally the grammar it should parse.

#### `parse_mutop`
- **Type:** `token list -> token list * mutop`
- **Description:** Takes a list of tokens and returns an AST representing the MicroCaml expression at the `mutop` level corresponding to the given tokens, along with any tokens left in the token list.
- **Exceptions:** Raise `InvalidInputException` if the input fails to parse i.e does not match the MicroCaml definition grammar.
- **Examples:**
  ```ocaml
  parse_mutop [Tok_Def; Tok_ID("x"); Tok_Equal; Tok_Bool(true); Tok_DoubleSemi] = ([], Def ("x", Value (Bool true)))

  parse_mutop [Tok_DoubleSemi] = ([], NoOp)

  parse_mutop [Tok_Int(1); Tok_DoubleSemi] = ([], Expr (Value (Int 1))))

  parse_mutop [Tok_Let; Tok_ID "x"; Tok_Equal; Tok_Bool true; Tok_In; Tok_ID "x"; Tok_DoubleSemi] = 
  ([], Expr (Let ("x", false, Value (Bool true), ID "x")))
  ```

### AST and Grammar of `parse_mutop`

Below is the AST type `mutop`, which is returned by `parse_mutop`, followed by the CFG that it parses for MicroCaml expressions at the `mutop` level. This CFG is similar (and similarly formatted) to the CFG of `parse_expr` and relies its implementation of Expr.

```ocaml
type mutop = 
  | Def of var * expr
  | Expr of expr
  | NoOp
```

The CFG is as follows:

- Mutop -> DefMutop | ExprMutop | `;;`
- DefMutop -> `def` *`Tok_ID`* `=` Expr `;;`
- ExprMutop -> Expr `;;`

Notice how a valid input for the `parse_mutop` must always terminate with `Tok_DoubleSemi` and input of just `Tok_DoubleSemi` to the parser is considered valid as per the AST.

For this part, we created a new keyword `def` to refer to top-level MicroCaml expressions to differentiate local `let`. In essence, `def` is similar to top-level (global) `let` expressions in normal (OCaml) `utop`. This means `def` will create **global definitions** for variables while running `mutop`, in part 4b. Another key difference between `def` and the `let` expressions defined in Part 2 is that `def` should be *implicitly recursive*. (Note that `def rec x = ...;;` is not valid as per the given AST---basically the `rec` is implicit).

Here are some example mutop directives. Note that `parse_mutop` should return a tuple of (updated token list, parsed AST), but in these examples we omit the updated token list since it should always just be an empty list.

### Example 1: Global definition 

**Input:**
```ocaml
def x = let a = 3 in if a <> 3 then 0 else 1;;
```

**Output (after lexing and parsing):**
```ocaml
Def ("x",
  Let ("a", false, Value (Int 3),
    If (Binop (NotEqual, ID "a", Value (Int 3)), Value (Int 0), Value (Int 1))))
```

### Example 2: Implicit recursion on `f`

**Input:**
```ocaml
def f = fun x -> if x > 0 then f (x-1) else "done";;
```

**Output (after lexing and parsing):**
```ocaml
Def ("f",
  Fun ("x",
   If (Binop (Greater, ID "x", Value (Int 0)),
    FunctionCall (ID "f", Binop (Sub, ID "x", Value (Int 1))),
    Value (String "done"))))
```

### Example 3: Expression

**Input:**
```ocaml
(fun x -> "(" ^ x ^ ")") "parenthesis";;
```

**Output (after lexing and parsing):**
```ocaml
Expr (
  FunctionCall (Fun ("x",
    Binop (Concat, Value (String "("),
      Binop (Concat, ID "x", Value (String ")")))),
    Value (String "parenthesis")))
```

## Provided functions

To help you implement both parsers, we have provided some helper functions in the `parser.ml` file. You are not required to use these, but they are recommended.

### `match_token`
- **Type:** `token list -> token -> token list`
- **Description:** Takes the list of tokens and a single token as arguments, and returns a new token list with the first token removed IF the first token matches the second argument.
- **Exceptions:** Raise `InvalidInputException` if the first token does not match the second argument to the function.

### `match_many`
- **Type:** `token list -> token list -> token list`
- **Description:** An extension of `match_token` that matches a sequence of tokens given as the second token list and returns a new token list with that matches each token in the order in which they appear in the sequence. For example, `match_many toks [Tok_Let]` is equivalent to `match_token toks Tok_Let`.
- **Exceptions:** Raise `InvalidInputException` if the tokens do not match.

### `lookahead`
- **Type:** `token list -> token option`
- **Description:** Returns the top token in the list of tokens as an option, returning `None` if the token list is empty. **In constructing your parser, the lack of lookahead token (None) is fine for the epsilon case.**

### `lookahead_many`
- **Type:** `token list -> int -> token option`
- **Description:** An extension of `lookahead` that returns token at the nth index in the list of tokens as an option, returning `None` if the token list is empty at the given index or the index is negative. For example, `lookahead_many toks 0` is equivalent to `lookahead toks`.

## Academic Integrity

Please **carefully read** the academic honesty section of the course syllabus. **Any evidence** of impermissible cooperation on projects, use of disallowed materials or resources, or unauthorized use of computer accounts, **will be** submitted to the Student Honor Council, which could result in an XF for the course, or suspension or expulsion from the University. Be sure you understand what you are and what you are not permitted to do in regards to academic integrity when it comes to project assignments. These policies apply to all students, and the Student Honor Council does not consider lack of knowledge of the policies to be a defense for violating them. Full information is found in the course syllabus, which you should review before starting.

[str doc]: https://caml.inria.fr/pub/docs/manual-ocaml/libref/Str.html
[lecture]: http://www.cs.umd.edu/class/spring2021/cmsc330/lectures/20-parsing.pdf



# Project 4B: MicroCaml Interpreter
Due: November 23, 2021 at 11:59 PM (late November 24, *10% penalty*)

Points: 48 public, 52 semipublic

## Introduction

This is part (B) of project 4, in which you implement an interpreter for MicroCaml.

In particular, you will implement two functions, `eval_expr` and `eval_mutop`. Each of these takes an `environment` (defined in [microCamlTypes.ml](./src/microCamlTypes.ml)) as a parameter, which acts as a map from variables to values. The `eval_expr` function evaluates an expression in the given environment, returning a `value`, while `eval_mutop` takes a `mutop` -- a top-level directive -- and returns a possibly updated environment and any additional result.

You will need to use Imperative OCaml -- notably references -- to implement this project. This use is small, but important. More details below.

### Ground Rules and Extra Info

The interpreter must be implemented in `eval.ml` in accordance with the signatures for `eval_expr` and `eval_mutop` found in [eval.mli](./src/eval.mli). `eval.ml` is the only file you will write code in. 

In your code, you may use any standard library functions, but the ones that will be useful to you will be found in the [`Stdlib` module][stdlib doc]. If you come asking for help using something we have not taught we will direct you to use methods taught in this class.

### Compilation, Tests, and Running

You can submit through `gradescope-submit` from the project directory and the project will be automatically submitted. You can also manually submit to [Gradescope](https://www.gradescope.com/courses/171498/assignments/786590). *You may only submit the `eval.ml` file.*

You do not need a working parser and lexer to implement this project --- all testing can be done on abstract syntax trees directly.

To test locally, run `dune runtest -f`. To test from the toplevel, run `dune utop src`. The necessary functions and types will automatically be imported for you. For example, from `utop`, you can write:

```ocaml
eval_expr [] (Let ("x", false, Value (Bool true), ID "x"));;
- : value = Bool true
```

### Running Mutop

If you do have a working parser and lexer, you can run them and your interpreter together in *mutop* (Micro-utop), a version of `utop` for MicroCaml. Run the command `dune exec bin/mutop.exe` in your terminal or use the shell script `bash mutop.sh` to start the mutop toplevel. The toplevel uses your implementations for `parse_mutop` and `eval_mutop` to execute MicroCaml expressions. Here is an example of its use:

![Mutop Example](assets/ex.gif)

**Note:** If you are having issues running *mutop*, run the command `dune build` before starting the mutop toplevel.

## Operational Semantics

We are going to describe how to implement your interpreter using examples, below. A more succinct description is this [operational semantics](./microcaml-opsem.pdf). Even if you don't use it much to do the project, we expect you to understand it -- we may take questions from it for the exam.

## Part 1: Evaluating Expressions
### `eval_expr : environment -> expr -> value` 

This function takes an environment `env` and an expression `e`, which is type `expr`, and produces the result of evaluating `e`, which is something of type `value`. All of the types mentioned here are defined in [microCamlTypes](src/microCamlTypes.ml); do not change any of them!

The environment `env` is a `(var * value ref) list`, where `var` refers to an variable name (which is a string), and the `value ref` refers to its corresponding value in the `environment`; it's a `ref` because the value could change, due to implementing recursion, as discussed for `Let` below. Elements earlier in the list shadow elements later in the list. 

There are three possible error cases, represented by three different exceptions (in `eval.ml` -- do not change):

```
exception TypeError of string
exception DeclareError of string
exception DivByZeroError
```

A `TypeError` happens when an operation receives an argument of the wrong type; a `DeclareError` happens when an ID is seen that has not been declared; and a `DivByZeroError` happens on attempted division by zero. We do not enforce what messages you use when raising the `TypeError` or `DeclareError` exceptions. That's up to you.

Evaluation of subexpressions should be done from left to right to ensure that lines with multiple possible errors match up with our expected errors.

Now we describe what your interpreter should do for each kind of `expr`, i.e.,

```
type expr =
  | Value of value
  | ID of var
  | Fun of var * expr
  | Not of expr
  | Binop of op * expr * expr
  | If of expr * expr * expr
  | FunctionCall of expr * expr
  | Let of var * bool * expr * expr
```

### Value 

A `value` is defined as
```
type value =
  | Int of int
  | Bool of bool
  | String of string
  | Closure of environment * var * expr
```
Values (often literals in the original source program) evaluate to themselves, i.e., 

```ocaml
eval_expr [] (Value(Int 1)) = Int 1
eval_expr [] (Value(Bool false)) = Bool false
eval_expr [] (Value(String "x")) = String "x"
```

A *closure* is the result of evaluating an anonymous function; it, too, evaluates to itself. We will discuss closures in detail when considering anonymous functions, and function calls, below.
```ocaml
eval_expr [] (Value(Closure ([], "x", Fun ("y", Binop (Add, ID "x", ID "y"))))) = Closure ([], "x", Fun ("y", Binop (Add, ID "x", ID "y")))
```

### ID

An identifier evaluates to whatever value it is mapped to by the environment. Should raise a `DeclareError` if the identifier has no binding.

```ocaml
eval_expr [("x", ref (Int 1))] (ID "x") = Int 1
eval_expr [] (ID "x") (* DeclareError "Unbound variable x" *)
```

See the discussion of `Let` below for advice about managing environments.

### Not

The unary `not` operator operates only on booleans and produces a `Bool` containing the negated value of the contained expression. If the expression in the `Not` is not a boolean (or does not evaluate to a boolean), a `TypeError` should be raised.

```ocaml
eval_expr [("x", ref (Bool true))] (Not (ID "x")) = Bool false
eval_expr [("x", ref (Bool true))] (Not (Not (ID "x"))) = Bool true
eval_expr [] (Not (Value(Int 1))) (* TypeError "Expected type bool" *)
```

### Binop

There are five sorts of binary operator: Those carrying out integer arithmetic; those carrying out integer ordering comparisons; one carrying out string concatenation; and one carrying out equality (and inequality) comparisons; and those implementing boolean logic.

#### Add, Sub, Mult, and Div

Arithmetic operators work on integers; if either argument evaluates to a non-`Int`, a `TypeError` should be raised. An attempt to divide by zero should raise a `DivByZeroError` exceptio. 

```ocaml
eval_expr [] (Binop (Add, Value(Int 1), Value(Int 2))) = Int 3
eval_expr [] (Binop (Add, Value(Int 1), Value(Bool false))) (* TypeError "Expected type int" *)
eval_expr [] (Binop (Div, Value(Int 1), Value(Int 0))) (* DivByZeroError *)
```

#### Greater, Less, GreaterEqual, and LessEqual

These relational operators operate only on integers and produce a `Bool` containing the result of the operation. If either argument evaluates to a non-`Int`, a `TypeError` should be raised.

```ocaml
eval_expr [] (Binop(Greater, Value(Int 1), Value(Int 2))) = Bool false
eval_expr [] (Binop(LessEqual, Value(Bool false), Value(Bool true))) (* TypeError "Expected type int" *)
```

#### Concat

This operation returns the result of concatenating two strings; if either argument evaluates to a non-`String`, a `TypeError` should be raised. 

```ocaml
eval_expr [] (Binop (Concat, Value(Int 1), Value(Int 2))) (* TypeError "Expected type string" *)
eval_expr [] (Binop (Concat, Value(String "hello "), Value(String "ocaml"))) = String "hello ocaml"
```

#### Equal and NotEqual

The equality operators require both arguments to be of the same type. The operators produce a `Bool` containing the result of the operation. If the two arguments to these operators do not evaluate to the same type (e.g., one boolean and one integer), a `TypeError` should be raised. Moreover, we *cannot compare two closures for equality* -- to do so risks an infinite loop because of the way recursive functions are implemented; trying to compare them also raises `TypeError` (OCaml does the same thing in its implementation, BTW).

```ocaml
eval_expr [] (Binop(NotEqual, Value(Int 1), Value(Int 2))) = Bool true
eval_expr [] (Binop(Equal, Value(Bool false), Value(Bool true))) = Bool false
eval_expr [] (Binop(Equal, Value(String "hi"), Value(String "hi"))) = Bool true
eval_expr [] (Binop(NotEqual, Value(Int 1), Value(Bool false))) (* TypeError "Cannot compare types" *)
```

#### Or and And

These logical operations operate only on booleans and produce a `Bool` result. If either argument evaluates to a non-`Bool`, a `TypeError` should be raised.

```ocaml
eval_expr [] (Binop(Or, Value(Int 1), Value(Int 2))) (* TypeError "Expected type bool" *)
eval_expr [] (Binop(Or, Value(Bool false), Value(Bool true))) = Bool true
```

### If

The `If` expression consists of three subexpressions - a guard, the true branch, and the false branch. The guard expression must evaluate to a `Bool` - if it does not, a `TypeError` should be raised. If it evaluates to `Bool true`, the true branch should be evaluated; else the false branch should be. 

```ocaml
eval_expr [] (If (Binop (Equal, Value (Int 3), Value (Int 3)), Value (Bool true), Value (Bool false))) = Bool true
eval_expr [] (If (Binop (Equal, Value (Int 3), Value (Int 2)), Value (Int 5), Value (Bool false))) = Bool false
```

Notes:
- Only one branch should be evaluated, not both. 
- The true and false branches **could evaluate to values having different types**. This is an effect of MicroCaml being dynamically typed.

### Let

The `Let` consists of four components - an ID's name `var` (which is a string); a boolean indicating whether or not the bound variable is referenced in its own definition (i.e., whether it's *recursive*); the *initialization expression*; and the *body expression*.

#### Non-recursive bindings

For a non-recursive `Let`, we first evaluate the initialization expression, which produces a value *v* or raises an error. If the former, we then return the result of evaluating the body expression in an environment extended with a mapping from the `Let`'s ID variable to *v*. (Evaluating the body might cause an exception to be raised.) 

```ocaml
eval_expr [] (Let ("x", false,
  Binop (Add, Binop (Mult, Value (Int 2), 
    Binop (Div, Value (Int 3), Value (Int 5))), Value (Int 4)),
  Binop (Sub, ID "x", Value (Int 5)))) = Int (-1)
```

#### Recursive bindings

For a recursive `Let`, we evaluate the initialization expression in an environment extended with a mapping from the ID we are binding to a temporary placeholder; this way, the initialization expression is permitted to refer to itself, the ID being bound. Then, we *update* that placeholder to *v*, the result, before evaluating the body.

The AST given in this example corresponds to the MicroCaml program `let rec f = fun x -> if x = 0 then x else (x + (f (x-1))) in f 8`:

```ocaml
eval_expr [] (Let ("f", true,
  Fun ("x",
    If (Binop (Equal, ID "x", Value (Int 0)), ID "x",
      Binop (Add, ID "x",
        FunctionCall (ID "f", Binop (Sub, ID "x", Value (Int 1)))))),
    FunctionCall (ID "f", Value (Int 8)))) = Int 36
```

#### Environments

Being able to modify the placeholder is made possibly by using references; this is why the type `environment` given in `microCamlTypes.ml` is `(var * value ref) list` and not `(var * value) list`. To make it easy to work with this kind of environment, we recommend you use the functions given at the top of `eval.ml`:

- `extend env x v` produces an environment that extends `env` with a mapping from `x` to `v`
- `lookup env x` returns `v` if `x` maps to `v` in `env`; if there are multiple mappings, it chooses the most recent.
- `extend_tmp env x` produces an environment that extends `env` with a mapping from `x` to a temporary placeholder.
- `update env x v` produces an environment that updates `env` in place, modifying its most recent mapping for `x` to be `v` instead (removing the placeholder).

### Fun

The `Fun` is used for anonymous functions, which consist of two components - a parameter, which is a string as an ID's name, and a body, which is an expression. A `Fun` evaluates to a `Closure` that captures the current environment, so as to implement lexical (aka static) scoping.

```ocaml
eval_expr [("x", ref (Bool true))] (Fun ("y", Binop (And, ID "x", ID "y")))
  = Closure ([("x", ref (Bool true))], "y", Binop (And, ID "x", ID "y"))
eval_expr [] (Fun ("x", Fun ("y", Binop (And, ID "x", ID "y"))))
	= Closure ([], "x", Fun ("y", Binop (And, ID "x", ID "y")))
```

### FunctionCall

The `FunctionCall` has two subexpressions. We evaluate the first to a `Closure(A,x,e)` (otherwise, a `TypeError` should be raised) and the second to a value *v*. Then we evaluate `e` (the closure's body) in environment `A` (the closure's environment), returning the result.

```ocaml
eval_expr [] (FunctionCall (Value (Int 1), Value (Int 1))) (* TypeError "Not a function" *)
eval_expr [] (Let ("f", false, Fun ("x", Fun ("y", Binop (Add, ID "x", ID "y"))),
  FunctionCall (FunctionCall (ID "f", Value (Int 1)), Value (Int 2)))) = Int 3
```

The AST in the second example is equivalent to the MicroCaml expression `let f = fun x -> fun y -> x + y in (f 1) 2`.

## Part 2: Evaluating Mutop Directive
### `eval_mutop : environment -> mutop -> environment * (value option)`

This function evaluates the given `mutop` directive in the given `environment`, returning an updated environment with an optional `value` as the result. There are three kinds of `mutop` directive (as defined in [microCamlTypes.ml](./src/microCamlTypes.ml)):

  ```ocaml
  type mutop =
    | Def of var * expr
    | Expr of expr
    | NoOp
  ```

### Def

For a `Def`, we evaluate its `expr` in the given environment, but with a placeholder set for `var` (see the discussion of recursive `Let`, above, for more about environment placeholders), producing value *v*. We then update the binding for `var` to be *v* and return the extended environment, along with the value itself. 

```ocaml
eval_mutop [] (Def ("x", Value(Bool(true)))) =  ([("x", {contents = Bool true})], Some (Bool true))
```
```ocaml
eval_mutop [] (Def ("f",
  Fun ("y",
    If (Binop (Equal, ID "y", Value (Int 0)), Value (Int 1),
    FunctionCall (ID "f", Binop (Sub, ID "y", Value (Int 1))))))) =
([("f",
  {contents =
    Closure (<cycle>, "y",
      If (Binop (Equal, ID "y", Value (Int 0)), Value (Int 1),
        FunctionCall (ID "f", Binop (Sub, ID "y", Value (Int 1)))))})],
  Some 
    (Closure ([("f", {contents = <cycle>})], "y",
      If (Binop (Equal, ID "y", Value (Int 0)), Value (Int 1),
        FunctionCall (ID "f", Binop (Sub, ID "y", Value (Int 1)))))))
```

### Expr
For a `Expr`, we should evaluate the expression in the given environment, and return that environment and the resulting value.

```ocaml
eval_mutop [] (Expr (FunctionCall (Fun ("x",
  Binop (Concat, Value (String "("),
    Binop (Concat, ID "x", Value (String ")")))),
      Value (String "parenthesis")))) = ([], Some (String "(parenthesis)"))
```

### NoOp

The `NoOp` should return the original environment and no value (`None`).

```ocaml
eval_mutop [] NoOp = ([], None)
```

## Academic Integrity

Please **carefully read** the academic honesty section of the course syllabus. **Any evidence** of impermissible cooperation on projects, use of disallowed materials or resources, or unauthorized use of computer accounts, **will be** submitted to the Student Honor Council, which could result in an XF for the course, or suspension or expulsion from the University. Be sure you understand what you are and what you are not permitted to do in regards to academic integrity when it comes to project assignments. These policies apply to all students, and the Student Honor Council does not consider lack of knowledge of the policies to be a defense for violating them. Full information is found in the course syllabus, which you should review before starting.


<!-- links -->

[stdlib doc]: https://caml.inria.fr/pub/docs/manual-ocaml/libref/Stdlib.html
# Xenoform

Xenoform is a preprocessor for [terraform](https://developer.hashicorp.com/terraform) code.
By introducing some syntax extensions (explained below), xenoform provides better developer
experience for your terraform projects.

Xenoform syntax is a superset of the original terraform syntax (to be precise,
[HCL2](https://github.com/hashicorp/hcl) syntax); input is converted into normal terraform
code. Thus it's fairly simple to introduce xenoform into your terraform workflow.

## Supported features and motivations

See also `tests/success/all_features.in.tf` for a usage example.

### Variables with narrower scopes

- Motivation
  - Terraform `locals` block introduces module-local variables. Sometimes we want
    file-local or block-local variables.
- Example:

  ```tf
  flocals { # define file locals
    x = 1
  }

  resource "someprovider_someresource" "xxx" {
    for_each = toset(["aaa", "bbb"])

    blocals { # define variables that reside only in the current resource/module block
      foo = "xxx_${each.value}"
    }

    arg1 = flocal.x   # expanded to `local.flocal_filename_x`
    arg2 = blocal.foo # expanded to `"xxx_${each.value}"`
  }
  ```

- Note:
  - `flocals` are implemented as simple name mangling: `flocals` block is
    converted to `locals` block with a file-specific variable name prefix.
  - `blocals` are implemented by term rewriting. `blocal.var_name` is replaced with the
    right hand side of the `blocals` variable. Therefore, in a `resource`/`module` with
    `for_each`, `each` can be used in the right hand side of `blocals` variables.

### Macros

- Motivation
  - Terraform does not support custom functions in the HCL2 source files.
    - [Provider-defined functions](https://developer.hashicorp.com/terraform/plugin/framework/functions/concepts)
      is possible but it's somewhat tedious to define small utilities in Go.
    - Pure-HCL2 way to reuse an expression is to define a
      [terraform module](https://developer.hashicorp.com/terraform/tutorials/modules),
      but it's syntactically heavy on the calling side.
- Example

  ```tf
  macro "hoge" "x" "y" { # define a macro named `hoge` that receives 2 arguments
    x2     = x + 1
    y2     = y + 2
    return = x2 * y2 # the last block attribute must be `return`
  }

  locals {
    use_hoge = macro::hoge(5, 10) # expanded to `((5 + 1) * (10 + 2))`
  }
  ```

### Including macros defined in other files

- Include from code: By adding the following you can use macros defined in `another_file.in.tf`.

  ```tf
  macro_include {
    source = "./another_file.in.tf"
  }
  ```

- Include from command line: You can instead pass `--macro-prelude another_file.in.tf`
  in order to use macros defined in the file.

### `pipeline` macro

- Motivation
  - Large complex expressions such as nested for-expressions are hard to read. We can
    somewhat improve the readability by introducing locals for each step of the complex
    expression. But the locals could then be a source of confusions.
  - We want to construct complex expressions from multiple steps as "lambda" expressions
    and pour the result of one step into the next step.
- Example:

  ```tf
  locals {
    # Expanded to `join(", ", [for x in concat([1, 2, 3], [4, 5]) : x + 1])` with some extra whitespaces
    use_pipeline = macro::pipeline(
      [1, 2, 3],            # 1st step (just an expression).
      concat(_, [4, 5]),    # 2nd step (expression with a placeholder). `_` is replaced by the result of the 1st step.
      [for x in _ : x + 1], # 3rd step (expression with a placeholder). `_` is replaced by the result of the 2nd step.
      join(", ", _),        # Last step (expression with a placeholder). `_` is replaced by the result of the 3rd step.
    )
  }
  ```

- Note: `pipeline` macro is a special macro and is implemented in the preprocessor layer,
  instead of a macro defined using `macro` block. It takes arbitrary number of arguments (steps).

### Assertion

- Motivation
  - Terraform does not directly support `assert` functionality in other languages.
    Validating if an expected precondition is met before executing plan/apply is useful
    for catching issues earlier.
  - Terraform does offer multiple ways to [validate configurations](https://developer.hashicorp.com/terraform/language/validate),
    but there's currently no support for assertions that (a) does not belong to a specific resource,
    data source or module, and (b) raises an error before making any action.
  - `assert` block is introduced to cover such needs.
- Example:

  ```tf
  assert "string_not_equal" {
    condition = "an expression that should" == "evaluate to true but actually false"
  }
  ```

  is expanded to a local and causes a plan-time error.


- Note:
  - An `assert` block is expanded to a `locals` with a conditional (ternary) expression
    that raises an error only when the condition evaluates to `false`. To raise an error
    we use [`tobool()`](https://developer.hashicorp.com/terraform/language/functions/tobool)
    function (as a workaround), but the type conversion itself is not relevant; look into
    the string passed to `toobool()`.

## Caveats

- Some of code editor features (e.g. language server protocol) for terraform won't work.
- Xenoform outputs may contain extra parenthesis, whitespace and newline characters.
  Xenoform itself does not try to prettify the output; when you want to remove extra
  whitespaces use `terraform fmt`. It also means that line numbers are not preserved.
  Be careful when you see line numbers in error/warning messages by terraform or other tools.
- Macro bodies are expanded at call site. If a macro body contains variable references
  such as `local.foo` and `flocal.bar` and the macro resides in another directory/file,
  the variables cannot be resolved from the call site.
- Code comments are basically preserved so that static code analysis tools can use them
  (e.g. to suppress warnings of a tool). However, comments before xenoform-specific blocks
  (`macro`, `blocals` and `assert`) are removed together with the blocks.

Main developer : [@skirino](https://github.com/skirino)

locals {
  a  = "foo"
  p0 = macro::pipeline("")
  p1 = macro::pipeline(
    [1, 2, 3],
    concat(_, [4, 5]),
    [for x in _ : x + 1],
  )
}

flocals { # define file locals
  x = { y = 4 }
  z = 5
}

macro "hoge" "x" "y" { # define a macro named `hoge` that receives 2 arguments
  x2     = x + 1
  y2     = y + 2
  return = x2 * y2 # the last block attribute must be `return`
}

macro_include {
  source = "./macro_include1.in.tf"
}

macro_include {
  source = "./macro_include2.in.tf" # `macro_include2.in.tf` file is also included from `macro_include1.in.tf`.
}

resource "someprovider_someresource" "xxx" {
  for_each = toset(["aaa", "bbb"])

  blocals { # define variables that reside only in the current resource/module block
    foo    = "${local.a}_${flocal.x.y}_${each.value}"
    bar    = local.z + 3
    baz    = blocal.bar + 10
    b_list = ["a", "b", "c"]
    b_obj  = { k1 = "v1", k2 = "v2" }
  }

  use_blocal_foo                = blocal.foo
  use_blocal_baz                = blocal.baz
  use_blocal_list               = blocal.b_list[1]
  use_blocal_object             = blocal.b_obj.k2
  use_macro_in_this_file        = macro::hoge(blocal.bar + 6, flocal.x.y)
  use_directly_included_macro   = macro::included1(7)
  use_indirectly_included_macro = macro::included2(8)
  use_macros_in_nested_expr     = macro::hoge(macro::included1(blocal.bar), macro::included2(flocal.x.y))
  use_prelude_macro1            = macro::prelude1(11)
  use_prelude_macro2            = macro::prelude2(12)
}

assert "number_equality" {
  condition = (1 + 1) == 2
}

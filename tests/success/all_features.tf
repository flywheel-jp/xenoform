locals {
  a  = "foo"
  p0 = ("")
  p1 = (
    [for x in (
    concat((
    [1, 2, 3]), [4, 5])) : x + 1])
}

locals { # define file locals
  flocal_all_features_x = { y = 4 }
  flocal_all_features_z = 5
}

resource "someprovider_someresource" "xxx" {
  for_each = toset(["aaa", "bbb"])

  use_blocal_foo                = ( "${local.a}_${local.flocal_all_features_x.y}_${each.value}")
  use_blocal_baz                = ( ( local.z + 3) + 10)
  use_blocal_list               = ( ["a", "b", "c"])[1]
  use_blocal_object             = ( { k1 = "v1", k2 = "v2" }).k2
  use_macro_in_this_file        = ( ( (( local.z + 3) + 6) + 1) * ( ( local.flocal_all_features_x.y) + 2))
  use_directly_included_macro   = (( ((7)) + ( 9)))
  use_indirectly_included_macro = ( (8) + ( 9))
  use_macros_in_nested_expr     = ( ( ((( ((( local.z + 3))) + ( 9)))) + 1) * ( (( (local.flocal_all_features_x.y) + ( 9))) + 2))
  use_prelude_macro1            = (( ((11)) + 11))
  use_prelude_macro2            = ( (12) + 12)
}

locals {
  # tflint-ignore: terraform_unused_declarations
  assert_all_features_number_equality = ( (1 + 1) == 2) ? "ASSERTION OK: number_equality" : tobool("ASSERTION FAILED: number_equality in file 'all_features': condition=${ (1 + 1) == 2 }")
}

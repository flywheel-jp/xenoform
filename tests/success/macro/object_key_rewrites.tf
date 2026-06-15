
locals {
  var_in_obj_key                      = ({ (("str")) = 1 })
  var_in_both_obj_key_value           = ({ (("str")) = ("str")})
  macro_call_in_obj_key               = { (( "${ ("key") }_")) = "value" }
  macro_call_in_obj_key_value         = { (( "${ ("key") }_")) = ( "${ ("value") }_")}
  var_and_macro_call_in_obj_key_value = ({
    fixed_key               = "fixed_value"
    (("str"))                     = ("str")
    (( "${ (("str")) }_")) = ( "${ (("str")) }_")
})
}


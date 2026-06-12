macro "append_char" "s" {
  return = "${s}_"
}

macro "obj_k" "s" {
  return = { (s) = 1 }
}

macro "obj_kv" "s" {
  return = { (s) = s }
}

macro "obj_all" "s" {
  return = {
    fixed_key               = "fixed_value"
    (s)                     = s
    (macro::append_char(s)) = macro::append_char(s)
  }
}

locals {
  var_in_obj_key                      = macro::obj_k("str")
  var_in_both_obj_key_value           = macro::obj_kv("str")
  macro_call_in_obj_key               = { (macro::append_char("key")) = "value" }
  macro_call_in_obj_key_value         = { (macro::append_char("key")) = macro::append_char("value") }
  var_and_macro_call_in_obj_key_value = macro::obj_all("str")
}

macro_include {
  source = "./macro_included_from_prelude.in.tf"
}

macro "prelude1" "x" {
  return = macro::included_from_prelude(x)
}

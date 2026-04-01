macro_include {
  source = "./macro_include2.in.tf"
}

macro "included1" "x" {
  return = macro::included2(x)
}

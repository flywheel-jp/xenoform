macro "foo" "x" {
  return = x
}

locals {
  a = { a = macro::foo(1) }.a
}

macro "foo" "x" {
  return = x
}

locals {
  a = macro::foo({ a = macro::foo(1) }.a)
}

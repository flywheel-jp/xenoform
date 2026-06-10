macro "bind" "x" {
  return = x + 1
}

locals {
  a = macro::bind(2)
}

macro "recursive1" "x" {
  return = macro::recursive1(x + 1)
}

macro "recursive2" "x" {
  return = macro::recursive2(x + 2)
}

locals {
  use_recursive = macro::recursive1(3)
}

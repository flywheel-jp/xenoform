macro "pipeline" "x" {
  return = x + 1
}

locals {
  a = macro::pipeline(2)
}

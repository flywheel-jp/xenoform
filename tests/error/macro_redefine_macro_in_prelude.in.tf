macro "map" "arr" "f" {
  return = [for e in arr : macro::bind(f, e)]
}

locals {
  a = macro::map([1, 2, 3], _1 + 1)
}

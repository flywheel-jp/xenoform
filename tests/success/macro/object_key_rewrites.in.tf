macro "append_char" "s" {
  return = "${s}_"
}

macro "make_map" "k" {
  return = { (k) = 1 }
}

locals {
  m1 = { (macro::append_char("key")) = 10 }
  m2 = macro::make_map("key")
}

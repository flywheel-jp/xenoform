macro "foo" "x" {
  return = x + 1
}

resource "someprovider_someresource" "abc" {
  arg = macro::bar(10)
}

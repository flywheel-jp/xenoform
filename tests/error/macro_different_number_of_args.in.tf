macro "foo" "x" {
  return = x + 1
}

resource "someprovider_someresource" "abc" {
  arg = macro::foo(10, 11)
}

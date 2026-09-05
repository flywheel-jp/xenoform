resource "someprovider_someresource" "xxx" {
  flocals {
    foo = "foo"
  }

  assert "my_assert" {
    condition = 1 + 1 == 2
  }
}

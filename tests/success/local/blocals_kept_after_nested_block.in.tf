resource "someprovider_someresource" "xxx" {
  blocals {
    foo = "foo"
    bar = "${blocal.foo} bar"
  }

  some_block {}
  use_blocal_foo = blocal.foo
  use_blocal_bar = blocal.bar
}

resource "someprovider" "foo" {
  blocals {
    x = blocal.x + 1
  }

  arg = blocal.x
}

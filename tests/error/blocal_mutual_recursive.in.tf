resource "someprovider" "foo" {
  blocals {
    x = blocal.y + 1
    y = blocal.x + 2
  }

  arg = blocal.x
}

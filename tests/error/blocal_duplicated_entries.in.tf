resource "someprovider" "foo" {
  blocal {
    x = 1
    y = 2
    x = 3
  }

  arg = blocal.x
}

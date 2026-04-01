resource "someprovider" "foo" {
  blocal {
    x = 1
  }

  arg = blocal.x
}

resource "someprovider_someresource" "bar" {
  blocal {
    y = 2
  }

  arg = blocal.x
}

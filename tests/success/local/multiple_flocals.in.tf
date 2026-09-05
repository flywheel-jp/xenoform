flocals {
  a = 1
}

flocals {
  b = flocal.a + 1
}

locals {
  use_a = flocal.a
  use_b = flocal.b
}

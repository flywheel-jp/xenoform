locals {
  flocal_multiple_flocals_a = 1
}

locals {
  flocal_multiple_flocals_b = local.flocal_multiple_flocals_a + 1
}

locals {
  use_a = local.flocal_multiple_flocals_a
  use_b = local.flocal_multiple_flocals_b
}


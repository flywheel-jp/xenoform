macro "recursive" "x" "acc" {
  return = x == 0 ? acc : macro::recursive(x - 1, acc + x)
}

locals {
  # note: Even for `3` this macro call results in an infinite macro expansions
  # because `x == 0 ? ... : ...` is evaluated at runtime, not at preprocessing.
  use_recursive = macro::recursive(3, 0)
}

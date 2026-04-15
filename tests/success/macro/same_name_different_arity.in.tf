macro "foo" "x" "y" {
  return = x + y
}

macro "foo" "x" {
  return = macro::foo(x, 1)
}

assert "simulate_default_arg" {
  condition = macro::foo(2) == 3
}

macro "included2" "x" {
  return = x + macro::constant()
}

macro "constant" {
  return = 9
}

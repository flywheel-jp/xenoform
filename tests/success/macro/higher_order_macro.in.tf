macro "mymap" "arr" "f" {
  return = [for e in arr : macro::bind(f, e)]
}

locals {
  use_bind = macro::bind(_1 + _2, 10, 20)

  use_map_with_pipeline = macro::pipeline(
    [1, 2, 3],
    macro::mymap(_, _1 + 1),
    macro::mymap(_, _1 * 2),
  )
}

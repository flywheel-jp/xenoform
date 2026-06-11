assert "delete_key_nohit" {
  condition = macro::delete_key({}, "k") == {}
}
assert "delete_key_hit" {
  condition = macro::delete_key({ a = 1, b = 2, c = 3 }, "b") == { a = 1, c = 3 }
}

assert "merge_by" {
  condition = macro::merge_by({ a = 1, b = 2, c = 3, d = 4 }, { b = 20, d = 40, e = 50 }, _2 + _3) == { a = 1, b = 22, c = 3, d = 44, e = 50 }
}

assert "flatten_objects2_empty" {
  condition = macro::flatten_objects2([], "a") == []
}
assert "flatten_objects2_nonempty" {
  condition = macro::flatten_objects2([
    { a = [{ c = 1, d = 2 }, { c = 3, d = 4 }], b = "x" },
    { a = [{ c = 5, d = 6 }], b = "y" },
  ], "a") == [
    { a = { c = 1, d = 2 }, b = "x" },
    { a = { c = 3, d = 4 }, b = "x" },
    { a = { c = 5, d = 6 }, b = "y" },
  ]
}

assert "flatten_objects3_empty" {
  condition = macro::flatten_objects3([], "a", "c") == []
}
assert "flatten_objects3_nonempty" {
  condition = macro::flatten_objects3([
    { a = [{ c = [10, 20], d = 2 }, { c = [30], d = 4 }], b = "x" },
    { a = [{ c = [40, 50, 60], d = 6 }], b = "y" },
  ], "a", "c") == [
    { a = { c = 10, d = 2 }, b = "x" },
    { a = { c = 20, d = 2 }, b = "x" },
    { a = { c = 30, d = 4 }, b = "x" },
    { a = { c = 40, d = 6 }, b = "y" },
    { a = { c = 50, d = 6 }, b = "y" },
    { a = { c = 60, d = 6 }, b = "y" },
  ]
}

assert "to_map_empty" {
  condition = macro::to_map([], _1) == {}
}
assert "to_map_nonempty_only_key_expr" {
  condition = macro::to_map(
    [
      { a = "x", b = 1, c = 10 },
      { a = "x", b = 2, c = 20 },
      { a = "y", b = 3, c = 30 },
    ],
    "${_1.a}|${_1.b}",
  ) == {
    "x|1" = { a = "x", b = 1, c = 10 },
    "x|2" = { a = "x", b = 2, c = 20 },
    "y|3" = { a = "y", b = 3, c = 30 },
  }
}
assert "to_map_nonempty_both_key_and_value_expr" {
  condition = macro::to_map([1, 2, 3], "key${_1}", _1 * 2) == {
    key1 = 2
    key2 = 4
    key3 = 6
  }
}

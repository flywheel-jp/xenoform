assert "map_empty" {
  condition = macro::map([], _1 * 2) == []
}
assert "map_nonempty" {
  condition = macro::map([1, 2, 3], _1 * 2) == [2, 4, 6]
}

assert "filter_empty" {
  condition = macro::filter([], _1 % 2 == 0) == []
}
assert "filter_nonempty" {
  condition = macro::filter([1, 2, 3, 4, 5], _1 % 2 == 0) == [2, 4]
}

assert "all_empty" {
  condition = macro::all([], _1 % 2 == 0) == true
}
assert "all_nonempty" {
  condition = macro::all([1, 2, 3], _1 % 2 == 0) == false
}

assert "any_empty" {
  condition = macro::any([], _1 % 2 == 0) == false
}
assert "any_nonempty" {
  condition = macro::any([1, 2, 3], _1 % 2 == 0) == true
}

assert "find_empty" {
  condition = macro::find([], _1 % 2 == 0) == null
}
assert "find_not_found" {
  condition = macro::find([1, 2, 3], _1 > 5) == null
}
assert "find_found" {
  condition = macro::find([1, 2, 3], _1 % 2 == 0) == 2
}

assert "find_index_empty" {
  condition = macro::find_index([], _1 % 2 == 0) == null
}
assert "find_index_not_found" {
  condition = macro::find_index([1, 2, 3], _1 > 5) == null
}
assert "find_index_found" {
  condition = macro::find_index([1, 2, 3], _1 % 2 == 0) == 1
}

assert "count_by_empty" {
  condition = macro::count_by([], _1 % 2 == 0) == 0
}
assert "count_by_nonempty" {
  condition = macro::count_by([1, 2, 3, 4, 5], _1 % 2 == 0) == 2
}

assert "sum_by_empty" {
  condition = macro::sum_by([], _1 % 3) == 0
}
assert "sum_by_nonempty" {
  condition = macro::sum_by([1, 2, 3, 4, 5], _1 % 3) == 6
}

assert "group_by_empty" {
  condition = macro::group_by([], _1 % 3) == {}
}
assert "group_by_nonempty" {
  condition = macro::group_by([1, 2, 3, 4, 5], _1 % 3) == { 0 = [3], 1 = [1, 4], 2 = [2, 5] }
}

assert "max_by_empty" {
  condition = macro::max_by([], _1 % 3) == null
}
assert "max_by_nonempty" {
  condition = macro::max_by([1, 2, 3], _1 % 3) == 2
}

assert "min_by_empty" {
  condition = macro::min_by([], _1 % 3) == null
}
assert "min_by_nonempty" {
  condition = macro::min_by([1, 2, 3], _1 % 3) == 3
}

assert "sort_by_empty" {
  condition = macro::sort_by([], -_1) == []
}
assert "sort_by_nonempty" {
  condition = macro::sort_by([{ a = "foo" }, { a = "bar", b = "b"}, { a = "baz", c = "c" }], _1.a) == [{ a = "bar", b = "b"}, { a = "baz", c = "c" }, { a = "foo" }]
}

assert "last_nonempty" {
  condition = macro::last([1, 2, 3]) == 3
}

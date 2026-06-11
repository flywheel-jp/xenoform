# Note on the doc comments below:
# We say "returns" for simplicity, but strictly speaking a macro doesn't return a value.
# "Returns ..." means "Converts an invocation of this macro into an expression that
# evaluates to ...".

#
# Macros for arrays
#

# Returns an array whose element is the result of invoking `f` on each element in `arr`.
# `f` must be an expression where `_1` is replaced with each element in `arr`.
macro "map" "arr" "f" {
  return = [for e in arr : macro::bind(f, e)]
}

# Returns an array with only those elements for which `f` evaluates to `true`.
# `f` must be a boolean expression where `_1` is replaced with each element in `arr`.
macro "filter" "arr" "f" {
  return = [for e in arr : e if macro::bind(f, e)]
}

# Returns a boolean value indicating that `f` evaluates to `true` for all elements in `arr`.
# `f` must be a boolean expression where `_1` is replaced with each element in `arr`.
macro "all" "arr" "f" {
  return = alltrue(macro::map(arr, f))
}

# Returns a boolean value indicating that `f` evaluates to `true` for any elements in `arr`.
# `f` must be a boolean expression where `_1` is replaced with each element in `arr`.
macro "any" "arr" "f" {
  return = anytrue(macro::map(arr, f))
}

# Returns an element in `arr` where `f` evaluates to `true`, or returns
# `default` if no element is found.
# `f` must be a boolean expression where `_1` is replaced with each element in `arr`.
# `default` can be omitted and defaults to `null`.
macro "find" "arr" "f" {
  return = macro::find(arr, null, f)
}
macro "find" "arr" "default" "f" {
  return = try(macro::filter(arr, f)[0], default)
}

# Returns an index of an element in `arr` where `f` evaluates to `true`, or returns
# `null` if no element is found.
# `f` must be a boolean expression where `_1` is replaced with each element in `arr`.
macro "find_index" "arr" "f" {
  return = try([for i, e in arr : i if macro::bind(f, e)][0], null)
}

# Returns a number of elements in `arr` where `f` evaluates to `true`.
# `f` must be a boolean expression where `_1` is replaced with each element in `arr`.
macro "count_by" "arr" "f" {
  return = length(macro::filter(arr, f))
}

# Returns a sum of numbers obtained by evaluating `f` with each element in `arr`.
# `f` must be a number expression where `_1` is replaced with each element in `arr`.
macro "sum_by" "arr" "f" {
  return = try(sum(macro::map(arr, f)), 0)
}

# Returns a map whose keys are results of evaluating `f` with each element, and
# values are arrays of elements belonging to the same key.
# `f` must be a string expression where `_1` is replaced with each element in `arr`.
macro "group_by" "arr" "f" {
  return = { for e in arr : macro::bind(f, e) => e... }
}

# Returns an element in `arr` for which `f` evaluates to the maximum value.
# `f` must be a number expression where `_1` is replaced with each element in `arr`.
macro "max_by" "arr" "f" {
  return = macro::max_by(arr, null, f)
}
macro "max_by" "arr" "default" "f" {
  return = try(macro::find(arr, macro::bind(f, _1) == max(macro::map(arr, f)...)), default)
}

# Returns an element in `arr` for which `f` evaluates to the minimum value.
# `f` must be a number expression where `_1` is replaced with each element in `arr`.
macro "min_by" "arr" "f" {
  return = macro::min_by(arr, null, f)
}
macro "min_by" "arr" "default" "f" {
  return = try(macro::find(arr, macro::bind(f, _1) == min(macro::map(arr, f)...)), default)
}

# Returns an array with the same elements in `arr` sorted with the evaluation of `f` with
# each element in `arr`.
# `f` must be a string expression where `_1` is replaced with each element in `arr`.
macro "sort_by" "arr" "f" {
  indices = { for i, e in arr : macro::bind(f, e) => i... }
  return = flatten([
    for k in sort(keys(indices)) : [
      for i in indices[k] : element(arr, i)
    ]
  ])
}

# Returns the last element in `arr`.
macro "last" "arr" {
  return = reverse(arr)[0]
}

#
# Macros for maps/objects
#

# Returns a map without `key`. If `key` does not exist in `map`, returns the given
# `map` without modification.
macro "delete_key" "map" "key" {
  return = { for k, v in map : k => v if k != key }
}

# Returns a map containing keys in both `map1` and `map2`. For a key that resides in both maps,
# `f` is evaluated with 3 arguments and the result becomes the value of the key.
# `f` is an expression where
# - `_1` is replaced with the duplicated key,
# - `_2` is replaced with the value in `map1`, and
# - `_3` is replaced with the value in `map2`.
# If you don't want to handle collisions, use the terraform builtin `merge()` function.
macro "merge_by" "map1" "map2" "f" {
  keys1 = keys(map1)
  keys2 = keys(map2)
  return = merge(
    { for k in setsubtract(keys1, keys2) : k => map1[k] },
    { for k in setsubtract(keys2, keys1) : k => map2[k] },
    { for k in setintersection(keys1, keys2) : k => macro::bind(f, k, map1[k], map2[k]) },
  )
}

# Returns an array of objects where sub-arrays in given objects are flattened.
# Each object in `arr` is expected to have `field` which must be a sub-array.
# In the objects in the returned array, `field` is replaced with each element
# in the sub-array.
#
# Example:
#   macro::flatten_objects2([
#     { a = [{ c = 1, d = 2 }, { c = 3, d = 4 }], b = "x" },
#     { a = [{ c = 5, d = 6 }], b = "y" },
#   ], "a")
#
#   is evaluated to
#
#   [
#     { a = { c = 1, d = 2 }, b = "x" },
#     { a = { c = 3, d = 4 }, b = "x" },
#     { a = { c = 5, d = 6 }, b = "y" },
#   ]
macro "flatten_objects2" "arr" "field" {
  return = flatten([
    for e1 in arr : [
      for e2 in e1[field] :
      merge(e1, { (field) = e2 })
    ]
  ])
}

# Returns an array of objects where sub-arrays and sub-sub-arrays in given objects
# are flattened. Each object in `arr` is expected to have `field1` which must be
# a sub-array of objects which is expected to have `field2` array. In the objects in the
# returned array, `field1` and `field1.field2` are replaced with elements in the sub-
# and sub-sub-arrays.
#
# Example:
#   macro::flatten_objects3(
#     [
#       { a = [{ c = [10, 20], d = 2 }, { c = [30], d = 4 }], b = "x" },
#       { a = [{ c = [40, 50, 60], d = 6 }], b = "y" },
#     ],
#     "a",
#     "c",
#   )
#
#   is evaluated to
#
#   [
#     { a = { c = 10, d = 2 }, b = "x" },
#     { a = { c = 20, d = 2 }, b = "x" },
#     { a = { c = 30, d = 4 }, b = "x" },
#     { a = { c = 40, d = 6 }, b = "y" },
#     { a = { c = 50, d = 6 }, b = "y" },
#     { a = { c = 60, d = 6 }, b = "y" },
#   ]
macro "flatten_objects3" "arr" "field1" "field2" {
  return = flatten([
    for e1 in arr : flatten([
      for e2 in e1[field1] : [
        for e3 in e2[field2] :
        merge(e1, { (field1) = merge(e2, { (field2) = e3 }) })
      ]
    ])
  ])
}

# Constructs a map from array by applying key generator expression and value generator
# expression from each element. Value generator expression is optional and by default
# each array element becomes the value.
#
# Example: to_map with key expression
#   macro::to_map(
#     [
#       { a = "x", b = 1, c = 10 },
#       { a = "x", b = 2, c = 20 },
#       { a = "y", b = 3, c = 30 },
#     ],
#     "${_1.a}|${_1.b}",
#   )
#
#   is evaluated to
#
#   {
#     "x|1" = { a = "x", b = 1, c = 10 },
#     "x|2" = { a = "x", b = 2, c = 20 },
#     "y|3" = { a = "y", b = 3, c = 30 },
#   }
#
# Example: to_map with both key and value expressions
#   macro::to_map(
#     [1, 2, 3],
#     "key${_1}",
#     _1 * 2,
#   )
#
#   is evaluated to
#
#   {
#     key1 = 2
#     key2 = 4
#     key3 = 6
#   }
macro "to_map" "arr" "key_expr" {
  return = macro::to_map(arr, key_expr, _1)
}
macro "to_map" "arr" "key_expr" "value_expr" {
  return = {
    for e in arr : macro::bind(key_expr, e) => macro::bind(value_expr, e)
  }
}

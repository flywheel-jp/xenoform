
locals {
  use_bind = (( 10) + ( 20))

  use_map_with_pipeline = (( [for e in ((( [for e in ((
    [1, 2, 3])) : (( ( e) + 1))]))) : (( ( e) * 2))]))
}


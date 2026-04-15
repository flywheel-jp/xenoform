
locals {
  # tflint-ignore: terraform_unused_declarations
  assert_same_name_different_arity_simulate_default_arg = ( (( ((2)) + ( 1))) == 3) ? "ASSERTION OK: simulate_default_arg" : tobool("ASSERTION FAILED: simulate_default_arg in file 'same_name_different_arity': condition=${ (( ((2)) + ( 1))) == 3 }")
}

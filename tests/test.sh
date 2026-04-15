#!/usr/bin/env bash
set -euo pipefail -o posix

: "${XENOFORM_BIN:?}"

"${XENOFORM_BIN}" -h | grep '^Usage: ' >/dev/null
"${XENOFORM_BIN}" --help | grep '^Usage: ' >/dev/null

function find_expected_output_path() {
  # Assuming that given arguments contain exactly 1 input .in.tf file
  while [[ "$#" -gt 0 ]]; do
    if [[ "$1" = '--macro-prelude' ]]; then
      shift 2
    else
      echo "${1/%.in.tf/.tf}"
      return
    fi
  done
}

function success() {
  local out
  out=$("${XENOFORM_BIN}" "$@")
  local expected
  expected=$(cat "$(find_expected_output_path "$@")")
  if [[ "${out}" != "${expected}" ]]; then
    echo 'Unexpected output. Diff:'
    echo '----------'
    diff <(echo "${out}") <(echo "${expected}")
    echo '----------'
    exit 1
  fi
}

success --macro-prelude "$(dirname "$0")/success/macro_prelude1.in.tf" --macro-prelude "$(dirname "$0")/success/macro_prelude2.in.tf" "$(dirname "$0")/success/all_features.in.tf"
success --macro-prelude "$(dirname "$0")/success/macro_prelude1.in.tf" "$(dirname "$0")/success/all_features.in.tf" --macro-prelude "$(dirname "$0")/success/macro_prelude2.in.tf"
success "$(dirname "$0")/success/all_features.in.tf" --macro-prelude "$(dirname "$0")/success/macro_prelude1.in.tf" --macro-prelude "$(dirname "$0")/success/macro_prelude2.in.tf"
success "$(dirname "$0")/success/macro/macro_within_traversal.in.tf"
success "$(dirname "$0")/success/macro/same_name_different_arity.in.tf"

function error() {
  local expected_exit_code="$1"
  local expected_error_message="$2"
  shift 2
  local code=0
  local out
  out=$("${XENOFORM_BIN}" "$@" 2>&1) || code="$?"
  if [[ "${code}" -ne "${expected_exit_code}" ]]; then
    echo "Unexpected exit status ${code} for error case '$*'. Expected: ${expected_exit_code}"
    exit 1
  fi
  if ! [[ "${out}" =~ ${expected_error_message} ]]; then
    echo "Unexpected error message '${out}' for error case '$*'. Expected: ${expected_error_message}"
    exit 1
  fi
}

error 2 '^error: the following required arguments were not provided:.*'
error 2 "^error: unexpected argument 'input2.in.tf' found.*" input1.in.tf input2.in.tf
error 2 "^error: a value is required for '--macro-prelude <FILE>' but none was supplied.*" '--macro-prelude'
error 1 '^Failed to read .*$' "$(dirname "$0")/error/nonexisting_file.in.tf"
error 1 '^Failed to parse .* as HCL2\.$' "$(dirname "$0")/error/non_hcl2.in.tf"
error 1 '^Failed to parse .*$' "$(dirname "$0")/error/blocal_duplicated_entries.in.tf" # This results in a parsing error instead of error in our code
error 1 "^'blocal\.x' not present in blocals block\.$" "$(dirname "$0")/error/blocal_different_block.in.tf"
error 1 "^Too many expansions of blocal 'x'\.$" "$(dirname "$0")/error/blocal_self_recursive.in.tf"
error 1 "^Too many expansions of blocal 'x'\.$" "$(dirname "$0")/error/blocal_mutual_recursive.in.tf"
error 1 "^'macro' block without name label is invalid\.$" "$(dirname "$0")/error/macro_no_label.in.tf"
error 1 "^Last attribute of macro 'no_return' must be 'return = \.\.\.'\.$" "$(dirname "$0")/error/macro_no_return_attribute.in.tf"
error 1 '^Failed to read .* \(included from .*\)\.$' "$(dirname "$0")/error/macro_nonexisting_include.in.tf"
error 1 '^Failed to parse .* as HCL2 \(included from .*\)\.$' "$(dirname "$0")/error/macro_include_non_hcl2.in.tf"
error 1 "^'macro_include' block in .* must have exactly one attribute named 'source'\.$" "$(dirname "$0")/error/macro_include_no_source_attribute.in.tf"
error 1 "^'macro_include' block in .* must have exactly one attribute named 'source'\.$" "$(dirname "$0")/error/macro_include_extra_attribute.in.tf"
error 1 "^Only literal string is allowed for 'source' attribute value\.$" "$(dirname "$0")/error/macro_include_dynamic_source_value.in.tf"
error 1 "^.* is included multiple times within ".*"\.$" "$(dirname "$0")/error/macro_include_same_file_multiple_times.in.tf"
error 1 "^Macro named 'bar' with arity '1' not found\.$" "$(dirname "$0")/error/macro_nonexisting_name.in.tf"
error 1 "^Macro named 'foo' with arity '2' not found\.$" "$(dirname "$0")/error/macro_different_number_of_args.in.tf"
error 1 "^Duplicate macro blocks with name 'same_name_used_twice' and arity '1' found in this compilation unit\.$" "$(dirname "$0")/error/macro_multiple_macros_with_same_name_arity.in.tf"
error 1 "^Too many expansions of macro 'recursive'\.$" "$(dirname "$0")/error/macro_self_recursive.in.tf"
error 1 "^Too many expansions of macro 'recursive1'\.$" "$(dirname "$0")/error/macro_mutual_recursive.in.tf"
error 1 "^No argument is passed to 'macro::pipeline\(\)'\.$" "$(dirname "$0")/error/macro_empty_pipeline.in.tf"
error 1 "^'pipeline' macro is reserved and cannot be defined\.$" "$(dirname "$0")/error/macro_redefine_pipeline.in.tf"
error 1 '^Failed to read .* \(given as a macro prelude\)\.$' '--macro-prelude' "$(dirname "$0")/error/nonexisting_file.in.tf" "$(dirname "$0")/success/all_features.in.tf"
error 1 '^Failed to parse .* as HCL2 \(given as a macro prelude\)\.$' '--macro-prelude' "$(dirname "$0")/error/non_hcl2.in.tf" "$(dirname "$0")/success/all_features.in.tf"
error 1 "^Exactly 1 label is expected for 'assert' block\.$" "$(dirname "$0")/error/assert_too_many_labels.in.tf"
error 1 "^Attribute 'condition' must be given to 'assert' block\.$" "$(dirname "$0")/error/assert_missing_condition_attribute.in.tf"

echo 'Succesfully finished all tests.'

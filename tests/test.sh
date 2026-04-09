#!/usr/bin/env bash
set -euo pipefail -o posix

: "${XENOFORM_BIN:?}"

function success() {
  local path="${@: -1}"
  local out
  out=$("${XENOFORM_BIN}" "$@")
  local expected
  expected=$(cat "${path/%.in.tf/.tf}")
  if [[ "${out}" != "${expected}" ]]; then
    echo 'Unexpected output. Diff:'
    echo '----------'
    diff <(echo "${out}") <(echo "${expected}")
    echo '----------'
    exit 1
  fi
}

success \
  --macro-prelude "$(dirname "$0")/success/macro_prelude1.in.tf" \
  --macro-prelude "$(dirname "$0")/success/macro_prelude2.in.tf" \
  "$(dirname "$0")/success/all_features.in.tf"
success "$(dirname "$0")/success/macro_expansion/macro_within_traversal.in.tf"

function error() {
  local expected_error_message="$1"
  shift
  local code=0
  local out
  out=$("${XENOFORM_BIN}" "$@" 2>&1) || code="$?"
  if [[ "${code}" -ne 1 ]]; then
    echo "Unexpected exit status ${code} for error case '$*'"
    exit 1
  fi
  if ! [[ "${out}" =~ ${expected_error_message} ]]; then
    echo "Unexpected error message '${out}' for error case '$*'. Expected: ${expected_error_message}"
    exit 1
  fi
}

error '^Filename argument required\.$'
error '^Failed to read .*$' "$(dirname "$0")/error/nonexisting_file.in.tf"
error '^Failed to parse .* as HCL2\.$' "$(dirname "$0")/error/non_hcl2.in.tf"
error '^Failed to parse .*$' "$(dirname "$0")/error/blocal_duplicated_entries.in.tf" # This results in a parsing error instead of error in our code
error "^'blocal\.x' not present in blocals block\.$" "$(dirname "$0")/error/blocal_different_block.in.tf"
error "^Too many expansions of blocal 'x'\.$" "$(dirname "$0")/error/blocal_self_recursive.in.tf"
error "^Too many expansions of blocal 'x'\.$" "$(dirname "$0")/error/blocal_mutual_recursive.in.tf"
error "^'macro' block without name label is invalid\.$" "$(dirname "$0")/error/macro_no_label.in.tf"
error "^Last attribute of macro 'no_return' must be 'return = \.\.\.'\.$" "$(dirname "$0")/error/macro_no_return_attribute.in.tf"
error '^Failed to read .* \(included from .*\)\.$' "$(dirname "$0")/error/macro_nonexisting_include.in.tf"
error '^Failed to parse .* as HCL2 \(included from .*\)\.$' "$(dirname "$0")/error/macro_include_non_hcl2.in.tf"
error "^'macro_include' block in .* must have exactly one attribute named 'source'\.$" "$(dirname "$0")/error/macro_include_no_source_attribute.in.tf"
error "^'macro_include' block in .* must have exactly one attribute named 'source'\.$" "$(dirname "$0")/error/macro_include_extra_attribute.in.tf"
error "^Only literal string is allowed for 'source' attribute value\.$" "$(dirname "$0")/error/macro_include_dynamic_source_value.in.tf"
error "^.* is included multiple times within ".*"\.$" "$(dirname "$0")/error/macro_include_same_file_multiple_times.in.tf"
error "^Macro named 'bar' not found\.$" "$(dirname "$0")/error/macro_nonexisting_name.in.tf"
error "^Multiple macros with the same name 'same_name_used_twice' found in this compilation unit\.$" "$(dirname "$0")/error/macro_multiple_macros_with_the_same_name.in.tf"
error "^Number of args passed to macro 'foo' must be '1'\.$" "$(dirname "$0")/error/macro_different_number_of_args.in.tf"
error "^Too many expansions of macro 'recursive'\.$" "$(dirname "$0")/error/macro_self_recursive.in.tf"
error "^Too many expansions of macro 'recursive1'\.$" "$(dirname "$0")/error/macro_mutual_recursive.in.tf"
error "^No argument is passed to 'macro::pipeline\(\)'\.$" "$(dirname "$0")/error/macro_empty_pipeline.in.tf"
error "^'pipeline' macro is reserved and cannot be defined\.$" "$(dirname "$0")/error/macro_redefine_pipeline.in.tf"
error "^No filename argument given after '--macro-prelude'\.$" '--macro-prelude'
error '^Failed to read .* \(given as a macro prelude\)\.$' '--macro-prelude' "$(dirname "$0")/error/nonexisting_file.in.tf" "$(dirname "$0")/success/all_features.in.tf"
error '^Failed to parse .* as HCL2 \(given as a macro prelude\)\.$' '--macro-prelude' "$(dirname "$0")/error/non_hcl2.in.tf" "$(dirname "$0")/success/all_features.in.tf"
error "^Exactly 1 label is expected for 'assert' block\.$" "$(dirname "$0")/error/assert_too_many_labels.in.tf"
error "^Attribute 'condition' must be given to 'assert' block\.$" "$(dirname "$0")/error/assert_missing_condition_attribute.in.tf"

echo 'Succesfully finished all tests.'

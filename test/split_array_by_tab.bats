# SPDX-License-Identifier: GPL-3.0-or-later

setup_file () {
  load 'test_helper/common-setup'
  _common_setup
}

setup () {
  load 'test_helper/bats-assert/load'
  load 'test_helper/bats-support/load'
}

@test "split_array_by_tab() - generic" {
  source "${PROJECT_ROOT}/src/functions.sh"

  UNIT_TESTS="true"

  run split_array_by_tab
  assert_failure 1

  run split_array_by_tab "array"
  assert_failure 1

  run split_array_by_tab "array" "array1"
  assert_failure 1

  changed_scripts_base=()
  changed_scripts_head=()
  tab=$'\t'
  run split_array_by_tab "changed_scripts_base" "changed_scripts_head" "old${tab}new" "old${tab}new_old" "old${tab}old"
  assert_success
  assert_output "old old old
new new_old old"
}

teardown () {
  export \
    changed_scripts_base="" \
    changed_scripts_head="" \
    UNIT_TESTS=""
}

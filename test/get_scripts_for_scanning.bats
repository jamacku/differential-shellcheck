# SPDX-License-Identifier: GPL-3.0-or-later

setup_file () {
  load 'test_helper/common-setup'
  _common_setup
}

setup () {
  load 'test_helper/bats-assert/load'
  load 'test_helper/bats-support/load'
}

@test "get_scripts_for_scanning() - full scan" {
  source "${PROJECT_ROOT}/src/functions.sh"

  UNIT_TESTS="true"

  run get_scripts_for_scanning
  assert_failure 1

  run get_scripts_for_scanning "path"
  assert_failure 1

  shell_scripts=()
  run get_scripts_for_scanning "./test/fixtures/get_scripts_for_scanning/files.txt" "shell_scripts" "0"
  assert_success
  assert_output --partial "'./test/fixtures/get_scripts_for_scanning/script1.sh' './test/fixtures/get_scripts_for_scanning/script2' './test/fixtures/get_scripts_for_scanning/script 2.sh' './test/fixtures/get_scripts_for_scanning/script&3.sh' './test/fixtures/get_scripts_for_scanning/\$script4.sh'"
}

@test "get_scripts_for_scanning() - diff scan" {
  source "${PROJECT_ROOT}/src/functions.sh"

  UNIT_TESTS="true"

  run get_scripts_for_scanning
  assert_failure 1

  run get_scripts_for_scanning "path"
  assert_failure 1

  shell_scripts=()
  run get_scripts_for_scanning "./test/fixtures/get_scripts_for_scanning/files_diff.txt" "shell_scripts" "1"
  assert_success
  assert_output --partial "$'./test/fixtures/get_scripts_for_scanning/script1.sh\t./test/fixtures/get_scripts_for_scanning/script1.sh' $'./test/fixtures/get_scripts_for_scanning/script2\t./test/fixtures/get_scripts_for_scanning/script1.sh' $'./test/fixtures/get_scripts_for_scanning/script 2.sh\t./test/fixtures/get_scripts_for_scanning/script 2.sh' $'./test/fixtures/get_scripts_for_scanning/script&3.sh\t./test/fixtures/get_scripts_for_scanning/\$script4.sh' $'./test/fixtures/get_scripts_for_scanning/\$script4.sh\t./test/fixtures/get_scripts_for_scanning/\$script4.sh'"
}

teardown () {
  export \
    shell_scripts="" \
    UNIT_TESTS=""
}

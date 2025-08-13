#!/usr/bin/env bash
set -Eeu

MY_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${MY_DIR}/lib.sh"

test_new_org_secret_with_secret_txt_file()             { assert_secrets "${FUNCNAME}"; }
test_new_org_secret_with_no_matching_secret_txt_file() { assert_secrets "${FUNCNAME}"; }
test_new_repo_secret_with_no_secret_txt_file()         { assert_secrets "${FUNCNAME}"; }
test_new_repo_secret_with_matching_secret_txt_file()   { assert_secrets "${FUNCNAME}"; }
test_two_identical_repo_secrets()                      { assert_secrets "${FUNCNAME}"; }
test_secret_with_expire_never()                        { assert_secrets "${FUNCNAME}"; }
test_repo_txt_file_has_no_corresponding_gh_secret()    { assert_secrets "${FUNCNAME}"; }
test_org_txt_file_has_no_corresponding_gh_secret()     { assert_secrets "${FUNCNAME}"; }
test_same_secret_twice_in_api_once_in_txt_files()      { assert_secrets "${FUNCNAME}"; }
test_10_days_since_update()                            { assert_secrets "${FUNCNAME}"; }
test_335_days_since_update()                           { assert_secrets "${FUNCNAME}"; }
test_ignore_kosli_reporter_sources()                   { assert_secrets "${FUNCNAME}"; }
test_non_secret_is_ignored()                           { assert_secrets "${FUNCNAME}"; }

assert_secrets()
{
  local -r func="${1}"
  local -r test_root="${MY_DIR}/${func:5}"
  local -r expected_blended="${test_root}/expected.blended.json"
  local -r expected_filtered="${test_root}/expected.filtered.json"
  local -r expected_summary="${test_root}/expected.summary.txt"
  local -r expected_filtered_plus="${test_root}/expected.filtered.plus.json"
  local -r expected_summary_plus="${test_root}/expected.summary.plus.txt"

  # - - - - - - - - - - - - - - - - - - -

  "${MY_DIR}/../bin/blend_secrets.py" "${test_root}/api_secrets.json" "${test_root}/txt_root" "2025-07-22" \
    >"${stdoutF}" 2>"${stderrF}"

  assertEquals "line:${LINENO}" 0 $?
  assertStdoutEquals "line:${LINENO}" "$(cat "${expected_blended}")"
  assertStderrEmpty "line:${LINENO}"

  # - - - - - - - - - - - - - - - - - - -

  "${MY_DIR}/../bin/filter_secrets.py" "${expected_blended}" \
    >"${stdoutF}" 2>"${stderrF}"

  assertEquals "line:${LINENO}" 0 $?
  assertStdoutEquals "line:${LINENO}" "$(cat "${expected_filtered}")"
  assertStderrEmpty "line:${LINENO}"

  # - - - - - - - - - - - - - - - - - - -

  "${MY_DIR}/../bin/print_filtered_secrets_summary.py" "${expected_filtered}" \
    >"${stdoutF}" 2>"${stderrF}"

  assertEquals "line:${LINENO}" 0 $?
  assertStdoutEquals "line:${LINENO}" "$(cat "${expected_summary}")"
  assertStderrEmpty "line:${LINENO}"

  # - - - - - - - - - - - - - - - - - - -

  "${MY_DIR}/../bin/filter_secrets.py" "${expected_blended}" "${test_root}/repos_root" \
    >"${stdoutF}" 2>"${stderrF}"

  assertEquals "line:${LINENO}" 0 $?
  assertStdoutEquals "line:${LINENO}" "$(cat "${expected_filtered_plus}")"
  assertStderrEmpty "line:${LINENO}"

  # - - - - - - - - - - - - - - - - - - -

  "${MY_DIR}/../bin/print_filtered_secrets_summary.py" "${expected_filtered_plus}" \
    >"${stdoutF}" 2>"${stderrF}"

  assertEquals "line:${LINENO}" 0 $?
  assertStdoutEquals "line:${LINENO}" "$(cat "${expected_summary_plus}")"
  assertStderrEmpty "line:${LINENO}"
}

# Load shUnit2.
source "${MY_DIR}/shunit2"

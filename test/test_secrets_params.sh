#!/usr/bin/env bash
set -Eeu

MY_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${MY_DIR}/lib.sh"

readonly FILTER="${MY_DIR}/../bin/filter_secrets.py"
readonly FIXTURES="${MY_DIR}/params_fixtures"
readonly BLENDED="${FIXTURES}/blended.json"

# A params file whose required threshold keys are misspelled must fail with a
# clear message that names both the offending file and the missing key (not a
# bare KeyError). rotation_days is checked first, so it is the one reported.
test_misspelled_key_in_params_file_is_a_clear_error()
{
  local status=0
  "${FILTER}" "${BLENDED}" "${FIXTURES}/misspelled_keys.json" \
    >"${stdoutF}" 2>"${stderrF}" || status=$?

  assertEquals "line:${LINENO}" 1 "${status}"
  assertStdoutEmpty "line:${LINENO}"

  local found_message=0
  grep -q "does not contain the required key 'rotation_days'" "${stderrF}" && found_message=1
  assertEquals "line:${LINENO}" 1 "${found_message}"

  local names_file=0
  grep -q "misspelled_keys.json" "${stderrF}" && names_file=1
  assertEquals "line:${LINENO}" 1 "${names_file}"
}

# A params file whose attestation-name key is misspelled must fail with a clear
# message naming the file and the missing key. filter_secrets.py does not use
# this value, but load_params validates the full shared-params contract so a
# misconfigured file is caught rather than silently accepted.
test_misspelled_attestation_name_in_params_file_is_a_clear_error()
{
  local status=0
  "${FILTER}" "${BLENDED}" "${FIXTURES}/misspelled_attestation_name.json" \
    >"${stdoutF}" 2>"${stderrF}" || status=$?

  assertEquals "line:${LINENO}" 1 "${status}"
  assertStdoutEmpty "line:${LINENO}"

  local found_message=0
  grep -q "does not contain the required key 'attestation_name'" "${stderrF}" && found_message=1
  assertEquals "line:${LINENO}" 1 "${found_message}"

  local names_file=0
  grep -q "misspelled_attestation_name.json" "${stderrF}" && names_file=1
  assertEquals "line:${LINENO}" 1 "${names_file}"
}

# A params file that is not valid JSON must fail with a clear message that names
# the offending file (not a bare JSONDecodeError).
test_malformed_params_file_is_a_clear_error()
{
  local status=0
  "${FILTER}" "${BLENDED}" "${FIXTURES}/malformed.json" \
    >"${stdoutF}" 2>"${stderrF}" || status=$?

  assertEquals "line:${LINENO}" 1 "${status}"
  assertStdoutEmpty "line:${LINENO}"

  local found_message=0
  grep -q "is not valid JSON" "${stderrF}" && found_message=1
  assertEquals "line:${LINENO}" 1 "${found_message}"

  local names_file=0
  grep -q "malformed.json" "${stderrF}" && names_file=1
  assertEquals "line:${LINENO}" 1 "${names_file}"
}

# Load shUnit2.
source "${MY_DIR}/shunit2"

#!/usr/bin/env bash
set -Eeu

MY_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${MY_DIR}/lib.sh"

readonly POLICY="${MY_DIR}/../policies/secrets.rego"
readonly PARAMS="${MY_DIR}/../policies/secrets-params.json"

setUp()
{
  # The policy tests drive the kosli CLI (it embeds the OPA/Rego engine).
  # The CLI is only installed on the main branch in CI, so skip elsewhere
  # rather than fail on branch pushes.
  if ! installed kosli; then
    startSkipping
  fi
}

# Evaluate policies/secrets.rego against a local JSON fixture (no API calls)
# and leave the normalised {allow, violations} verdict in stdoutF.
evaluate_input()
{
  local -r input_file="${1}"
  kosli evaluate input \
    --input-file "${input_file}" \
    --policy "${POLICY}" \
    --params "@${PARAMS}" \
    --no-assert \
    --output json 2>"${stderrF}" | jq -S '{allow, violations}' >"${stdoutF}"
}

# A trail whose blended-secrets attestation was never reported must be DENIED
# (not silently allowed), with a diagnostic naming the missing attestation.
# Guards the Rego "positive assertion" structure against a regression back to
# the unsafe `allow if count(violations) == 0` false-positive.
test_missing_blended_secrets_attestation_is_denied()
{
  local -r test_root="${MY_DIR}/policy_blended_secrets_missing"
  evaluate_input "${test_root}/input.json"
  assertStdoutEquals "line:${LINENO}" "$(cat "${test_root}/expected.eval.json")"
  assertStderrEmpty "line:${LINENO}"
}

# Companion positive case: when the attestation is present and every secret is
# well-managed (both files, outside both alert windows) the trail is ALLOWED.
# The non-secret entry has deliberately bad dates to prove is_secret==false is
# ignored. Ensures the deny test above cannot pass for the wrong reason.
test_present_and_compliant_attestation_is_allowed()
{
  local -r test_root="${MY_DIR}/policy_blended_secrets_present_compliant"
  evaluate_input "${test_root}/input.json"
  assertStdoutEquals "line:${LINENO}" "$(cat "${test_root}/expected.eval.json")"
  assertStderrEmpty "line:${LINENO}"
}

# Load shUnit2.
source "${MY_DIR}/shunit2"

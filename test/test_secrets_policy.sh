#!/usr/bin/env bash
set -Eeu

MY_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${MY_DIR}/lib.sh"
# Defines _opa, and W, the prefix a path given to _opa must carry.
source "${MY_DIR}/../bin/lib-opa.sh"

readonly POLICY="${W}/policies/secrets.rego"
# Pinned thresholds so test outcomes do not change when the production
# thresholds in policies/secrets-params.json are tuned.
readonly PARAMS="${MY_DIR}/secrets-params.json"

# Evaluate policies/secrets.rego against a local JSON fixture with `opa eval`
# (no API calls) and leave the normalised {allow, violations} verdict in
# stdoutF. The params go in the query rather than a file, so a Docker opa
# needs no mount but the repo.
evaluate_input()
{
  local -r input_file="${1}"
  _opa eval --stdin-input --format raw \
    --data "${POLICY}" \
    "{\"allow\": data.policy.allow, \"violations\": data.policy.violations} with data.params as $(cat "${PARAMS}")" \
    <"${input_file}" 2>"${stderrF}" | jq -S '.' >"${stdoutF}"
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

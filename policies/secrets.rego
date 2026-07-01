# Policy for the cyber-dojo "secrets" flow (control SDLC-CTRL-0014).
#
# Evaluates the `blended-secrets` custom attestation produced by
# bin/blend_secrets.py and flags any secret that needs attention, mirroring
# the logic in bin/filter_secrets.py. A trail is compliant only when the
# attestation data is present AND every secret is positively verified as fine.
#
# Structured per the Kosli guidance on avoiding false positives
# (https://docs.kosli.com/tutorials/evaluate_trails_with_opa):
#   1. Fail-safe default: `default allow := false`.
#   2. Drive `allow` via a POSITIVE assertion, not the absence of violations.
#      If the attestation is missing/renamed, `secrets` is undefined, the
#      positive assertion fails to evaluate, and `allow` stays false.
#   3. `violations` are diagnostics only; they explain a denial, they do not
#      decide it.
#
# Parameters (passed via `kosli evaluate trail --params`, read as data.params):
#   attestation_name   - name of the custom attestation carrying the blended data
#   rotation_days      - a github secret should be rotated within this many days
#   alert_window_days  - warn this many days before expiry / before rotation is due
package policy

import rego.v1

attestation_name := data.params.attestation_name

# The array of per-secret objects from the blended-secrets attestation.
secrets := input.trail.compliance_status.attestations_statuses[attestation_name].attestation_data

default allow := false

# Positive assertion: the attestation data must exist AND every secret must be
# individually verified as needing no attention. If `secrets` is undefined
# (missing/renamed attestation), `is_array` fails and `allow` stays false.
allow if {
	is_array(secrets)
	every s in secrets {
		secret_is_fine(s)
	}
}

# A non-secret needs no attention.
secret_is_fine(s) if {
	s.is_secret == false
}

# A secret is fine only when it is positively in a well-managed state:
# it has both a .txt file and a github secret, is not within the expiry alert
# window, and is not within the rotation alert window.
secret_is_fine(s) if {
	s.is_secret == true
	s.has_txt_file == true
	s.has_github_secret == true
	s.days_to_expiry > data.params.alert_window_days
	s.days_since_update < (data.params.rotation_days - data.params.alert_window_days)
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# violations: diagnostics only (they explain a denial, they do not decide it).

# The named attestation is missing from the trail.
violations contains msg if {
	not input.trail.compliance_status.attestations_statuses[attestation_name]
	msg := sprintf("attestation '%s' is missing from the trail", [attestation_name])
}

# A github secret with no matching .txt file.
violations contains msg if {
	some s in secrets
	s.is_secret == true
	s.has_github_secret == true
	s.has_txt_file == false
	msg := sprintf("No .txt file: %s/%s/%s", [s.scope, s.repo, s.name])
}

# A .txt file with no matching github secret.
violations contains msg if {
	some s in secrets
	s.is_secret == true
	s.has_txt_file == true
	s.has_github_secret == false
	msg := sprintf("No GitHub secret: %s/%s/%s", [s.scope, s.repo, s.name])
}

# Expiring within the alert window.
violations contains msg if {
	some s in secrets
	s.is_secret == true
	s.days_to_expiry <= data.params.alert_window_days
	msg := sprintf("Expiring soon (in %d days): %s/%s/%s", [s.days_to_expiry, s.scope, s.repo, s.name])
}

# A github secret aging past its rotation window.
violations contains msg if {
	some s in secrets
	s.is_secret == true
	s.has_github_secret == true
	s.days_since_update >= (data.params.rotation_days - data.params.alert_window_days)
	msg := sprintf("Rotation due (%d days since update): %s/%s/%s", [s.days_since_update, s.scope, s.repo, s.name])
}

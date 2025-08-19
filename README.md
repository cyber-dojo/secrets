# Overview

This repository handles rotation of GitHub secrets.

The GitHub secrets API provides information on when each secret was last *updated* in GitHub.
The secret in GitHub might be an api-token (to some service) and it never expires. 
Such a secret must still be updated at least annually.

Each [.txt file](https://github.com/cyber-dojo/secrets/tree/main/docs#secrets-scope-and-txt-filenames) in the `txt_root/` sub-dirs provides information about a secret; its *expiry* date, and how to update it.

The file [.github/workflows/check-secrets.yml](.github/workflows/check-secrets.yml) is a daily cronjob workflow that:
- Combines data from the GitHub Secrets API and the .txt files.
- Finds secrets in all repos that:
   - Are within 30 days of their required annual rotation, or  
   - Are within 30 days of expiring, or
   - Are known GitHub secrets but don't have a corresponding .txt file, or
   - Have a .txt file but are not a GitHub secret
- Generates a report of secrets that need attention in the workflow-run step-summary
   - Includes a link to the docs/README.md file containing detailed instructions
- Sends a Slack message to the #cyber-dojo-alerts channel for team visibility
   - Includes a link to the workflow-run
- Makes attestations to the [secrets](https://app.kosli.com/cyber-dojo/flows/secrets/trails/) Flow in the `cyber-dojo` Kosli org.
   - Uses a custom-attestation-type. See [workflow](.github/workflows/create-custom-attestation.yml)
     and [schema](docs/custom-attestation-type-schema.json).
   - Secrets are non-compliant in their Trail if they are within 7 days of their required annual rotation,
     or within 7 days of expiring.


# The Workflow

The `check-secrets.yml` workflow uses three python scripts.

## 1. `bin/blend_secrets.py`

Blends data from the GitHub Secrets API and the secrets .txt files into a JSON file in this format:

```json
[
  {
    "days_since_update": 10,
    "days_to_expiry": 26826,
    "expires_at": "2099-01-01",
    "has_github_secret": true,
    "has_txt_file": false,
    "is_secret": true,
    "name": "THIS_IS_A_NEW_SECRET",
    "repo": "secrets",
    "scope": "org", 
    "txt_filename": "repos/secrets/gh-org-this-is-a-new-secret.txt",
    "updated_at": "2024-08-21"
  }
]
```

## 2. `bin/filter_secrets.py`

Takes the output of `blend_secrets.py` as an argument and filters out only those needing attention.
This program has two hard-wired constants:
- ROTATION_DAYS = 365, how often GitHub secret must be updated 
- ALERT_WINDOW_DAYS = 30, see above

## 3. `bin/print_filtered_secrets_summary.py`

Takes the output of `filter_secrets.py` and prints each secret needing attention in a simple Markdown format.

For each secret, a count is printed of the number of times the secret
occurs (lexically) in any file under the `.github/workflows/` dir of the secret's repo.

Note: A count of zero typically indicates:
- the secret is dead, or 
- the .txt file has the [wrong scope](https://github.com/cyber-dojo/secrets/blob/main/docs/README.md) 

**Example Output:**

```txt
1. Secret without a .txt file
   - secret name = KOSLI_API_TOKEN_MEEKROSOFT
   - scope = org
   - repo = secrets
   - suggested filename = txt_root/secrets/gh-org-kosli-api-token-meekrosoft.txt
   - occurrences in repo workflows = 0   

2. Secret with only a .txt file
   - secret name = KOSLI_API_TOKEN_HELLO
   - scope = org
   - repo = secrets
   - see file txt_root/secrets/gh-org-kosli-api-token-hello.txt
   - occurrences in repo workflows = 2   

3. Secret will soon expire
   - secret name = KOSLI_API_TOKEN_STAGING
   - scope = repo
   - repo = cli
   - expires in 6 days
   - see file txt_root/cli/gh-repo-kosli-api-token-staging.txt
   - occurrences in repo workflows = 4   
   
4. Secret will soon need updating
   - secret name = KOSLI_API_TOKEN
   - scope = repo
   - repo = ks8configdump
   - update due in 9 days
   - see file txt_root/ks8configdump/gh-repo-kosli-api-token.txt
   - occurrences in repo workflows = 2
```

# Testing

- See the `test/test_secrets.sh` file.
- To run the tests:
   ```bash
   make test_secrets
   ```

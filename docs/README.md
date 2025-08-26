# Action items come in 4 different forms

### [Secret with no .txt file](#secret-with-notxt-file)
### [Secret with only a .txt file](#secret-with-only-a-txt-file-1)
### [Secret will soon need updating](#secret-will-soon-need-updating-1)
### [Secret will soon expire](#secret-will-soon-expire-1)


## Secret with no.txt File
Eg
```
... Secret with no .txt file
    - secret name = SNAFU
    - scope = repo
    - repo = cli
    - suggested filename = txt_root/cli/gh-repo-snafu.txt
    - occurrences in repo workflows = 2
```
The given secret:
- Was returned from the GitHub secrets API
- *Does not have an .txt file*

You must either:
- Create a `txt_root/{REPO_NAME}/gh-repo-{SECRET_NAME}.txt` file (see below), for a Repo-scope secret, or
- Create a `txt_root/server/gh-org-{SECRET_NAME}.txt` file (see below), for an Org-scope secret, or
- Fix an incorrectly scoped .txt file (see below), or
- Delete the GitHub secret (if the secret is unused), or
- Archive the repo (if the repo is unused)


## Secret with only a .txt file
Eg
```
... Secret with only a .txt file 
    - secret name = WIBBLE
    - scope = repo
    - repo = waveapp
    - see file txt_root/waveapp/gh-repo-wibble.txt
    - occurrences in repo workflows = 4    
```
The given secret:
- Has a .txt file
- *Was not returned from the GitHub secrets API*

You must either:
- Create the secret in GitHub (with matching scope; see below)
- Fix an incorrectly scoped .txt file (see below), or
- Delete the .txt file (if the secret is unused), or


## Secret will soon need updating
Eg
```
... Secret will soon need updating
   - repo = ks8configdump
   - scope = repo
   - secret name = KOSLI_API_TOKEN
   - update due in 30 days
   - see file txt_root/ks8configdump/gh-repo-kosli-api-token.txt
   - occurrences in repo workflows = 2
```
The given secret:
- Was returned from the GitHub secrets API
- Has a .txt file
- *Will be 365 days old soon (as determined from the "updated_at" field in the GitHub secret API response)*

You must either:
- Generate a new secret - see instructions in its .txt file, update the line `secret-expire:`, 
update the secret in GitHub, or
- Delete both the GitHub secret and the .txt file (if the secret is unused), or
- Archive the repo (if the repo is unused)


## Secret will soon expire
Eg
```
... Secret will soon expire
    - secret name = LIST_ORG_AND_REPO_SECRETS
    - scope = repo
    - repo = opa-examples
    - will expire in 8 days
    - see file txt_root/opa-examples/gh-repo-list-org-and-repo-secrets.txt
    - occurrences in repo workflows = 2    
```
The given secret:
- Was returned from the GitHub secrets API
- Has a .txt file
- *Will expire soon (as determined from the  'secret-expire:' line in its .txt file)*

You must either:
- Generate a new secret - see instructions in its .txt file, update the line `secret-expire:`, 
update the secret in GitHub, or
- Delete both the GitHub secret and the .txt file (if the secret is unused), or
- Archive the repo (if the repo is unused)


# Secrets Scope and .txt filenames

The expiry dates of secrets are held in .txt files in the `txt_root` directory in the `secrets` repository. 

## REPO-scope secrets
.txt files for Repo-scope secrets must be named `gh-repo-{SECRET_NAME}.txt`
and exist in the directory `txt_root/{REPO_NAME}/`
For example, suppose the .txt file `txt_root/cli/gh-repo-sonarcube-token.txt`
begins with these two lines:
```txt
secret-name: SONARCUBE_TOKEN
secret-expire: 2025-09-23
is-secret: true
```
Then this indicates that the `cli` **Repo** has a secret called `SONARCUBE_TOKEN` 
which expires on the given date.


## ORG-scope secrets
.txt files for `kosli-dev` Org-scope secrets must be named `gh-org-{SECRET_NAME}.txt`
and exist in the directory `txt_root/server/`
For example, suppose the .txt file `txt_root/server/gh-org-wibble.txt`
begins with these two lines:
```txt
secret-name: WIBBLE
secret-expire: 2026-11-05
is-secret: true
```
Then this indicates that the `kosli-dev` **Org** has a secret called `WIBBLE` 
which expires on the given date.


## Incorrectly scoped .txt filenames

For example, suppose the first line of `txt_root/cli/gh-repo-snafu.txt` names a
secret called `SNAFU` but `SNAFU` is an *Org* scoped Github secret.
In this case the .txt filename must be `txt_root/server/gh-org-snafu.txt`.


## .txt file format
The .txt files are parsed by scripts and their first three lines must be as described above.
If a secret does not have an expiry date, it must be set to `never`. For example:
```txt
secret-name: FUBAR
secret-expire: never
is-secret: true
```

The rest of the lines are for humans, and should describe how to get the secret and update it,
eg, by regenerating a Personal Access Token with specific permissions.

## Secrets that are not secrets

Sometimes a GitHub secret stores a value that is not a "genuine" secret and cannot easily be changed.
For example, an aws-account-id, an aws-bucket-name, an aws-region, which you would prefer to keep "hidden".
If a secret exists in GitHub for this reason, it can be marked as a non-secret (to exempt
it from all new/expiry checks), by setting the `is-secret:` 3rd line to `false`. Eg
```txt
secret-name: AWS_REGION
secret-expire: never
is-secret: false
```

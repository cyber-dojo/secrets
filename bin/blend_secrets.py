#!/usr/bin/env python3

import sys
import json
import glob
from datetime import datetime
from pathlib import Path

DATE_IN_FAR_FUTURE = "2099-01-01"


def print_help():
    print("""
    Use: blend_secrets.py <API_SECRETS_FILENAME> <TXT_ROOT> <DATE_TODAY>

    A program to blend secrets data contained in API_SECRETS_FILENAME, and in .txt files under TXT_ROOT.
    Output for each secret looks like this:
      {
        "days_since_update": 163,
        "days_to_expiry": 7,
        "expires_at": "2025-07-29",
        "has_github_secret": true,
        "has_txt_file": true,
        "name": "KOSLI_API_TOKEN_PROD",
        "origin": "server",
        "scope": "org",
        "updated_at": "2025-07-12"
      }   
    The output of blend_secrets.py is used as the input to filter_secrets.py     

    There are three inputs to this program:
    1. API_SECRETS_FILENAME 
    This file contains the JSON secrets returned from all the GitHub Secrets API calls.
    An example (test) file lives at: test/new_repo_secret_with_matching_secret_txt_file/api_secrets.json

        The JSON looks like this:
        {
          ORG_SECRETS
          "repos": {
            "cli": { REPO_SECRETS },
            "terraform-server": { REPO_SECRETS },
            "server": { REPO_SECRETS },
            ...
          }          
        }        
        Where ORG_SECRETS and REPO_SECRETS share this common structure:
          "total_count": N,
          "secrets": [ S1, S2, ..., SN ],

        Where Si is an individual secret, with this structure:
            {
              "name": THE_NAME_OF_A_SECRET,
              "created_at": "2025-07-08T10:36:56Z",
              "updated_at": "2025-07-08T10:36:56Z",
              ...
            }        

    2. TXT_ROOT
    The name of a dir containing one sub-dir for each repo in the kosli-dev Org that uses secrets.
    An example (test) dir lives at: test/new_repo_secret_with_matching_secret_txt_file/

      If TXT_ROOT is "~", then ~ might contain sub-dirs for several repos, three of which are 
      'server', 'cli', and 'terraform-server'. For example: 

      ~/server/
      ~/server/gh-org-one.txt
      ~/server/gh-org-two.txt
      ~/server/gh-repo-one.txt
      ~/server/gh-repo-two.txt

      ~/cli/
      ~/cli/gh-repo-alpha.txt
      ~/cli/gh-repo-beta.txt
      ~/cli/gh-repo-gamma.txt  

      ~/terraform-server/
      ~/terraform-server/gh-repo-a.txt          
      ~/terraform-server/gh-repo-b.txt
      ~/terraform-server/gh-repo-c.txt
      ~/terraform-server/gh-repo-d.txt                                                  

    The secrets for each Repo-sub-dir live inside files named gh-repo-*.txt 
    The 'server' sub-dir also contains Org-scope secrets, inside files named gh-org-*.txt

    The first two lines of each text file must have this structure:
      secret-name: SECRET_NAME
      secret-expire: 2025-07-29

    For example, ~/cli/gh-repo-alpha.txt having this first line:
      secret-name: ALPHA
    means the Repo called 'cli' has a secret named 'ALPHA' expiring on 2025-07-29

    For example, ~/server/gh-org-wibble.txt having this first line:
      secret-name: WIBBLE
      secret-expire: 2025-11-05
    means the kosli-dev Org has a secret named 'WIBBLE' expiring 2025-11-05       

    If a secret has no expiry date, secret-expire: must be set to 'never'

    3. DATE_TODAY
    Today's date which is used to calculate the number of days till the next update/rotation, 
    and the number of days to expiry, for each secret.  
    For example: "2025-08-13"                
    """)


def blend_secrets(api_secrets_filename, txt_root, date_today):
    output = []

    with open(api_secrets_filename, 'r') as file:
        data = json.load(file)

    # Process Org secrets from the API call
    for secret in data["secrets"]:
        updated_at = secret["updated_at"][:len("YYYY-MM-DD")]
        output.append({
            "name": secret["name"],
            "updated_at": updated_at,
            "days_since_update": days_diff(updated_at, date_today),
            "repo": "server",
            "scope": "org",
            "has_github_secret": True,
            "has_txt_file": False,
            "is_secret": True,
            "txt_filename": None,
            "expires_at": DATE_IN_FAR_FUTURE,
            "days_to_expiry": days_diff(date_today, DATE_IN_FAR_FUTURE),
        })

    # Process Repo secrets from the API call
    for repo_name in data["repo"]:
        for secret in data["repo"][repo_name]["secrets"]:
            updated_at = secret["updated_at"][:len("YYYY-MM-DD")]
            output.append({
                "name": secret["name"],
                "updated_at": updated_at,
                "days_since_update": days_diff(updated_at, date_today),
                "repo": repo_name,
                "scope": "repo",
                "has_github_secret": True,
                "has_txt_file": False,
                "is_secret": True,
                "txt_filename": None,
                "expires_at": DATE_IN_FAR_FUTURE,
                "days_to_expiry": days_diff(date_today, DATE_IN_FAR_FUTURE),
            })

    # Process txt_root dir Org level secrets
    known_org_secrets = get_txt_secrets(txt_root, 'server', "gh-org-*.txt")
    for secret_name, value in known_org_secrets.items():
        expiry_date = value['expiry_date']
        is_secret = value['is_secret']
        index = find_secret_index(output, secret_name, "org", "server")
        if index is not None:
            entry = output[index]
            entry["has_txt_file"] = True
            entry["txt_filename"] = value['txt_filename']
            entry["expires_at"] = expiry_date
            entry["days_to_expiry"] = days_diff(date_today, expiry_date)
            entry["is_secret"] = is_secret
        else:
            output.append({
                "name": secret_name,
                "repo": "secrets",
                "scope": "org",
                "has_github_secret": False,
                "has_txt_file": True,
                "txt_filename": value['txt_filename'],
                "expires_at": expiry_date,
                "days_to_expiry": days_diff(date_today, expiry_date),
                "updated_at": None,
                "days_since_update": None,
                "is_secret": is_secret
            })

    # Process txt_root dir Repo level secrets
    subdir_names = [p.name for p in Path(txt_root).iterdir() if p.is_dir()]
    for subdir_name in sorted(subdir_names):
        known_repo_secrets = get_txt_secrets(txt_root, subdir_name, "gh-repo-*.txt")
        for secret_name, value in known_repo_secrets.items():
            expiry_date = value['expiry_date']
            is_secret = value['is_secret']
            index = find_secret_index(output, secret_name, "repo", subdir_name)
            if index is not None:
                entry = output[index]
                entry["has_txt_file"] = True
                entry["txt_filename"] = value['txt_filename']
                entry["expires_at"] = expiry_date
                entry["days_to_expiry"] = days_diff(date_today, expiry_date)
                entry["is_secret"] = is_secret
            else:
                output.append({
                    "name": secret_name,
                    "repo": subdir_name,
                    "scope": "repo",
                    "has_github_secret": False,
                    "has_txt_file": True,
                    "txt_filename": value['txt_filename'],
                    "expires_at": expiry_date,
                    "days_to_expiry": days_diff(date_today, expiry_date),
                    "updated_at": None,
                    "days_since_update": None,
                    "is_secret": is_secret
                })

    print(json.dumps(output, indent=2, sort_keys=True))


def get_txt_secrets(txt_root, repo_name, pattern):
    txt_secrets = {}
    for filename in glob.glob(f"{txt_root}/{repo_name}/{pattern}"):
        parts = filename.split('/')
        txt_filename = '/'.join(parts[-3:])
        with open(filename, 'r') as file:
            lines = file.readlines()
            first_line = lines[0]
            diagnostic = f"1st line of {filename} does not start with 'secret-name:'"
            assert first_line.startswith("secret-name:"), diagnostic
            secret_name = first_line.split(":")[1].strip()

            second_line = lines[1]
            diagnostic = f"2nd line of {filename} does not start with 'secret-expire:'"
            assert second_line.startswith("secret-expire:"), diagnostic
            expiry_date = second_line.split(":")[1].strip()

            third_line = lines[2]
            diagnostic = f"3rd line of {filename} does not start with 'is-secret:'"
            assert third_line.startswith("is-secret:"), diagnostic
            is_secret = third_line.split(":")[1].strip()
            diagnostic = f"3rd line of {filename} must be 'is-secret: true' or 'is-secret: false'"
            assert is_secret == 'true' or is_secret == 'false', diagnostic

            txt_secrets[secret_name] = {
                "expiry_date": expiry_date,
                "txt_filename": txt_filename,
                "is_secret": is_secret == 'true'
            }

    return txt_secrets


def find_secret_index(output, secret_name, scope, repo):
    for index, secret in enumerate(output):
        if secret["name"] == secret_name and secret["scope"] == scope  and secret["repo"] == repo:
            return index
    return None


def days_diff(earlier, later):
    """
    Return the number of days between earlier and later.
    """
    earlier = datetime.strptime(earlier, '%Y-%m-%d').date()
    if later == "never":
        later = DATE_IN_FAR_FUTURE

    later = datetime.strptime(later, '%Y-%m-%d').date()
    return (later - earlier).days
    

if __name__ == "__main__":  # pragma: no cover
    if len(sys.argv) != 4:
        print_help()
        exit(0)

    api_secrets_filename = sys.argv[1]
    txt_root = sys.argv[2]
    date_today = sys.argv[3]
    blend_secrets(api_secrets_filename, txt_root, date_today)

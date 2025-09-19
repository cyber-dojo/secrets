#!/usr/bin/env python3

import glob, os, sys, json
from copy import deepcopy

ROTATION_DAYS = 365
ALERT_WINDOW_DAYS = 30


def print_help():
    print("""
    Use: filter_secrets.py <BLENDED_FILENAME> [<REPOS_ROOT>]
    
    A program to filter the output of blend_secrets.py, selecting only those that are secrets and:
    - Have no .txt file
        are known only from GitHub Secrets API responses
    - Have only a .txt file
        do not occur in any GitHub Secrets API response
    - Will soon expire
        as determined by the 'secret-expire:' entry in the .txt file
    - Will soon need updating/rotating
        as determined by the 'updated_at' field in the GitHub Secrets API response
    """)


def filter_secrets(blended_filename, repos_root):
    output = []

    with open(blended_filename, 'r') as file:
        secrets = json.load(file)
    
    for secret in secrets:
        repo = secret["repo"]
        scope = secret["scope"]
        name = secret['name']

        if not secret["is_secret"]:
            continue

        has_txt_file = secret["has_txt_file"]
        has_github_secret = secret["has_github_secret"]

        if has_github_secret is True:
            secret["days_to_update"] = ROTATION_DAYS - secret["days_since_update"]
        else:
            secret["days_to_update"] = None

        if has_github_secret is True and has_txt_file is False:
            copy = deepcopy(secret)
            suggested_filename = f"txt_root/{repo}/gh-{scope}-{name.replace('_', '-').lower()}.txt"
            copy["type"] = "No .txt file"
            copy["txt_filename"] = suggested_filename
            copy["uses_in_repo"] = uses_in_repo(scope, repos_root, repo, name)
            output.append(copy)

        if has_txt_file is True and has_github_secret is False:
            copy = deepcopy(secret)
            copy["type"] = "No GitHub secret"
            copy["uses_in_repo"] = uses_in_repo(scope, repos_root, repo, name)
            output.append(copy)

        expiring = secret['days_to_expiry'] <= ALERT_WINDOW_DAYS
        aging = has_github_secret is True and (secret["days_since_update"] >= (ROTATION_DAYS - ALERT_WINDOW_DAYS))

        if expiring or aging:
            copy = deepcopy(secret)
            copy["type"] = "Expiring soon"
            copy["uses_in_repo"] = uses_in_repo(scope, repos_root, repo, name)
            output.append(copy)

    print(json.dumps(output, indent=2, sort_keys=True))


def uses_in_repo(scope, repos_root, repo_name, name):
    if scope == "org":
        return None
    if repos_root is None:
        return None

    count = 0
    for filename in glob.iglob(f"{repos_root}/{repo_name}/.github/**", recursive=True):
        if os.path.isfile(filename):
            with open(filename, "r") as file:
                for line in file.readlines():
                    if f"secrets.{name}" in line:
                        count += 1

    return count


if __name__ == "__main__":  # pragma: no cover
    nargs = len(sys.argv)
    if nargs != 2 and nargs != 3:
        print_help()
        exit(0)
    
    blended_filename = sys.argv[1]
    repos_root = sys.argv[2] if nargs == 3 else None
    filter_secrets(blended_filename, repos_root)


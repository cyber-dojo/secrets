#!/usr/bin/env python3

import sys
import json


def print_help():
    print("""
    Use: print_filtered_secrets_summary.py <FILTERED_FILENAME>
        
    A Simple program to print the output of bin/filter_secrets.py in markdown.
    """)


def print_secrets(filtered_filename):
    lines = []

    with open(filtered_filename, 'r') as file:
        secrets = json.load(file)

    for index, secret in enumerate(secrets, start=1):
        type = secret["type"]
        scope = secret["scope"]  # scope == "org" or scope == "repo"
        repo = secret["repo"]
        name = secret["name"]
        txt_filename = secret["txt_filename"]

        lines.append("")

        if type == "No .txt file":
            lines.extend([
                f"{index}. Secret with no .txt file",
                f"    - secret name = {name}",
                f"    - scope = {scope}",
                f"    - repo = {repo}",
                f"    - suggested filename = {txt_filename}"
            ])

        elif type == "No GitHub secret":
            lines.extend([
                f"{index}. Secret with only a .txt file",
                f"    - secret name = {name}",
                f"    - scope = {scope}",
                f"    - repo = {repo}"
            ])

        elif type == "Expiring soon":
            lines.extend([
                f"{index}. Secret will soon expire",
                f"    - secret name = {name}",
                f"    - scope = {scope}",
                f"    - repo = {repo}",
                f"    - expires in {secret['days_to_expiry']} days"
            ])
            if secret['days_to_update'] is not None:
                lines.extend([
                    f"    - update due in {secret['days_to_update']} days"
                ])

        count = secret['uses_in_repo']
        if scope == "repo" and count is not None:
            lines.extend([
                f"    - occurrences in repo workflows = {count}"
            ])

        if type != "No .txt file" and txt_filename is not None:
            lines.extend([see_file_message(txt_filename)])

        if type != "No GitHub secret":
            lines.extend([see_gh_message(scope, repo, name)])

    for line in lines:
        print(line)


def see_file_message(txt_filename):
    url = f"https://github.com/kosli-dev/secrets/blob/main/{txt_filename}"
    return f"    - see file [{txt_filename}]({url})"


def see_gh_message(scope, repo, name):
    if scope == "org":
        url = "https://github.com/organizations/kosli-dev/settings/secrets/actions"
    else:
        assert scope == "repo", scope
        url = f"https://github.com/kosli-dev/{repo}/settings/secrets/actions/{name}"

    return f"    - see [in GitHub]({url})"


if __name__ == "__main__":  # pragma: no cover
    if len(sys.argv) != 2:
        print_help()
        exit(0)
    
    filtered_filename = sys.argv[1]
    print_secrets(filtered_filename)


#!/usr/bin/env bash
set -Eeu

ORG=kosli-dev

for REPO_NAME in $(gh repo list "${ORG}" --no-archived --limit 500 --json name --jq '.[].name' | grep -v '.github'); do
    mkdir -p ./repos/${REPO_NAME}

    if [[ ! -d /tmp/${REPO_NAME} ]]; then
       git clone https://github.com/${ORG}/${REPO_NAME} /tmp/${REPO_NAME} 
    fi 

    if [[ -d /tmp/${REPO_NAME}/secrets ]]; then
        find /tmp/${REPO_NAME}/secrets -name "gh-org*.txt" -print -exec cp '{}' ./repos/${REPO_NAME}/ \;
        find /tmp/${REPO_NAME}/secrets -name "gh-repo*.txt" -print -exec cp '{}' ./repos/${REPO_NAME}/ \;
    fi    

    rm -rf /tmp/${REPO_NAME}
done

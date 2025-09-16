#!/usr/bin/env bash
set -Eeu

BEARER="${1}"
URL="${2}"

curl -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${BEARER}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  --fail \
  "https://api.github.com/${URL}"


#  --silent \

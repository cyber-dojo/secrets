#!/usr/bin/env bash
set -Eeu

export MY_DIR="$(dirname "${BASH_SOURCE[0]}")"

mkdir "${MY_DIR}/../evidence" &> /dev/null || true

for file in ${MY_DIR}/test_*.sh; do
  echo "Running ${file}"
  echo
  ${file} -- --output-junit-xml="${MY_DIR}/../evidence/$(basename ${file}).xml"
done

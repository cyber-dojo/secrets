
exit_non_zero_unless_installed()
{
  for dependent in "$@"
  do
    if ! installed "${dependent}" ; then
      stderr "${dependent} is not installed"
      exit 42
    fi
  done
}

installed()
{
  local -r dependent="${1}"
  if hash "${dependent}" 2> /dev/null; then
    true
  else
    false
  fi
}

stderr()
{
  local -r message="${1}"
  >&2 echo "ERROR: ${message}"
}

assertStdoutEquals() { assertEquals "${1}" "${2}" "$(cat "${stdoutF}")"; }
assertStderrEquals() { assertEquals "${1}" "${2}" "$(cat "${stderrF}")"; }

assertStdoutEmpty() { assertStdoutEquals "${1}" ""; }
assertStderrEmpty() { assertStderrEquals "${1}" ""; }

oneTimeSetUp()
{
  # This is automatically called by shunit2
  local -r outputDir="${SHUNIT_TMPDIR}/output"
  mkdir "${outputDir}"
  stdoutF="${outputDir}/stdout"
  stderrF="${outputDir}/stderr"
}

legal_name()
{
    sed 's/_/-/g' <<<"${1}"
}

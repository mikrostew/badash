#!/usr/bin/env bats

# set HOME to isolate these tests
setup() {
  tmpdir="$(mktemp -d /tmp/badash.test.XXXXXX)"
  HOME="$tmpdir"
}

teardown() {
  rm -rf "$tmpdir"
}

# clean up the output for validation
# * convert CR character to newline + 'CR'
# * remove all non-printable stuff, except newline
# * replace the ANSI color stuff (red/green/reset)
#
# note that `tr` is using octal here
clean_output() {
  LC_ALL=C echo "$1" | tr '\15' '\12CR' | tr -d '\0-\11\13-\37' | sed 's/\[1;32m/GREEN/g' | sed 's/\[0;31m/RED/g' | sed 's/\[0m/RESET/g'
}

compare_file_contents() {
  local generated="$1"
  local expected="$2"

  # cleanup the non-deterministic contents in the "Generated from ..." line
  local cleaned_gen_file="$(echo "$1" | sed "s/# Generated from '.*', [0-9-]* [0-9:]*/# Generated from '', 1234-56-78 12:34:56/g")"

  if [ "$cleaned_gen_file" != "$expected" ]
  then
    echo ""
    echo "Error: generated file does not match expected"
    echo ""
    echo "Expected:"
    echo "'$expected'"
    echo ""
    echo "Generated (cleaned):"
    echo "'$cleaned_gen_file'"
    echo ""
    echo "Diff:"
    diff <(echo "$cleaned_gen_file") <(echo "$expected")
    echo ""
  fi
}


# generate code for "@wait-for-keypress"
@test "@echo-err" {
  bash_script="test/fixtures/echo-err"
  generated_file="$tmpdir/.badash/echo-err"

  expected_output="$(cat <<'END_OF_OUTPUT'
should echo things
REDdoes this 'echo things'?RESET
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash
# Generated from '', 1234-56-78 12:34:56
gen::echo-err() {
  echo -e "\033[0;31m$*\033[0m" >&2
}
echo "should echo things"
gen::echo-err "does this 'echo things'?"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]

  # have to clean this up
  cleaned_output="$(clean_output "$output")"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  compare_file_contents "$(<$generated_file)" "$expected_file_contents"
}


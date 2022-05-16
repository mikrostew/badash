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
  diff "$generated_file" <(echo "$expected_file_contents")
}


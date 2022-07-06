#!/usr/bin/env bats

# set HOME to isolate these tests
setup() {
  tmpdir="$(mktemp -d /tmp/badash.test.XXXXXX)"
  HOME="$tmpdir"
}

teardown() {
  rm -rf "$tmpdir"
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
@test "@wait-for-keypress" {
  bash_script="test/fixtures/wait-for-keypress"
  generated_file="$tmpdir/.badash/wait-for-keypress"

  expected_output="$(cat <<'END_OF_OUTPUT'
should do things
Press any key to continue...
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash
# Generated from '', 1234-56-78 12:34:56
echo "should do things"
echo 'Press any key to continue...'
read -n1 -s
END_FILE_CONTENTS
  )"

  # need to simulate input in stdin so this test doesn't hang
  run ./badash "$bash_script" < <(echo 'y')
  [ "$status" -eq 0 ]
  diff <(echo "$output") <(echo "$expected_output")
  compare_file_contents "$(<$generated_file)" "$expected_file_contents"
}


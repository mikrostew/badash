#!/usr/bin/env bats

# set HOME to isolate these tests
# TODO: refactor these functions to something that is loaded?
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

@test "does not remove comments and blank lines" {
  bash_script="test/fixtures/basic-comments"
  generated_file="$tmpdir/.badash/basic-comments"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]
  [ "$output" == "Comments and blank lines" ]
  # check the generated file
  expected_contents="$(cat <<'END_OF_GEN_CODE'
#!/usr/bin/env bash
# Generated from '', 1234-56-78 12:34:56

# comment that will not be removed
# and another comment line

echo 'Comments and blank lines' # not removed
END_OF_GEN_CODE
  )"
  compare_file_contents "$(<$generated_file)" "$expected_contents"
}

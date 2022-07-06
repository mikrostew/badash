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

@test "generates code for system_is_*?" {
  # TODO: need to refactor some functions to get paths to fixture files and generated files
  bash_script="test/fixtures/system-is-gen"
  generated_file="$tmpdir/.badash/system-is-gen"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]

  diff <(echo "$output") <(echo "$(uname -s)")

  # check the generated file
  expected_contents="$(cat <<'END_OF_GEN_CODE'
#!/usr/bin/env bash
# Generated from '', 1234-56-78 12:34:56

if [ "$(uname -s | tr [:upper:] [:lower:])" == "donkey" ]; then echo "nope"; else echo "$(uname -s)"; fi
END_OF_GEN_CODE
  )"

  compare_file_contents "$(<$generated_file)" "$expected_contents"
}


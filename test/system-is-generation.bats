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

if [ "$(uname -s | tr [:upper:] [:lower:])" == "donkey" ]; then echo "nope"; else echo "$(uname -s)"; fi
END_OF_GEN_CODE
  )"

  diff "$generated_file" <(echo "$expected_contents")
}


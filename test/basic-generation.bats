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

@test "removes comments and blank lines" {
  bash_script="test/fixtures/basic-comments.bash"
  generated_file="$tmpdir/.badash/basic-comments.bash"

  run badash "$bash_script"
  [ "$status" -eq 0 ]
  [ "$output" == "Comments and blank lines" ]
  # check the generated file
  expected_contents="$(cat <<'END_OF_GEN_CODE'
#!/usr/bin/env bash
echo 'Comments and blank lines' # not removed
END_OF_GEN_CODE
  )"
  [ "$(<$generated_file)" == "$expected_contents" ]
}

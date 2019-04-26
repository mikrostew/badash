#!/usr/bin/env bats

# set HOME to isolate these tests
setup() {
  tmpdir="$(mktemp -d /tmp/badash.test.XXXXXX)"
  HOME="$tmpdir"
}

teardown() {
  rm -rf "$tmpdir"
}


# generate code for "@wait_for_keypress"
@test "@wait_for_keypress" {
  bash_script="test/fixtures/wait-for-keypress"
  generated_file="$tmpdir/.badash/wait-for-keypress"

  expected_output="$(cat <<'END_OF_OUTPUT'
should do things
Press any key to continue...
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash
echo "should do things"
echo 'Press any key to continue...'
read -n1 -s
END_FILE_CONTENTS
  )"

  # need to simulate input in stdin so this test doesn't hang
  run badash "$bash_script" < <(echo 'y')
  [ "$status" -eq 0 ]
  diff <(echo "$output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}


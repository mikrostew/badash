#!/usr/bin/env bats
#
# set HOME to isolate these tests
setup() {
  tmpdir="$(mktemp -d /tmp/badash.test.XXXXXX)"
  HOME="$tmpdir"
}

teardown() {
  rm -rf "$tmpdir"
}

# generate code for "@wait-for-command"
@test "@wait-for-command one time" {
  bash_script="test/fixtures/wait-for-command-1"
  generated_file="$tmpdir/.badash/wait-for-command-1"

  expected_output="$(cat <<'END_OF_OUTPUT'
testing wait-for-command
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash
echo "testing wait-for-command"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]
  diff <(echo "$output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

# when multiple commands use "@wait-for-command"
@test "@wait-for-command multiple" {
  bash_script="test/fixtures/wait-for-command-2"
  generated_file="$tmpdir/.badash/wait-for-command-2"

  expected_output="$(cat <<'END_OF_OUTPUT'
testing wait-for-command
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash
echo "testing wait-for-command"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]
  diff <(echo "$output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

# when the command fails
@test "@wait-for-command command fails" {
  bash_script="test/fixtures/wait-for-command-fail"
  generated_file="$tmpdir/.badash/wait-for-command-fail"

  expected_output="$(cat <<'END_OF_OUTPUT'
testing wait-for-command
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash
echo "testing wait-for-command"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]
  diff <(echo "$output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}


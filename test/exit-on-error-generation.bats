#!/usr/bin/env bats

# set HOME to isolate these tests
setup() {
  tmpdir="$(mktemp -d /tmp/badash.test.XXXXXX)"
  HOME="$tmpdir"
}

teardown() {
  rm -rf "$tmpdir"
}

# TODO: test line containing comment (probably fails ATM)


# generate code for "@exit_on_error 'some msg'"
@test "@exit_on_error - message only" {
  bash_script="test/fixtures/exit-on-error-msg"
  generated_file="$tmpdir/.badash/exit-on-error-msg"

  expected_output="$(cat <<'END_OF_OUTPUT'
something that passes
if it got this far it didn't fail
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash

echo "something that passes"
exit_code="$?"
if [ "$exit_code" -ne 0 ]
then
  echo "Somehow echo failed" >&2
  # (no code to run before exit)
  exit "$exit_code"
fi

echo "if it got this far it didn't fail"
END_FILE_CONTENTS
  )"

  run badash "$bash_script"
  [ "$status" -eq 0 ]
  diff <(echo "$output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}


# generate code for "@exit_on_error 'some msg' 'some code'"
@test "@exit_on_error - message and code" {
  bash_script="test/fixtures/exit-on-error-msg-code"
  generated_file="$tmpdir/.badash/exit-on-error-msg-code"

  expected_output="$(cat <<'END_OF_OUTPUT'
blah blah
some other stuff here
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash

echo "blah blah"
exit_code="$?"
if [ "$exit_code" -ne 0 ]
then
  echo "Somehow echo failed" >&2
  curl "http://echo.fail/error"
  exit "$exit_code"
fi

echo "some other stuff here"
END_FILE_CONTENTS
  )"

  run badash "$bash_script"
  [ "$status" -eq 0 ]
  diff <(echo "$output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}


# test error for "@exit_on_error" with no strings provided
@test "@exit_on_error - no strings" {
  bash_script="test/fixtures/exit-on-error-no-strings"
  generated_file="$tmpdir/.badash/exit-on-error-no-strings"

  expected_output="$(cat <<'END_OF_OUTPUT'

badash: Wrong number of arguments to @exit_on_error: expected 1 or 2, got 0
END_OF_OUTPUT
  )"

  run badash "$bash_script"
  [ "$status" -eq 1 ]
  diff <(echo "$output") <(echo "$expected_output")
  # (executable file is not created)
  [ ! -f "$generated_file" ]
}


# test error for "@exit_on_error" with too many strings provided
@test "@exit_on_error - too many strings" {
  bash_script="test/fixtures/exit-on-error-3-strings"
  generated_file="$tmpdir/.badash/exit-on-error-3-strings"

  expected_output="$(cat <<'END_OF_OUTPUT'

badash: Wrong number of arguments to @exit_on_error: expected 1 or 2, got 3
END_OF_OUTPUT
  )"

  run badash "$bash_script"
  [ "$status" -eq 1 ]
  diff <(echo "$output") <(echo "$expected_output")
  # (executable file is not created)
  [ ! -f "$generated_file" ]
}


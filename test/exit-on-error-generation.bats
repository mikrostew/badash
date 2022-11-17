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

# TODO: test line containing comment (probably fails ATM)


# generate code for "@exit-on-error 'some msg'"
@test "@exit-on-error - message only" {
  bash_script="test/fixtures/exit-on-error-msg"
  generated_file="$tmpdir/.badash/exit-on-error-msg"

  expected_output="$(cat <<'END_OF_OUTPUT'
something that passes
if it got this far it didn't fail
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash
# Generated from '', 1234-56-78 12:34:56

echo "something that passes"
# spaced to test padding
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

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]
  diff <(echo "$output") <(echo "$expected_output")
  compare_file_contents "$(<$generated_file)" "$expected_file_contents"
}


# generate code for "@exit-on-error 'some msg' 'some code'"
@test "@exit-on-error - message and code" {
  bash_script="test/fixtures/exit-on-error-msg-code"
  generated_file="$tmpdir/.badash/exit-on-error-msg-code"

  expected_output="$(cat <<'END_OF_OUTPUT'
blah blah
some other stuff here
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash
# Generated from '', 1234-56-78 12:34:56

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

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]
  diff <(echo "$output") <(echo "$expected_output")
  compare_file_contents "$(<$generated_file)" "$expected_file_contents"
}


# test error for "@exit-on-error" with no strings provided
@test "@exit-on-error - no strings" {
  bash_script="test/fixtures/exit-on-error-no-strings"
  generated_file="$tmpdir/.badash/exit-on-error-no-strings"

  expected_output="$(cat <<'END_OF_OUTPUT'

badash: Wrong number of arguments to @exit-on-error: expected 1 or 2, got 0
END_OF_OUTPUT
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 1 ]
  diff <(echo "$output") <(echo "$expected_output")
  # (executable file is not created)
  [ ! -f "$generated_file" ]
}


# test error for "@exit-on-error" with too many strings provided
@test "@exit-on-error - too many strings" {
  bash_script="test/fixtures/exit-on-error-3-strings"
  generated_file="$tmpdir/.badash/exit-on-error-3-strings"

  expected_output="$(cat <<'END_OF_OUTPUT'

badash: Wrong number of arguments to @exit-on-error: expected 1 or 2, got 3
END_OF_OUTPUT
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 1 ]
  diff <(echo "$output") <(echo "$expected_output")
  # (executable file is not created)
  [ ! -f "$generated_file" ]
}


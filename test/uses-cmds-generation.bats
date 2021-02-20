#!/usr/bin/env bats

# set HOME to isolate these tests
setup() {
  tmpdir="$(mktemp -d /tmp/badash.test.XXXXXX)"
  HOME="$tmpdir"
}

teardown() {
  rm -rf "$tmpdir"
}


# one command

@test "@uses-cmds - one command" {
  bash_script="test/fixtures/uses-cmds-one-cmd"
  generated_file="$tmpdir/.badash/uses-cmds-one-cmd"

  expected_output="$(cat <<'END_OF_OUTPUT'
should execute
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash
gen::req-check() {
  if [ ! $(command -v $2) ]; then
    echo "uses-cmds-one-cmd: Required command '$2' not found" >&2
    printf -v "$1" "1"
  fi
}
_gen_cmd_check_rtn=0
gen::req-check _gen_cmd_check_rtn sed
if [ "$_gen_cmd_check_rtn" != 0 ]; then exit $_gen_cmd_check_rtn; fi
echo "should execute"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]
  diff <(echo "$output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}


# two commands

@test "@uses-cmds - two commands" {
  bash_script="test/fixtures/uses-cmds-two-cmds"
  generated_file="$tmpdir/.badash/uses-cmds-two-cmds"

  expected_output="$(cat <<'END_OF_OUTPUT'
should execute
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash
gen::req-check() {
  if [ ! $(command -v $2) ]; then
    echo "uses-cmds-two-cmds: Required command '$2' not found" >&2
    printf -v "$1" "1"
  fi
}
_gen_cmd_check_rtn=0
gen::req-check _gen_cmd_check_rtn grep
gen::req-check _gen_cmd_check_rtn sed
if [ "$_gen_cmd_check_rtn" != 0 ]; then exit $_gen_cmd_check_rtn; fi
echo "should execute"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]
  diff <(echo "$output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

# cmds for specific OSs

@test "@uses-cmds - specific OS" {
  bash_script="test/fixtures/uses-cmds-with-os"
  generated_file="$tmpdir/.badash/uses-cmds-with-os"

  expected_output="$(cat <<'END_OF_OUTPUT'
should execute
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash
gen::req-check() {
  if [ ! $(command -v $2) ]; then
    echo "uses-cmds-with-os: Required command '$2' not found" >&2
    printf -v "$1" "1"
  fi
}
_gen_cmd_check_rtn=0
[ "$(uname -s)" == 'Darwin' ] && gen::req-check _gen_cmd_check_rtn sed
[ "$(uname -s)" == 'Linux' ] && gen::req-check _gen_cmd_check_rtn grep
gen::req-check _gen_cmd_check_rtn jq
if [ "$_gen_cmd_check_rtn" != 0 ]; then exit $_gen_cmd_check_rtn; fi
echo "should execute"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]
  diff <(echo "$output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}


# command doesn't exist

@test "@uses-cmds - command doesn't exist" {
  bash_script="test/fixtures/uses-cmds-no-exist"
  generated_file="$tmpdir/.badash/uses-cmds-no-exist"

  expected_output="$(cat <<'END_OF_OUTPUT'
uses-cmds-no-exist: Required command 'some-command-that-does-not-exist' not found
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash
gen::req-check() {
  if [ ! $(command -v $2) ]; then
    echo "uses-cmds-no-exist: Required command '$2' not found" >&2
    printf -v "$1" "1"
  fi
}
_gen_cmd_check_rtn=0
gen::req-check _gen_cmd_check_rtn some-command-that-does-not-exist
if [ "$_gen_cmd_check_rtn" != 0 ]; then exit $_gen_cmd_check_rtn; fi
echo "should not print this"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 1 ]
  diff <(echo "$output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

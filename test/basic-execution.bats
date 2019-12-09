#!/usr/bin/env bats

# set HOME to isolate these tests
setup() {
  tmpdir="$(mktemp -d /tmp/badash.test.XXXXXX)"
  HOME="$tmpdir"
}

teardown() {
  rm -rf "$tmpdir"
}

@test "runs a vanilla bash script" {
  bash_script="test/fixtures/basic"
  run ./badash "$bash_script"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" == "I'm a basic script stdout" ]
  [ "${lines[1]}" == "I'm a basic script stderr" ]
}

@test "runs a vanilla bash script with args" {
  bash_script="test/fixtures/basic-with-args"
  run ./badash "$bash_script" -f somefile
  [ "$status" -eq 0 ]
  [ "$output" == "basic script, arg1 is -f, arg2 is somefile" ]
}

@test "errors if script argument is not given" {
  run ./badash
  [ "$status" -eq 1 ]
  echo "$output"
  [ "$output" == "badash: Missing argument: script to execute" ]
}

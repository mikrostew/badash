#!/usr/bin/env bats

# TODO: set HOME to isolate these tests

@test "runs a vanilla bash script" {
  bash_script="test/fixtures/basic.bash"
  run badash "$bash_script"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" == "I'm a basic script stdout" ]
  [ "${lines[1]}" == "I'm a basic script stderr" ]
}

@test "runs a vanilla bash script with args" {
  bash_script="test/fixtures/basic-with-args.bash"
  run badash "$bash_script" -f somefile
  [ "$status" -eq 0 ]
  [ "$output" == "basic script, arg1 is -f, arg2 is somefile" ]
}

@test "errors if script argument is not given" {
  run badash
  [ "$status" -eq 1 ]
  echo "$output"
  [ "$output" == "badash: Missing argument: script to execute" ]
}

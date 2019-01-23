#!/usr/bin/env bats

# TODO: set HOME to isolate these tests

@test "runs a vanilla bash script" {
  bash_script="test/fixtures/basic.bash"
  result_stdout="$(badash $bash_script 2>/dev/null)"
  result_stderr="$( ( badash $bash_script >/dev/null ) 2>&1 )"
  [ "$result_stdout" == "I'm a basic script stdout" ]
  [ "$result_stderr" == "I'm a basic script stderr" ]
}

@test "runs a vanilla bash script with args" {
  bash_script="test/fixtures/basic-with-args.bash"
  result_stdout="$(badash $bash_script -f somefile)"
  [ "$result_stdout" == "basic script, arg1 is -f, arg2 is somefile" ]
}

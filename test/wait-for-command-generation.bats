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

# boilerplate: the main wait-for-command generated function
FILE_BOILERPLATE="$(cat <<'END_FILE_BOILERPLATE'
#!/usr/bin/env bash
COLOR_FG_BOLD_GREEN='\033[1;32m'
COLOR_FG_GREEN='\033[0;32m'
COLOR_FG_RED='\033[0;31m'
COLOR_RESET='\033[0m'
if [ "$(uname -s)" == 'Darwin' ]; then DATE_CMD=gdate; else DATE_CMD=date; fi
# show a busy spinner while command is running
# and only show output if there is an error
gen::wait-for-command() {
  # flags
  #  --show-output (bool): always show command output
  #  --hide-args (bool): show command name, but hide arguments (for secrets and such)
  local more_args=0
  while [ "$more_args" == 0 ]
  do
    if [ "$1" == "--show-output" ]
    then
      local show_output="true"
      shift
    elif [ "$1" == "--hide-args" ]
    then
      local hide_args="true"
      shift
    else
      more_args=1
    fi
  done
  # rest of the input is the command and arguments
  if [ "$hide_args" == "true" ]
  then
    local cmd_display="$1 [args hidden]"
  else
    local cmd_display="$@"
  fi

  # calculate things for the output
  local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' # braille dots
  local num_chars=${#spin_chars}
  local total_length=$(( 2 + ${#cmd_display} ))

  # capture when the command was started
  local cmd_start_time=$($DATE_CMD +%s%3N)

  # start the spinner running async, and get its PID
  (
    # wait for the command to complete, showing a busy spinner
    i=0
    while :
    do
      i=$(( (i + 1) % num_chars ))
      printf "\r${spin_chars:$i:1} ${COLOR_FG_BOLD_GREEN}running${COLOR_RESET} '${cmd_display}'" >&2
      sleep 0.1
    done
  ) & disown
  local spinner_pid="$!"

  # trap signals and kill the spinner process
  trap "kill $spinner_pid" INT TERM

  # run the command, capturing its output (both stdout and stderr)
  cmd_output="$("$@" 2>&1)"
  local exit_code="$?"

  # clear the trap, and kill the spinner process
  trap - INT TERM
  kill "$spinner_pid"

  # calculate total runtime (approx)
  local cmd_stop_time=$($DATE_CMD +%s%3N)
  local cmd_run_time=$((cmd_stop_time - cmd_start_time))

  # TODO: attempt to clean up, depending on option (doesn't always work)
  # but still check if it failed?
  #printf "\r%-${total_length}s\r" ' ' >&2

  printf "\r  ${COLOR_FG_BOLD_GREEN}ran${COLOR_RESET} '$cmd_display' (${cmd_run_time}ms)" >&2

  # check that the command was successful
  if [ "$exit_code" == 0 ]
  then
    printf " [${COLOR_FG_GREEN}OK${COLOR_RESET}]\n"
    # show output if configured
    if [ "$show_output" == "true" ]; then echo "$cmd_output"; fi
  else
    printf " [${COLOR_FG_RED}ERROR${COLOR_RESET}]\n"
    # if it fails, show the command output
    echo "$cmd_output"
  fi
  # pass through the exit code of the internal command, instead of dropping it
  return "$exit_code"
}
END_FILE_BOILERPLATE
)"

# clean up the output for validation
# * convert CR to newline
# * remove all non-printable stuff except newline
# * clean up the ANSI color stuff
# * remove the spinner character
# * replace the output time to match expected
#
# note that `tr` is using octal here
clean_output() {
  LC_ALL=C echo "$1" | tr '\15' '\12' | tr '\0-\11\13-\37' '[ *]' | sed 's/\[[0-9;]*m//g' | sed 's/[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]/ /g' | sed 's/[0-9]*ms/113ms/'
}


### TESTS

# generate code for "@wait-for-command"
@test "@wait-for-command one time" {
  bash_script="test/fixtures/wait-for-command-1"
  generated_file="$tmpdir/.badash/wait-for-command-1"

  # the output has some timing info that varies - will fix that in the output
  expected_output="$(cat <<'END_OF_OUTPUT'
testing wait-for-command

   running  'echo this will not be printed'
   ran  'echo this will not be printed' (113ms) [ OK ]
END_OF_OUTPUT
  )"

  # expected generated file
  expected_file_contents="$(cat <<END_FILE_CONTENTS
$FILE_BOILERPLATE
echo "testing wait-for-command"
gen::wait-for-command echo "this will not be printed"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]

  # have to clean this up
  cleaned_output="$(clean_output "$output")"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

# when multiple commands use "@wait-for-command"
@test "@wait-for-command multiple" {
  bash_script="test/fixtures/wait-for-command-2"
  generated_file="$tmpdir/.badash/wait-for-command-2"

  # the output has some timing info that varies - will fix that in the output
  expected_output="$(cat <<'END_OF_OUTPUT'
testing wait-for-command

   running  'echo this will not be printed'
   ran  'echo this will not be printed' (113ms) [ OK ]

   running  'echo or this'
   ran  'echo or this' (113ms) [ OK ]
END_OF_OUTPUT
  )"

  # expected generated file
  expected_file_contents="$(cat <<END_FILE_CONTENTS
$FILE_BOILERPLATE
echo "testing wait-for-command"
gen::wait-for-command echo "this will not be printed"
gen::wait-for-command echo "or this"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]

  # have to clean this up
  cleaned_output="$(clean_output "$output")"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

# when the command fails
@test "@wait-for-command command fails" {
  bash_script="test/fixtures/wait-for-command-fail"
  generated_file="$tmpdir/.badash/wait-for-command-fail"

  # the output has some timing info that varies - will fix that in the output
  # also, the output is different on Linux
  expected_output="$(cat <<'END_OF_OUTPUT'
testing wait-for-command

   running  './test/fixtures/fail-with-output.sh'
   ran  './test/fixtures/fail-with-output.sh' (113ms) [ ERROR ]
stdout text
stderr text
END_OF_OUTPUT
  )"

  # expected generated file
  expected_file_contents="$(cat <<END_FILE_CONTENTS
$FILE_BOILERPLATE
echo "testing wait-for-command"
# this should always fail
gen::wait-for-command ./test/fixtures/fail-with-output.sh
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  # should fail with the exit code of the command
  [ "$status" -eq 2 ]

  # have to clean this up
  cleaned_output="$(clean_output "$output")"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

# two @directives on the same line
@test "@wait-for-command two on the same line" {
  bash_script="test/fixtures/wait-for-command-same-line"
  generated_file="$tmpdir/.badash/wait-for-command-same-line"

  # the output has some timing info that varies - will fix that in the output
  # also, the output is different on Linux
  expected_output="$(cat <<'END_OF_OUTPUT'
testing wait-for-command

   running  'echo first command'
   ran  'echo first command' (113ms) [ OK ]

   running  'echo second command'
   ran  'echo second command' (113ms) [ OK ]
END_OF_OUTPUT
  )"

  # expected generated file
  expected_file_contents="$(cat <<END_FILE_CONTENTS
$FILE_BOILERPLATE
echo "testing wait-for-command"
gen::wait-for-command echo "first command" && gen::wait-for-command echo "second command"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]

  # have to clean this up
  cleaned_output="$(clean_output "$output")"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

# show command output with --show-output flag
@test "@wait-for-command --show-output" {
  bash_script="test/fixtures/wait-for-command-show"
  generated_file="$tmpdir/.badash/wait-for-command-show"

  # the output has some timing info that varies - will fix that in the output
  expected_output="$(cat <<'END_OF_OUTPUT'
testing wait-for-command --show-output

   running  'echo this WILL be printed'
   ran  'echo this WILL be printed' (113ms) [ OK ]
this WILL be printed
END_OF_OUTPUT
  )"

  # expected generated file
  expected_file_contents="$(cat <<END_FILE_CONTENTS
$FILE_BOILERPLATE
echo "testing wait-for-command --show-output"
gen::wait-for-command --show-output echo "this WILL be printed"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]

  # have to clean this up
  cleaned_output="$(clean_output "$output")"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

# hide arguments with --hide-args flag
@test "@wait-for-command --hide-args" {
  bash_script="test/fixtures/wait-for-command-hide"
  generated_file="$tmpdir/.badash/wait-for-command-hide"

  # the output has some timing info that varies - will fix that in the output
  expected_output="$(cat <<'END_OF_OUTPUT'
testing wait-for-command --hide-args

   running  'echo [args hidden]'
   ran  'echo [args hidden]' (113ms) [ OK ]
END_OF_OUTPUT
  )"

  # expected generated file
  expected_file_contents="$(cat <<END_FILE_CONTENTS
$FILE_BOILERPLATE
echo "testing wait-for-command --hide-args"
gen::wait-for-command --hide-args echo "this WILL be printed"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]

  # have to clean this up
  cleaned_output="$(clean_output "$output")"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

# hide arguments and show output
@test "@wait-for-command --hide-args --show-output" {
  bash_script="test/fixtures/wait-for-command-hide-show"
  generated_file="$tmpdir/.badash/wait-for-command-hide-show"

  # the output has some timing info that varies - will fix that in the output
  expected_output="$(cat <<'END_OF_OUTPUT'
testing wait-for-command --hide-args --show-output

   running  'echo [args hidden]'
   ran  'echo [args hidden]' (113ms) [ OK ]
this WILL be printed
END_OF_OUTPUT
  )"

  # expected generated file
  expected_file_contents="$(cat <<END_FILE_CONTENTS
$FILE_BOILERPLATE
echo "testing wait-for-command --hide-args --show-output"
gen::wait-for-command --hide-args --show-output echo "this WILL be printed"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]

  # have to clean this up
  cleaned_output="$(clean_output "$output")"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

# hitting Ctrl-C while the command is still running
@test "@wait-for-command handling Ctrl-C" {
  # this isn't working, and I don't want to block on testing this
  skip
  bash_script="test/fixtures/wait-for-command-ctrl-c"
  generated_file="$tmpdir/.badash/wait-for-command-ctrl-c"

  # TODO: if I kill the process, no output is saved
  expected_output="$(cat <<'END_OF_OUTPUT'
testing wait-for-command with Ctrl-C

   running  'sleep 3'
END_OF_OUTPUT
  )"

  # expected generated file
  expected_file_contents="$(cat <<END_FILE_CONTENTS
$FILE_BOILERPLATE
echo "testing wait-for-command with Ctrl-C"
gen::wait-for-command sleep 3
END_FILE_CONTENTS
  )"

  # TODO: how to kill that while it is running?
  # (and still preserve exit code, and output, and such)
  # maybe use expect?
  # https://spin.atomicobject.com/2016/01/11/command-line-interface-testing-tools/
  ./badash "$bash_script" &
  run_pid="$!"
  sleep 1
  kill -SIGINT $run_pid
  sleep 1
  echo "status = $status" >&2
  [ "$status" == "" ]

  # have to clean this up
  cleaned_output="$(clean_output "$output")"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

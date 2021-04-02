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
  #  --show-output: always show command output
  if [ "$1" == "--show-output" ]
  then
    local show_output="true"
    shift
  fi
  # rest of the input is a command array
  local cmd_string="$@"

  # calculate things for the output
  local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' # braille dots
  local num_chars=${#spin_chars}
  local total_length=$(( 2 + ${#cmd_string} ))

  # capture when the command was started
  local cmd_start_time=$($DATE_CMD +%s%3N)

  # start the spinner running async, and get its PID
  (
    # wait for the command to complete, showing a busy spinner
    i=0
    while :
    do
      i=$(( (i + 1) % num_chars ))
      printf "\r${spin_chars:$i:1} ${COLOR_FG_BOLD_GREEN}running${COLOR_RESET} '${cmd_string}'" >&2
      sleep 0.1
    done
  ) & disown
  local spinner_pid="$!"

  # run the command, capturing its output (both stdout and stderr)
  cmd_output="$("$@" 2>&1)"
  local exit_code="$?"

  # kill the spinner process
  kill "$spinner_pid"

  # calculate total runtime (approx)
  local cmd_stop_time=$($DATE_CMD +%s%3N)
  local cmd_run_time=$((cmd_stop_time - cmd_start_time))

  # TODO: attempt to clean up, depending on option (doesn't always work)
  # but still check if it failed?
  #printf "\r%-${total_length}s\r" ' ' >&2

  printf "\r  ${COLOR_FG_BOLD_GREEN}ran${COLOR_RESET} '$cmd_string' (${cmd_run_time}ms)" >&2

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

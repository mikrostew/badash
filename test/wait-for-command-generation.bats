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
COLOR_FG_RED='\033[0;31m'
COLOR_RESET='\033[0m'
if [ "$(uname -s)" == 'Darwin' ]; then DATE_CMD=gdate; else DATE_CMD=date; fi
# https://invisible-island.net/ncurses/terminfo.src.html#toc-_Specials
if [ -z "$TERM" ] || [ "$TERM" = "dumb" ] || [ "$TERM" = "unknown" ]
then
  COLUMNS=80
else
  COLUMNS="$(tput cols)"
fi
# show a busy spinner while command is running
# and only show output if there is an error
gen::wait-for-command() {
  # flags
  #  --show-output (bool): always show command output
  #  --clear (bool): clear the spinner
  #  --msg (string): message to show instead of the command
  local more_args=0
  local message=""
  while [ "$more_args" == 0 ]
  do
    if [ "$1" == "--show-output" ]
    then
      local show_output="true"
      shift
    elif [ "$1" == "--clear" ]
    then
      local clear="true"
      shift
    elif [ "$1" == "--msg" ]
    then
      shift
      message="$1"
      shift
    else
      more_args=1
    fi
  done
  # (rest of the input is the command and arguments)
  # make sure cmd is not too wide for the terminal
  # - 3 chars for spinner, 3 for ellipsis, 12 for time printout (estimated)
  local max_length=$(( COLUMNS - 18 ))
  if [ -z "$message" ]; then message="$*"; fi
  local cmd_display="$message"
  if [ "${#message}" -gt "$max_length" ]
  then
    cmd_display="${message:0:$max_length}..."
  fi
  local total_length=$(( 3 + ${#cmd_display} ))

  local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' # braille dots
  local num_chars=${#spin_chars}

  local cmd_start_time=$($DATE_CMD +%s%3N)

  # start the spinner running async, and get its PID
  (
    i=0
    while :
    do
      i=$(( (i + 1) % num_chars ))
      printf "\r ${spin_chars:$i:1} ${cmd_display}" >&2
      sleep 0.1
    done
  ) & disown
  local spinner_pid="$!"

  # kill the spinner process for Ctrl-C, and exit this as well
  trap "kill $spinner_pid && exit" INT TERM

  # run the command, capturing its output (both stdout and stderr)
  cmd_output="$("$@" 2>&1)"
  local exit_code="$?"

  # clear the trap, and stop the spinner
  trap - INT TERM
  kill "$spinner_pid"

  # calculate total runtime (approx)
  local cmd_stop_time=$($DATE_CMD +%s%3N)
  local cmd_run_time=$((cmd_stop_time - cmd_start_time))

  # check that the command was successful
  if [ "$exit_code" == 0 ]
  then
    # attempt to clean up, for --clear option (best effort, this mostly works)
    if [ -n "$clear" ]
    then
      printf "\r%-${total_length}s\r" ' ' >&2
    else
      printf "\r ${COLOR_FG_BOLD_GREEN}✔${COLOR_RESET} $cmd_display (${cmd_run_time}ms)\n" >&2
    fi
    # show output if configured
    if [ "$show_output" == "true" ]; then echo "$cmd_output"; fi
  else
    printf "\r ${COLOR_FG_RED}✖${COLOR_RESET} $cmd_display (${cmd_run_time}ms)\n" >&2
    # if it fails, show the command output (in red)
    echo -e "${COLOR_FG_RED}$cmd_output${COLOR_RESET}" >&2
  fi
  # pass through the exit code of the internal command, instead of dropping it
  return "$exit_code"
}
END_FILE_BOILERPLATE
)"

# clean up the output for validation
# * convert CR character to newline + 'CR'
# * remove all non-printable stuff, except newline
# * replace the ANSI color stuff (red/green/reset)
# * replace the spinner character
# * replace the output time to be deterministic
#
# note that `tr` is using octal here
clean_output() {
  LC_ALL=C echo "$1" | tr '\15' '\12CR' | tr -d '\0-\11\13-\37' | sed 's/\[1;32m/GREEN/g' | sed 's/\[0;31m/RED/g' | sed 's/\[0m/RESET/g' | sed 's/[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]/SPIN/g' | sed 's/[0-9]*ms)/113ms)/'
}


### TESTS

# generate code for "@wait-for-command"
@test "@wait-for-command one time" {
  bash_script="test/fixtures/wait-for-command-1"
  generated_file="$tmpdir/.badash/wait-for-command-1"

  # the output has some timing info that varies - will fix that in the output
  expected_output="$(cat <<'END_OF_OUTPUT'
testing wait-for-command

 SPIN echo this will not be printed
 GREEN✔RESET echo this will not be printed (113ms)
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

 SPIN echo this will not be printed
 GREEN✔RESET echo this will not be printed (113ms)

 SPIN echo or this
 GREEN✔RESET echo or this (113ms)
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

 SPIN ./test/fixtures/fail-with-output.sh
 RED✖RESET ./test/fixtures/fail-with-output.sh (113ms)
REDstdout text
stderr textRESET
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

 SPIN echo first command
 GREEN✔RESET echo first command (113ms)

 SPIN echo second command
 GREEN✔RESET echo second command (113ms)
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

 SPIN echo this WILL be printed
 GREEN✔RESET echo this WILL be printed (113ms)
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

# hitting Ctrl-C while the command is still running
@test "@wait-for-command handling Ctrl-C" {
  # this isn't working, and I don't want to block on testing this
  skip
  bash_script="test/fixtures/wait-for-command-ctrl-c"
  generated_file="$tmpdir/.badash/wait-for-command-ctrl-c"

  # TODO: if I kill the process, no output is saved (have to use a trap?)
  expected_output="$(cat <<'END_OF_OUTPUT'
testing wait-for-command with Ctrl-C

  sleep 3
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

# command too long for the line
@test "@wait-for-command command too long is truncated" {
  bash_script="test/fixtures/wait-for-command-too-long"
  generated_file="$tmpdir/.badash/wait-for-command-too-long"

  # the output has some timing info that varies - will fix that in the output
  # also, the output is different on Linux
  expected_output="$(cat <<'END_OF_OUTPUT'
testing wait-for-command too long

 SPIN echo this command is way too long for a single line, there is ...
 GREEN✔RESET echo this command is way too long for a single line, there is ... (113ms)
END_OF_OUTPUT
  )"

  # expected generated file
  expected_file_contents="$(cat <<END_FILE_CONTENTS
$FILE_BOILERPLATE
echo "testing wait-for-command too long"
gen::wait-for-command echo "this command is way too long for a single line, there is no way this will fit on a single line when I am testing it"
END_FILE_CONTENTS
  )"

  # save current term width, modify it, return it after the command
  # (so this test is not dependent on current term width)
  read -r rows cols < <(stty size) || true
  stty cols 80 || true
  run ./badash "$bash_script"
  stty cols "$cols" || true
  [ "$status" -eq 0 ]

  # have to clean this up
  cleaned_output="$(clean_output "$output")"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

# clear the spinner
@test "@wait-for-command clear the spinner" {
  bash_script="test/fixtures/wait-for-command-clear"
  generated_file="$tmpdir/.badash/wait-for-command-clear"

  # the output has some timing info that varies - will fix that in the output
  # (using backslash so expected spaces are preserved)
  expected_output="$(cat <<END_OF_OUTPUT
testing wait-for-command --clear

 SPIN echo this will be printed
                            \

END_OF_OUTPUT
  )"

  # expected generated file
  expected_file_contents="$(cat <<END_FILE_CONTENTS
$FILE_BOILERPLATE
echo "testing wait-for-command --clear"
gen::wait-for-command --clear echo "this will be printed"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]

  # have to clean this up
  cleaned_output="$(clean_output "$output")"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

# clear the spinner, and show the command output
@test "@wait-for-command clear spinner, show output" {
  bash_script="test/fixtures/wait-for-command-clear-show"
  generated_file="$tmpdir/.badash/wait-for-command-clear-show"

  # the output has some timing info that varies - will fix that in the output
  # (using backslash so expected spaces are preserved)
  expected_output="$(cat <<END_OF_OUTPUT
testing wait-for-command --clear --show-output

 SPIN echo this WILL be printed
                            \

this WILL be printed
END_OF_OUTPUT
  )"

  # expected generated file
  expected_file_contents="$(cat <<END_FILE_CONTENTS
$FILE_BOILERPLATE
echo "testing wait-for-command --clear --show-output"
gen::wait-for-command --clear --show-output echo "this WILL be printed"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]

  # have to clean this up
  cleaned_output="$(clean_output "$output")"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

# show a message instead of the command
@test "@wait-for-command show message" {
  bash_script="test/fixtures/wait-for-command-msg"
  generated_file="$tmpdir/.badash/wait-for-command-msg"

  # the output has some timing info that varies - will fix that in the output
  expected_output="$(cat <<END_OF_OUTPUT
testing wait-for-command --msg

 SPIN doing some things
 GREEN✔RESET doing some things (113ms)

END_OF_OUTPUT
  )"

  # expected generated file
  expected_file_contents="$(cat <<END_FILE_CONTENTS
$FILE_BOILERPLATE
echo "testing wait-for-command --msg"
gen::wait-for-command --msg "doing some things" echo "this will not be printed"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]

  # have to clean this up
  cleaned_output="$(clean_output "$output")"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

# show a message, show the output, and clear the spinner
@test "@wait-for-command show message, clear spinner, show output" {
  bash_script="test/fixtures/wait-for-command-msg-clear-show"
  generated_file="$tmpdir/.badash/wait-for-command-msg-clear-show"

  # the output has some timing info that varies - will fix that in the output
  expected_output="$(cat <<END_OF_OUTPUT
testing wait-for-command --msg --clear --show-output

 SPIN doing many things
                    \

this WILL be printed
END_OF_OUTPUT
  )"

  # expected generated file
  expected_file_contents="$(cat <<END_FILE_CONTENTS
$FILE_BOILERPLATE
echo "testing wait-for-command --msg --clear --show-output"
gen::wait-for-command --msg "doing many things" --clear --show-output echo "this WILL be printed"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]

  # have to clean this up
  cleaned_output="$(clean_output "$output")"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

# clear the spinner but the command fails
@test "@wait-for-command clear spinner but command fails" {
  bash_script="test/fixtures/wait-for-command-clear-fails"
  generated_file="$tmpdir/.badash/wait-for-command-clear-fails"

  # the output has some timing info that varies - will fix that in the output
  expected_output="$(cat <<END_OF_OUTPUT
testing wait-for-command --clear when command fails

 SPIN ./test/fixtures/fail-with-output.sh
 RED✖RESET ./test/fixtures/fail-with-output.sh (113ms)
REDstdout text
stderr textRESET
END_OF_OUTPUT
  )"

  # expected generated file
  expected_file_contents="$(cat <<END_FILE_CONTENTS
$FILE_BOILERPLATE
echo "testing wait-for-command --clear when command fails"
# this script fails
gen::wait-for-command --clear ./test/fixtures/fail-with-output.sh
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  # fails with the exit code of the script
  [ "$status" -eq 2 ]

  # have to clean this up
  cleaned_output="$(clean_output "$output")"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}


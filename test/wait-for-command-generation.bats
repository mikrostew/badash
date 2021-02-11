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

  # the output has some timing info that varies - will fix that in the output
  expected_output="$(cat <<'END_OF_OUTPUT'
testing wait-for-command

   running  'echo this will not be printed'
   running  'echo this will not be printed' (113ms) [ OK ]
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash
COLOR_FG_BOLD_GREEN='\033[1;32m'
COLOR_FG_GREEN='\033[0;32m'
COLOR_FG_RED='\033[0;31m'
COLOR_RESET='\033[0m'
if [ "$(uname -s)" == 'Darwin' ]; then DATE_CMD=gdate; else DATE_CMD=date; fi
# show a busy spinner while command is running
# and only show output if there is an error
gen::wait-for-command() {
  # input is a command array
  local cmd_string="$@"

  # calculate things for the output
  local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' # braille dots
  local num_chars=${#spin_chars}
  local total_length=$(( 2 + ${#cmd_string} ))

  # run the command async, and capture the PID
  local cmd_start_time=$($DATE_CMD +%s%3N)
  exec 3< <("$@" 2>&1)
  local cmd_pid="$!"

  # wait for the command to complete, showing a busy spinner
  i=0
  while kill -0 $cmd_pid 2>/dev/null
  do
    i=$(( (i + 1) % num_chars ))
    printf "\r${spin_chars:$i:1} ${COLOR_FG_BOLD_GREEN}running${COLOR_RESET} '${cmd_string}'" >&2
    sleep 0.1
  done
  # calculate total runtime (approx)
  local cmd_stop_time=$($DATE_CMD +%s%3N)
  local cmd_run_time=$((cmd_stop_time - cmd_start_time))

  # get the exit code of that process
  wait $cmd_pid
  local exit_code="$?"

  # TODO: attempt to clean up, depending on option (doesn't always work)
  # but still check if it failed?
  #printf "\r%-${total_length}s\r" ' ' >&2

  printf "\r  ${COLOR_FG_BOLD_GREEN}running${COLOR_RESET} '$cmd_string' (${cmd_run_time}ms)" >&2

  # check that the command was successful
  if [ "$exit_code" == 0 ]
  then
    printf " [${COLOR_FG_GREEN}OK${COLOR_RESET}]\n"
  else
    printf " [${COLOR_FG_RED}ERROR${COLOR_RESET}]\n"
    # if it fails, show the command output
    cat <&3
  fi
}
echo "testing wait-for-command"
gen::wait-for-command echo "this will not be printed"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]

  # convert CR to newline
  # remove all non-printable stuff except newline
  # clean up the ANSI color stuff
  # remove the spinner character
  # replace the output time to match expected
  # (note that `tr` is using octal here)
  cleaned_output="$(LC_ALL=C echo "$output" | tr '\15' '\12' | tr '\0-\11\13-\37' '[ *]' | sed 's/\[[0-9;]*m//g' | sed 's/[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]/ /g' | sed 's/[0-9]*ms/113ms/')"

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
   running  'echo this will not be printed' (113ms) [ OK ]

   running  'echo or this'
   running  'echo or this' (113ms) [ OK ]
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash
COLOR_FG_BOLD_GREEN='\033[1;32m'
COLOR_FG_GREEN='\033[0;32m'
COLOR_FG_RED='\033[0;31m'
COLOR_RESET='\033[0m'
if [ "$(uname -s)" == 'Darwin' ]; then DATE_CMD=gdate; else DATE_CMD=date; fi
# show a busy spinner while command is running
# and only show output if there is an error
gen::wait-for-command() {
  # input is a command array
  local cmd_string="$@"

  # calculate things for the output
  local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' # braille dots
  local num_chars=${#spin_chars}
  local total_length=$(( 2 + ${#cmd_string} ))

  # run the command async, and capture the PID
  local cmd_start_time=$($DATE_CMD +%s%3N)
  exec 3< <("$@" 2>&1)
  local cmd_pid="$!"

  # wait for the command to complete, showing a busy spinner
  i=0
  while kill -0 $cmd_pid 2>/dev/null
  do
    i=$(( (i + 1) % num_chars ))
    printf "\r${spin_chars:$i:1} ${COLOR_FG_BOLD_GREEN}running${COLOR_RESET} '${cmd_string}'" >&2
    sleep 0.1
  done
  # calculate total runtime (approx)
  local cmd_stop_time=$($DATE_CMD +%s%3N)
  local cmd_run_time=$((cmd_stop_time - cmd_start_time))

  # get the exit code of that process
  wait $cmd_pid
  local exit_code="$?"

  # TODO: attempt to clean up, depending on option (doesn't always work)
  # but still check if it failed?
  #printf "\r%-${total_length}s\r" ' ' >&2

  printf "\r  ${COLOR_FG_BOLD_GREEN}running${COLOR_RESET} '$cmd_string' (${cmd_run_time}ms)" >&2

  # check that the command was successful
  if [ "$exit_code" == 0 ]
  then
    printf " [${COLOR_FG_GREEN}OK${COLOR_RESET}]\n"
  else
    printf " [${COLOR_FG_RED}ERROR${COLOR_RESET}]\n"
    # if it fails, show the command output
    cat <&3
  fi
}
echo "testing wait-for-command"
gen::wait-for-command echo "this will not be printed"
gen::wait-for-command echo "or this"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]

  # convert CR to newline
  # remove all non-printable stuff except newline
  # clean up the ANSI color stuff
  # remove the spinner character
  # replace the output time to match expected
  # (note that `tr` is using octal here)
  cleaned_output="$(LC_ALL=C echo "$output" | tr '\15' '\12' | tr '\0-\11\13-\37' '[ *]' | sed 's/\[[0-9;]*m//g' | sed 's/[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]/ /g' | sed 's/[0-9]*ms/113ms/g')"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}

# when the command fails
@test "@wait-for-command command fails" {
  bash_script="test/fixtures/wait-for-command-fail"
  generated_file="$tmpdir/.badash/wait-for-command-fail"

  # the output has some timing info that varies - will fix that in the output
  expected_output="$(cat <<'END_OF_OUTPUT'
testing wait-for-command

   running  'mkdir -W -R -O -N -G ok'
   running  'mkdir -W -R -O -N -G ok' (113ms) [ ERROR ]
mkdir: illegal option -- W
usage: mkdir [-pv] [-m mode] directory ...
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash
COLOR_FG_BOLD_GREEN='\033[1;32m'
COLOR_FG_GREEN='\033[0;32m'
COLOR_FG_RED='\033[0;31m'
COLOR_RESET='\033[0m'
if [ "$(uname -s)" == 'Darwin' ]; then DATE_CMD=gdate; else DATE_CMD=date; fi
# show a busy spinner while command is running
# and only show output if there is an error
gen::wait-for-command() {
  # input is a command array
  local cmd_string="$@"

  # calculate things for the output
  local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' # braille dots
  local num_chars=${#spin_chars}
  local total_length=$(( 2 + ${#cmd_string} ))

  # run the command async, and capture the PID
  local cmd_start_time=$($DATE_CMD +%s%3N)
  exec 3< <("$@" 2>&1)
  local cmd_pid="$!"

  # wait for the command to complete, showing a busy spinner
  i=0
  while kill -0 $cmd_pid 2>/dev/null
  do
    i=$(( (i + 1) % num_chars ))
    printf "\r${spin_chars:$i:1} ${COLOR_FG_BOLD_GREEN}running${COLOR_RESET} '${cmd_string}'" >&2
    sleep 0.1
  done
  # calculate total runtime (approx)
  local cmd_stop_time=$($DATE_CMD +%s%3N)
  local cmd_run_time=$((cmd_stop_time - cmd_start_time))

  # get the exit code of that process
  wait $cmd_pid
  local exit_code="$?"

  # TODO: attempt to clean up, depending on option (doesn't always work)
  # but still check if it failed?
  #printf "\r%-${total_length}s\r" ' ' >&2

  printf "\r  ${COLOR_FG_BOLD_GREEN}running${COLOR_RESET} '$cmd_string' (${cmd_run_time}ms)" >&2

  # check that the command was successful
  if [ "$exit_code" == 0 ]
  then
    printf " [${COLOR_FG_GREEN}OK${COLOR_RESET}]\n"
  else
    printf " [${COLOR_FG_RED}ERROR${COLOR_RESET}]\n"
    # if it fails, show the command output
    cat <&3
  fi
}
echo "testing wait-for-command"
# this should always fail
gen::wait-for-command mkdir -W -R -O -N -G "ok"
END_FILE_CONTENTS
  )"

  run ./badash "$bash_script"
  # don't test this, since I am expecting it to fail
  #[ "$status" -eq 0 ]

  # convert CR to newline
  # remove all non-printable stuff except newline
  # clean up the ANSI color stuff
  # remove the spinner character
  # replace the output time to match expected
  # (note that `tr` is using octal here)
  cleaned_output="$(LC_ALL=C echo "$output" | tr '\15' '\12' | tr '\0-\11\13-\37' '[ *]' | sed 's/\[[0-9;]*m//g' | sed 's/[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]/ /g' | sed 's/[0-9]*ms/113ms/g')"

  diff <(echo "$cleaned_output") <(echo "$expected_output")
  diff "$generated_file" <(echo "$expected_file_contents")
}


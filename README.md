# badash

Convenience methods, modular imports, and other fun stuff for bash

[Installation](#installation)
[Syntax](#syntax)
* [@exit_on_error](#exit_on_error)
* [@wait-for-command](#wait-for-command)
* [@wait_for_keypress](#wait_for_keypress)

## Installation

```
cd /usr/local/lib/
git clone git@github.com:mikrostew/badash.git
ln -s /usr/local/lib/badash/badash /usr/local/bin/badash
```

## Syntax

### @exit_on_error

`@exit_on_error "message if this fails" ['code to run before exit']`

(convenience method) Check the exit code of the command that just completed, and exit with an error message if it failed. Optionally run some code before exiting.

Example:

```bash
#!/usr/bin/env badash
git checkout master
git merge "$some_branch"
@exit_on_error "Failed to merge '$some_branch' to master!"
```

<details>
  <summary>What that compiles to</summary>

```bash
#!/usr/bin/env bash
git checkout master
git merge "$some_branch"
exit_code="$?"
if [ "$exit_code" -ne 0 ]
then
  echo "Failed to merge '$some_branch' to master!" >&2
  exit "$exit_code"
fi
```
</details>

You can also specify a line of code to run before exiting, if you need to clean up anything.

Example:

```bash
#!/usr/bin/env badash
git checkout master
git merge "$some_branch"
@exit_on_error "Failed to merge '$some_branch' to master!" 'git undo-merge-somehow'
```

<details>
  <summary>What that compiles to</summary>

```bash
#!/usr/bin/env bash
git checkout master
git merge "$some_branch"
exit_code="$?"
if [ "$exit_code" -ne 0 ]
then
  echo "Failed to merge '$some_branch' to master!" >&2
  git undo-merge-somehow
  exit "$exit_code"
fi
```
</details>

### @wait-for-command

`@wait-for-command command to run`

(convenience method) Wait for a long-running command to finish, displaying a spinner while it runs. Show the output only on error.

Example:

```bash
#!/usr/bin/env badash
@wait-for-command brew update
```

<details>
  <summary>What that compiles to</summary>

```bash
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
gen::wait-for-command brew update
```
</details>


### @wait_for_keypress

`@wait_for_keypress 'Message to prompt the user'`

(convenience method) Wait for the user to press a key to continue execution of the script.

Example:

```bash
#!/usr/bin/env badash
@wait_for_keypress 'Press a key to continue...'
```

<details>
  <summary>What that compiles to</summary>

```bash
#!/usr/bin/env bash
echo -n 'Press a key to continue...'
read -n1 -s
```
</details>

### system_is_*

TODO


## Development

### Tests

To run the tests, install [bats-core](https://github.com/bats-core/bats-core), and run this command from the top-level project directory:

```
bats test/
```

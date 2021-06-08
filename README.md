# badash

Convenience methods, modular imports, and other fun stuff for bash

[Installation](#installation)

[Convenience Methods](#convenience-methods)
* [@exit-on-error](#exit-on-error)
* [@wait-for-command](#wait-for-command)
* [@wait-for-keypress](#wait-for-keypress)

[Tests and Checks](#tests-and-checks)
* [@system-is-\*](#system-is-)
* [@uses-cmds](#uses-cmds)

[Development](#development)

# Installation

(you may need to make `/usr/local/lib` and `/usr/local/bin` writeable first)

```
cd /usr/local/lib/
git clone git@github.com:mikrostew/badash.git
ln -s /usr/local/lib/badash/badash /usr/local/bin/badash
```

# Convenience Methods

## @exit-on-error

`@exit-on-error "message if this fails" ['code to run before exit']`

Check the exit code of the command that just completed, and exit with an error message if it failed. Optionally run some code before exiting.

Example:

```bash
#!/usr/bin/env badash
git checkout master
git merge "$some_branch"
@exit-on-error "Failed to merge '$some_branch' to master!"
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
@exit-on-error "Failed to merge '$some_branch' to master!" 'git undo-merge-somehow'
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


## @wait-for-command

`@wait-for-command [options] command to run`

Wait for a long-running command to finish, displaying a spinner while it runs. Show the output only on error, passing the exit code through.

**Options**

`--show-output` By default, command output is hidden unless it returns an error code. This option will also show the command output if the command is successful.

`--hide-args` By default, the command and all arguments are shown in the spinner text. This option hides the arguments, and replaces them with `[args hidden]`.

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
}
gen::wait-for-command brew update
```
</details>


## @wait-for-keypress

`@wait-for-keypress 'Message to prompt the user'`

Wait for the user to press a key to continue execution of the script.

Example:

```bash
#!/usr/bin/env badash
@wait-for-keypress 'Press a key to continue...'
```

<details>
  <summary>What that compiles to</summary>

```bash
#!/usr/bin/env bash
echo -n 'Press a key to continue...'
read -n1 -s
```
</details>


# Tests and Checks

## @system-is-*

`@system-is-<uname-string>`

Test the uname string of the current system. This is case insensitive, so `@system-is-darwin` == `@system-is-Darwin`.

Example:

```bash
#!/usr/bin/env badash
if @system-is-darwin
then
  echo "we're on Mac!"
elif @system-is-linux
then
  echo "we're on Linux!"
else
  echo "unknown system!!"
fi
```

<details>
  <summary>What that compiles to</summary>

```bash
#!/usr/bin/env bash
if [ "$(uname -s | tr '[:upper:]' '[:lower:]')" == "darwin" ]
then
  echo "we're on Mac!"
elif [ "$(uname -s | tr '[:upper:]' '[:lower:]')" == "linux" ]
then
  echo "we're on Linux!"
else
  echo "unknown system!!"
fi
```
</details>


## @uses-cmds

`@uses-cmds [system/]command [[system/]command] ... `

Check that commands exist before using them. Can be comma or space delimited, and you can specify a certain system to check.

Example:

```bash
#!/usr/bin/env badash
@uses-cmds git jq Linux/date Darwin/gdate

git status
echo '{"some":"JSON"}' | jq '.'

# show the current date
if [ "$(uname -s)" == "Darwin" ]
then
  gdate
else
  date
fi
```

<details>
  <summary>What that compiles to</summary>

```bash
#!/usr/bin/env bash
gen::req-check() {
  if [ ! $(command -v $2) ]; then
    echo "test-compile: Required command '$2' not found" >&2
    printf -v "$1" "1"
  fi
}
_gen_cmd_check_rtn=0
[ "$(uname -s)" == 'Darwin' ] && gen::req-check _gen_cmd_check_rtn gdate
[ "$(uname -s)" == 'Linux' ] && gen::req-check _gen_cmd_check_rtn date
gen::req-check _gen_cmd_check_rtn git
gen::req-check _gen_cmd_check_rtn jq
if [ "$_gen_cmd_check_rtn" != 0 ]; then exit $_gen_cmd_check_rtn; fi

git status
echo '{"some":"JSON"}' | jq '.'

# show the current date
if [ "$(uname -s)" == "Darwin" ]
then
  gdate
else
  date
fi
```
</details>



# Development

## Tests

To run the tests, install [bats-core](https://github.com/bats-core/bats-core), and run this command from the top-level project directory:

```
bats test/
```

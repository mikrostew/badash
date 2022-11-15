#!/usr/bin/env bash

# install this repo and symlink the badash script

REPO_URL="https://github.com/mikrostew/badash.git"

COLOR_FG_BOLD_GREEN='\033[1;32m'
COLOR_FG_RED='\033[0;31m'
COLOR_RESET='\033[0m'

COLUMNS="$(if [ -z "$TERM" ] || [ "$TERM" = "dumb" ] || [ "$TERM" = "unknown" ]; then echo 80; else tput cols; fi)"

# figure out the directory where this script is located
SCRIPT_FILE="$( [ -L "$0" ] && readlink "$0" || echo "$0" )"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_FILE")" &>/dev/null && pwd)"

# show a busy spinner while command is running
# and only show output if there is an error
_wait-for-command() {
  # make sure cmd is not too wide for the terminal
  # - 3 chars for spinner, 3 for ellipsis, 2 for spacing
  local max_length=$(( COLUMNS - 8 ))
  local message="$*"
  if [ "${#message}" -gt "$max_length" ]; then
    cmd_display="${message:0:$max_length}..."
  else
    cmd_display="$message"
  fi
  local total_length=$(( 3 + ${#cmd_display} ))

  local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' # braille dots
  local num_chars=${#spin_chars}

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

  # check that the command was successful
  if [ "$exit_code" == 0 ]
  then
    # write a final display with check mark for success
    printf "\r ${COLOR_FG_BOLD_GREEN}✔${COLOR_RESET} $cmd_display\n" >&2
  else
    printf "\r ${COLOR_FG_RED}✖${COLOR_RESET} $cmd_display\n" >&2
    # if it fails, show the command output (in red)
    echo -e "${COLOR_FG_RED}$cmd_output${COLOR_RESET}" >&2
  fi
  # pass through the exit code of the internal command, instead of dropping it
  return "$exit_code"
}

# show an animated prompt while waiting for input
_prompt-for-input() {
  # arguments:
  # - prompt string
  # - variable to store user input
  prompt_str="$1"
  read_var_name="$2"

  local prompt_animation=( ">  " " > " "  >" " > " )
  local num_frames=${#prompt_animation[@]}

  # echo the prompt
  printf "\r%s %s " "${prompt_animation[0]}" "$prompt_str"

  # start the animation running async, and get its PID
  (
    i=0
    while :
    do
      printf "\r%s %s " "${prompt_animation[$i]}" "$prompt_str" >&2
      sleep 0.2
      i=$(( (i + 1) % num_frames ))
    done
  ) & disown
  local animation_pid="$!"

  # kill the animation process for Ctrl-C, cleanup, and return failure
  trap "kill $animation_pid && echo "" && return 1" INT TERM

  # read input from the user
  read -r "${read_var_name?}"

  # clear the trap, and stop the spinner
  trap - INT TERM
  kill "$animation_pid"

  # sometimes a duplicate line will be printed
  # (race condition with killing the spawned process)
  # so clean that up if it happens
  printf "\r    %-${#total_length}s\r" ' ' >&2

  return 0
}

# if the previous command returned non-zero, exit after printing a message
_exit-on-error() {
  if [ "$?" -ne 0 ]; then echo "$1"; exit 1; fi
}

# defaults
# (TODO: make these configurable, if it makes sense)
# where to install this
prefix_dir=/usr/local
# install from a local checkout of the repo instead of github
local_install="no"

# script options
while [ "$#" -gt 0 ]
do
  case "$1" in
    --local)
      local_install="yes"
      shift
      ;;
    *)
      echo "Unknown argument '$1'"
      exit 1
      ;;
  esac
done

install_dir="$prefix_dir/lib/badash"
bin_dir="$prefix_dir/bin"
bin_path="$bin_dir/badash"
installed_bin_path="$install_dir/badash"
symlink_action=""

# check the symlink first

if [ -L "$bin_path" ]
then
  # if the symlink exists, make sure it points to the right location
  link_target="$(readlink "$bin_path")"
  if [ "$link_target" != "$installed_bin_path" ]
  then
    _prompt-for-input "Existing symlink points to '$link_target' - replace it? [y/N]" replace_confirm
    _exit-on-error "(not installing)" # got Ctrl-C
    symlink_action="replace"
  else
    # if the symlink already points to this repo, nothing to do
    symlink_action="nothing"
  fi
elif [ -f "$bin_path" ]
then
  # if a file exists there, this is not going to work
  echo "Failed: '$bin_path' is a file - can't create a symlink there"
  exit 1
else
  # no symlink there, will have to create one
  symlink_action="create"
fi

if [ -d "$install_dir" ]
then
  _prompt-for-input "Dir '$install_dir' exists - replace it? [y/N]" replace_confirm
  _exit-on-error "(not installing)" # got Ctrl-C

  if [ "$replace_confirm" == "Y" ] || [ "$replace_confirm" == "y" ]
  then
    # dir exists, so clone to temp dir first, before deleting original dir
    # (probably good enough to use PID of this script to make a unique dir entry)
    temp_checkout_dir="$install_dir-$$"
    if [ "$local_install" == "yes" ]
    then
      _wait-for-command cp -R "$SCRIPT_DIR" "$temp_checkout_dir"
      _exit-on-error "Failed: could not copy the repo from '$SCRIPT_DIR' to '$temp_checkout_dir'"
    else
      _wait-for-command git clone "$REPO_URL" "$temp_checkout_dir"
      _exit-on-error "Failed: could not clone the repo to '$temp_checkout_dir'"
    fi
    _wait-for-command rm -rf "$install_dir"
    _exit-on-error "Failed: could not remove the existing dir '$install_dir'"
    _wait-for-command mv "$temp_checkout_dir" "$install_dir"
    _exit-on-error "Failed: could not rename the temp dir from '$temp_checkout_dir' --> '$install_dir'"
  else
    echo "(not installing)"
    exit 1
  fi
else
  # the dir doesn't exist, so clone it directly there
  _wait-for-command git clone "$REPO_URL" "$install_dir"
  _exit-on-error "Failed: could not clone the repo to '$install_dir'"
fi

# do the symlink, if necessary
case "$symlink_action" in
  replace)
    _wait-for-command rm "$bin_path"
    _wait-for-command ln -s "$installed_bin_path" "$bin_path"
    ;;
  create)
    _wait-for-command ln -s "$installed_bin_path" "$bin_path"
    ;;
  nothing)
    echo -e " ${COLOR_FG_BOLD_GREEN}✔${COLOR_RESET} (symlink already exists)"
    ;;
  *)
    echo -e " ${COLOR_FG_RED}✖${COLOR_RESET} Failed to symlink - unknown action '$symlink_action'"
    exit 1
    ;;
esac

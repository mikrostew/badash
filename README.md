# badash

Convenience methods, modular imports, and other fun stuff for bash

Syntax
* [@exit_on_error](#exit_on_error)
* [@wait_for_keypress](#wait_for_keypress)

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

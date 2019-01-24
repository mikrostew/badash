# badash

Modular imports and other fun stuff for bash

## Syntax

### @exit_on_error

This is a convenience method to check the exit code of the command that just completed, and exit with an error message if it failed.

For example:

```bash
git checkout master
git merge "$some_branch"
@exit_on_error "Failed to merge '$some_branch' to master!"
```

compiles to:

```bash
git checkout master
git merge "$some_branch"
exit_code="$?"
if [ "$exit_code" -ne 0 ]
then
  echo "Failed to merge '$some_branch' to master!" >&2
  exit "$exit_code"
fi
```

You can also specify a line of code to run before exiting, if you need to clean up anything.

For example:

```bash
git checkout master
git merge "$some_branch"
@exit_on_error "Failed to merge '$some_branch' to master!" 'git undo-merge-somehow'
```

compiles to:

```bash
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


### system_is_*

TODO


## Development

### Tests

To run the tests, install [bats-core](https://github.com/bats-core/bats-core), and run this command from the top-level project directory:

```
bats test/
```

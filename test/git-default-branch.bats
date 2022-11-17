#!/usr/bin/env bats

# set HOME to isolate these tests
setup() {
  tmpdir="$(mktemp -d /tmp/badash.test.XXXXXX)"
  HOME="$tmpdir"
}

teardown() {
  rm -rf "$tmpdir"
}

compare_file_contents() {
  local generated="$1"
  local expected="$2"

  # cleanup the non-deterministic contents in the "Generated from ..." line
  local cleaned_gen_file="$(echo "$1" | sed "s/# Generated from '.*', [0-9-]* [0-9:]*/# Generated from '', 1234-56-78 12:34:56/g")"

  if [ "$cleaned_gen_file" != "$expected" ]
  then
    echo ""
    echo "Error: generated file does not match expected"
    echo ""
    echo "Expected:"
    echo "'$expected'"
    echo ""
    echo "Generated (cleaned):"
    echo "'$cleaned_gen_file'"
    echo ""
    echo "Diff:"
    diff <(echo "$cleaned_gen_file") <(echo "$expected")
    echo ""
  fi
}

# generate code for "@git-default-branch"
@test "@git-default-branch" {
  bash_script="test/fixtures/git-default-branch"
  generated_file="$tmpdir/.badash/git-default-branch"

  expected_output="$(cat <<'END_OF_OUTPUT'
git branch things
master
END_OF_OUTPUT
  )"

  expected_file_contents="$(cat <<'END_FILE_CONTENTS'
#!/usr/bin/env bash
# Generated from '', 1234-56-78 12:34:56
gen::echo-err() {
  echo -e "\033[0;31m$*\033[0m" >&2
}
echo "git branch things"
# spaced to test that the padding is correct
   if git show-ref --verify --quiet refs/heads/main
   then
     some_default_branch='main'
   elif git show-ref --verify --quiet refs/heads/master
   then
     some_default_branch='master'
   else
     gen::echo-err "Error: default branch is not 'main' or 'master'"
     exit 1
   fi
echo "$some_default_branch"
END_FILE_CONTENTS
  )"

  # need to simulate input in stdin so this test doesn't hang
  run ./badash "$bash_script"
  [ "$status" -eq 0 ]
  diff <(echo "$output") <(echo "$expected_output")
  compare_file_contents "$(<$generated_file)" "$expected_file_contents"
}

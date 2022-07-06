#!/usr/bin/env bats

# set HOME to isolate these tests
# TODO: refactor these functions to something that is loaded?
setup() {
  tmpdir="$(mktemp -d /tmp/badash.test.XXXXXX)"
  HOME="$tmpdir"
}

teardown() {
  rm -rf "$tmpdir"
}

compare_file_contents_notime() {
  local generated="$1"
  local expected="$2"

  # cleanup the timestamp in the "Generated from ..." line
  local cleaned_gen_file="$(echo "$1" | sed "s/, [0-9-]* [0-9:]*/, 1234-56-78 12:34:56/g")"

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

@test "regular file" {
  bash_script="$tmpdir/script-file"
  generated_file="$tmpdir/.badash/script-file"

  # the tmpdir often uses a symlink, so adjust that
  tmp_nosymlink="$(cd "$tmpdir" >/dev/null; pwd -P)"

  cat <<'END_OF_SCRIPT_FILE' >"$bash_script"
#!/usr/bin/env badash
echo "script name: @@SCRIPT_NAME@@"
echo "script dir: @@SCRIPT_DIR@@"
END_OF_SCRIPT_FILE

  expected_output="$(cat <<END_OF_OUTPUT
script name: script-file
script dir: $tmp_nosymlink
END_OF_OUTPUT
)"

  run ./badash "$bash_script"
  [ "$status" -eq 0 ]
  [ "$output" == "$expected_output" ]
  # check the generated file
  expected_contents="$(cat <<END_OF_GEN_CODE
#!/usr/bin/env bash
# Generated from '$tmp_nosymlink/script-file', 1234-56-78 12:34:56
echo "script name: script-file"
echo "script dir: $tmp_nosymlink"
END_OF_GEN_CODE
  )"
  compare_file_contents_notime "$(<$generated_file)" "$expected_contents"
}

@test "symlink" {
  bash_script="$tmpdir/script-file"
  mkdir -p "$tmpdir/bin"
  script_symlink="$tmpdir/bin/script-link"
  generated_file="$tmpdir/.badash/script-file"
  ln -s "$bash_script" "$script_symlink"

  # the tmpdir often uses a symlink, so adjust that
  tmp_nosymlink="$(cd "$tmpdir" >/dev/null; pwd -P)"

  cat <<'END_OF_SCRIPT_FILE' >"$bash_script"
#!/usr/bin/env badash
echo "script name: @@SCRIPT_NAME@@"
echo "script dir: @@SCRIPT_DIR@@"
END_OF_SCRIPT_FILE

  expected_output="$(cat <<END_OF_OUTPUT
script name: script-file
script dir: $tmp_nosymlink
END_OF_OUTPUT
)"

  run ./badash "$script_symlink"
  [ "$status" -eq 0 ]
  [ "$output" == "$expected_output" ]

  # check the generated file
  expected_contents="$(cat <<END_OF_GEN_CODE
#!/usr/bin/env bash
# Generated from '$tmp_nosymlink/script-file', 1234-56-78 12:34:56
echo "script name: script-file"
echo "script dir: $tmp_nosymlink"
END_OF_GEN_CODE
  )"
  compare_file_contents_notime "$(<$generated_file)" "$expected_contents"
}

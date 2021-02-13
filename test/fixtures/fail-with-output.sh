#!/usr/bin/env bash
# Output some text on stdout and stderr, then fail

echo "stdout text"
echo "stderr text" >&2

exit 1

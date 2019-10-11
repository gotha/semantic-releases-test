#!/usr/bin/env bash

REQUIRED_COMMANDS="git hub awk"

for i in $REQUIRED_COMMANDS; do
  if command -v "$i" >/dev/null 2>&1; then
    echo "$i found"
  else
    echo "$i not found; you must install it first"
    exit 1
  fi
done

echo "All good; Ready to use"

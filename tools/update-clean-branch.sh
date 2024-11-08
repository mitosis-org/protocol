#!/bin/bash

git add .

set +e # Grep succeeds with nonzero exit codes to show results.
git status | grep modified
if [ $? -eq 0 ]; then
    set -e
    git commit -m "cleaned $1"
    git push
else
    set -e
    echo "No changes since last run"
fi

#!/bin/bash

gitTag=$(git describe --tags --abbrev=0 origin/main)
gitCommit=$(git rev-parse origin/main)

mkdir -p temp 
cp -r src temp 
cp foundry.toml temp/src

sed \
  -e "s/{{git_tag}}/$gitTag/g" \
  -e "s/{{git_commit}}/$gitCommit/g" \
  temp/src/lib/Versioned.sol > temp/src/lib/Versioned.sol.tmp

mv temp/src/lib/Versioned.sol.tmp temp/src/lib/Versioned.sol

# ignore errors and continue to rm -rf temp
forge soldeer push mitosis~$(echo $gitTag | sed 's/^v//') temp/src || true

rm -rf temp

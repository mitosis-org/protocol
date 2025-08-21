#!/bin/bash

mkdir -p temp 
cp -r src temp 
cp foundry.toml temp/src

sed \
  -e "s/{{git_tag}}/$(git describe --abbrev=0 --tags origin/main)/g" \
  -e "s/{{git_commit}}/$(git rev-parse origin/main)/g" \
  temp/src/lib/Versioned.sol > temp/src/lib/Versioned.sol.tmp

mv temp/src/lib/Versioned.sol.tmp temp/src/lib/Versioned.sol

# ignore errors and continue to rm -rf temp
forge soldeer push mitosis~$(git describe --abbrev=0 --tags origin/main) temp/src || true

rm -rf temp

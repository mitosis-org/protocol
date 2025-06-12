#!/bin/bash

version=$(git describe --tags --abbrev=0)
commit=$(git rev-parse HEAD)

echo "Generating Versioned.sol..."

rm -f $PWD/src/lib/Versioned.sol
sed -e "s/{{version}}/$version/g" -e "s/{{commit}}/$commit/g" $PWD/tools/Versioned.tmpl >$PWD/src/lib/Versioned.sol

forge fmt ./src/lib/Versioned.sol

echo "Versioned.sol generated successfully."

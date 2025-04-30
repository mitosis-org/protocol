#!/bin/bash

set -e # exit on error

rm -rf coverage
mkdir -p coverage

# generates lcov.info
forge coverage --report lcov --report-file coverage/lcov.info -vvv

# Filter out node_modules, test, and mock files
lcov \
    --rc derive_function_end_line=0 \
    --remove coverage/lcov.info \
    --output-file coverage/filtered-lcov.info \
    --ignore-errors unused \
    --ignore-errors inconsistent \
    "*dependencies*" "*test*" "*script*" "*src/external*"

rm coverage/lcov.info
mv coverage/filtered-lcov.info coverage/lcov.info

# Generate summary
lcov \
    --rc derive_function_end_line=0 \
    --list coverage/lcov.info

# Open more granular breakdown in browser
if [ "$CI" != "true" ]; then
    genhtml \
        --rc derive_function_end_line=0 \
        --output-directory coverage \
        --ignore-errors unused \
        --ignore-errors inconsistent \
        coverage/lcov.info
    open coverage/index.html
fi

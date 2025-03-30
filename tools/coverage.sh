set -e # exit on error

# generates lcov.info
forge coverage --report lcov -vvv

# Filter out node_modules, test, and mock files
lcov \
    --rc derive_function_end_line=0 \
    --remove lcov.info \
    --output-file filtered-lcov.info \
    --ignore-errors unused \
    --ignore-errors inconsistent \
    "*dependencies*" "*test*" "*script*" "*src/external*"

rm lcov.info
mv filtered-lcov.info lcov.info

# Generate summary
lcov \
    --rc derive_function_end_line=0 \
    --list lcov.info

# Open more granular breakdown in browser
if [ "$CI" != "true" ]; then
    genhtml \
        --rc derive_function_end_line=0 \
        --output-directory coverage \
        --ignore-errors unused \
        --ignore-errors inconsistent \
        lcov.info
    open coverage/index.html
fi

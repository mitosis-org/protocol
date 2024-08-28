set -e # exit on error

# generates lcov.info
forge coverage --report lcov -vvv

# Filter out node_modules, test, and mock files
lcov \
    --rc branch_coverage=1 \
    --remove lcov.info \
    --output-file filtered-lcov.info \
    --ignore-errors unused \
    "*dependencies*" "*test*" "*mock*" "*script*"

rm lcov.info
mv filtered-lcov.info lcov.info

# Generate summary
lcov \
    --rc branch_coverage=1 \
    --list lcov.info

# Open more granular breakdown in browser
if [ "$CI" != "true" ]; then
    genhtml \
        --rc branch_coverage=1 \
        --output-directory coverage \
        lcov.info
    open coverage/index.html
fi

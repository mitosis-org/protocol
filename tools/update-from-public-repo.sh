#!/usr/bin/env bash

for FILE in $(cat ./public-files.txt)
do
    echo "Copying ${FILE}"
    mkdir -p $(dirname "${FILE}") && cp -rf "../protocol-public/${FILE}" "${FILE}"
done

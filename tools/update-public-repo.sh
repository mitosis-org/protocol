#!/usr/bin/env bash

for FILE in $(cat ./public-files.txt)
do
    echo "Copying ${FILE}"
    mkdir -p $(dirname "../protocol-public/${FILE}") && cp -rf "${FILE}" "../protocol-public/${FILE}"
done

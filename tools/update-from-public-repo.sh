#!/usr/bin/env bash

for FILE in $(cat ./public-files.txt)
do
    echo "Copying ${FILE}"
    cp "../protocol-public/${FILE}" "${FILE}"
done

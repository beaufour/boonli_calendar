#!/bin/bash
files="main.py requirements.txt boonli_calendar/*.py"
zip_name=function-source.zip

echo Generating requirements.txt
poetry export > requirements.txt

echo Building
rm -f ${zip_name}
zip ${zip_name} ${files}

echo Cleaning up
rm requirements.txt

#!/bin/sh

LOG_FILE=$1

for STATUS in PASS FAIL SKIP ERROR
do
  echo "${STATUS}: $(grep $STATUS $LOG_FILE | grep -v ' -- : ' | wc -l)"
done

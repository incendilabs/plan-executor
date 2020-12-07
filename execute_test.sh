#!/bin/sh

set -e

FHIR_ENDPOINT_URL=$1
FHIR_VERSION=$2
TEST=$3

bundle exec rake crucible:execute[$FHIR_ENDPOINT_URL,$FHIR_VERSION,$3,,true] > logs/execute_$TEST.log 2>&1

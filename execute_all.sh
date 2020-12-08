#!/bin/sh

set -e

FHIR_ENDPOINT_URL=$1
FHIR_VERSION=$2
TEST_OUTPUT=$3

bundle exec rake crucible:execute_all[$FHIR_ENDPOINT_URL,$FHIR_VERSION,$TEST_OUTPUT] > logs/execute_all.log 2>&1



#!/bin/sh

set -e

FHIR_ENDPOINT_URL=$1
FHIR_VERSION=$2
TEST=$3
TEST_OUTPUT=$4

bundle exec rake crucible:execute[$FHIR_ENDPOINT_URL,$FHIR_VERSION,$TEST,,$TEST_OUTPUT]

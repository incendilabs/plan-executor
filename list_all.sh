#!/bin/sh

set -e

FHIR_VERSION=$1

bundle exec rake crucible:list_all[$FHIR_VERSION]

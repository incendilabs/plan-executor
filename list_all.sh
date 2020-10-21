#!/bin/sh

FHIR_VERSION=$1

bundle exec rake crucible:list_all[$FHIR_VERSION] > logs/list_all.log 2>&1

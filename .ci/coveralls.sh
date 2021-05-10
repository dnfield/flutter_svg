#!/bin/bash

set -x

if [[ -z $COVERALLS_REPO_TOKEN ]]; then
  echo "Skipping coveralls, user not authorized"
  exit 0
fi

dart pub global activate coveralls
dart pub global run coveralls coverage/lcov.info

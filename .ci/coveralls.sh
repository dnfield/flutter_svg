#!/bin/bash

set -x

if [[ $COVERALLS_REPO_TOKEN == ENCRYPTED* ]]; then
  echo "Skipping coveralls, user not authorized"
  exit 0
fi

dart pub global activate coveralls
dart pub global run coveralls coverage/lcov.info

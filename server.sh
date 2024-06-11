#!/usr/bin/env bash
set -e
cd $(dirname "${BASH_SOURCE[0]}")

if [[ "$RUNNER_DEBUG" == "1" ]]; then
  set -x
fi

OPERATION=$1

case $OPERATION in
  init|run|create_cache|delete_cache|shutdown)
    if [ -f "env.yml" ]; then ANSIBLE_CUSTOM_VARS_ARG="-e @env.yml"; fi
    ansible-playbook server.yml -v -e "operation=$OPERATION" $ANSIBLE_CUSTOM_VARS_ARG "${@:2}"
  ;;
  *)
    echo "Invalid option!"
    echo "Available operations: init, run, create_cache, delete_cache, shutdown."
  ;;
esac

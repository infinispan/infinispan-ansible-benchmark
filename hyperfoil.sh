#!/usr/bin/env bash
set -e
cd $(dirname "${BASH_SOURCE[0]}")

if [[ "$RUNNER_DEBUG" == "1" ]]; then
  set -x
fi

OPERATION=$1

case $OPERATION in
  requirements)
    ansible-galaxy role install -r roles/requirements.yml
  ;;
  init|run|stats|shutdown|download_logs)
    if [ -f "env.yml" ]; then ANSIBLE_CUSTOM_VARS_ARG="-e @env.yml"; fi
    ansible-playbook hyperfoil_controller.yml -v -e "operation=$OPERATION" $ANSIBLE_CUSTOM_VARS_ARG "${@:2}"
  ;;
  benchmark)
    if [ -f "env.yml" ]; then ANSIBLE_CUSTOM_VARS_ARG="-e @env.yml"; fi
    ansible-playbook hyperfoil_agent.yml -v $ANSIBLE_CUSTOM_VARS_ARG "${@:2}"
  ;;
  *)
    echo "Invalid option!"
    echo "Available operations: requirements, init, run, shutdown, download_logs."
  ;;
esac

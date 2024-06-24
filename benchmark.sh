#!/usr/bin/env bash

set -e
cd $(dirname "${BASH_SOURCE[0]}")

if [[ "$RUNNER_DEBUG" == "1" ]]; then
  set -x
fi

OPERATION=$1

case $OPERATION in
  run)
    ansible-playbook all_benchmarks.yml -v "${@:2}"
  ;;
  report)
    size=$(jq '.benchmarks | length' "$2")
    for ((i=0;i<"$size";i++)); do
      id=$(printf "%04x" "$i")
      ./hyperfoil.sh stats -e test_runid="$id" -e download_results=true "${@:4}"
    done

    mkdir "$3"
    cp ./*.csv "$3"
    cp ./*_all.json "$3"
  ;;
  *)
    echo "Invalid option! $OPERATION"
    echo "Available operations: run,report"
    exit 1;
  ;;
esac

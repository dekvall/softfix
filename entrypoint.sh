#!/bin/bash

echo "hi"

set -e

echo $GITHUB_EVENT_NAME
cat $GITHUB_EVENT_PATH

PR_NUMBER=$(jq -r ".issue.number" "$GITHUB_EVENT_PATH")
echo "Softfixing #$PR_NUMBER in $GITHUB_REPOSITORY"

if [[ -z "$GITHUB_TOKEN" ]]; then
	echo "Set a github token"
	exit 1
fi





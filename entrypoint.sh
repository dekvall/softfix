#!/bin/bash

set -e

PR_NUMBER=$(jq -r ".issue.number" "$GITHUB_EVENT_PATH")
COMMENT_BODY=$(jq -r ".comment.body" "$GITHUB_EVENT_PATH")

echo $COMMENT_BODY

COMMIT_MSG=$(echo $COMMENT_BODY | sed -e 's/.*\/softfix\r\n```\(.*\)```.*/\1/')

# Grab the old commit message and use it if there is nothing else
# But really only handling of the message is required now, and a lot of cleanup
echo "Softfixing #$PR_NUMBER in $GITHUB_REPOSITORY"

if [[ -z "$GITHUB_TOKEN" ]]; then
	echo "Set a github token"
	exit 1
fi

URI="https://api.github.com"
ACCEPT_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token $GITHUB_TOKEN"

pr_response=$(curl -s -H "${AUTH_HEADER}" -H "${API_HEADER}" \
"${URI}/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER")

COMMITS_URL=$(echo "$pr_response" | jq -r .commits_url)
commits_response=$(curl -s -H "${AUTH_HEADER}" -H "${API_HEADER}" $COMMITS_URL)
# This is limited to 250 entries, but it should be okay
N_COMMITS=$(echo $commits_response | jq -r length)

USER_LOGIN=$(jq -r ".comment.user.login" "$GITHUB_EVENT_PATH")
user_response=$(curl -s -H "${AUTH_HEADER}" -H "${API_HEADER}" \
"${URI}/users/${USER_LOGIN}")

USER_NAME=$(echo "$user_response" | jq -r ".name")
if [[ "$USER_NAME" == "null" ]]; then
	USER_NAME=$USER_LOGIN
fi

USER_NAME="${USER_NAME} (Softfix Action)"

USER_EMAIL=$(echo "$user_response" | jq -r ".email")
if [[ "$USER_EMAIL" == "null" ]]; then
	USER_EMAIL="$USER_LOGIN@users.noreply.github.com"
fi

HEAD_REPO=$(echo "$pr_response" | jq -r .head.repo.full_name)
HEAD_BRANCH=$(echo "$pr_response" | jq -r .head.ref)

USER_TOKEN=${USER_LOGIN}_TOKEN
COMMITTER_TOKEN=${!USER_TOKEN:-$GITHUB_TOKEN}

git remote set-url origin https://x-access-token:$COMMITTER_TOKEN@github.com/$GITHUB_REPOSITORY.git
git config --global user.email "$USER_EMAIL"
git config --global user.name "$USER_NAME"

git remote add fork https://x-access-token:$COMMITTER_TOKEN@github.com/$HEAD_REPO.git

git fetch fork $HEAD_BRANCH

git checkout -b $HEAD_BRANCH fork/$HEAD_BRANCH
git reset --soft HEAD~$N_COMMITS
git commit -m "$COMMIT_MSG"

git push --force-with-lease fork $HEAD_BRANCH








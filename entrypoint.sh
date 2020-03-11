#!/bin/bash

echo "hi"

set -e

PR_NUMBER=$(jq -r ".issue.number" "$GITHUB_EVENT_PATH")
COMMENT_BODY=$(jq -r ".comment.body" "$GITHUB_EVENT_PATH")

echo $COMMENT_BODY

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

BASE_SHA=$(echo "$pr_response" | jq -r .base.sha)

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

if [[ -z "$BASE_SHA" ]]; then
	echo "Cannot get base sha information for #$PR_NUMBER"
	echo "API response: $pr_resp"
	exit 1
fi

HEAD_REPO=$(echo "$pr_response" | jq -r .head.repo.full_name)
HEAD_BRANCH=$(echo "$pr_response" | jq -r .head.ref)

#FIRST_PR_COMMIT=$(git rev-list $BASE_SHA..| head -1)

USER_TOKEN=${USER_LOGIN}_TOKEN
COMMITTER_TOKEN=${!USER_TOKEN:-$GITHUB_TOKEN}

git remote set-url origin https://x-access-token:$COMMITTER_TOKEN@github.com/$GITHUB_REPOSITORY.git
git config --global user.email "$USER_EMAIL"
git config --global user.name "$USER_NAME"

git remote add fork https://x-access-token:$COMMITTER_TOKEN@github.com/$HEAD_REPO.git

set -o xtrace

git fetch fork $HEAD_BRANCH

echo $BASE_SHA
echo "Resetting on $FIRST_PR_COMMIT"

git rev-list fork/$HEAD_BRANCH
# do the reset
git checkout -b $HEAD_BRANCH fork/$HEAD_BRANCH
git reset --soft $FIRST_PR_COMMIT
git commit --amend -m "$COMMENT_BODY"

# push back
git push --force-with-lease fork $HEAD_BRANCH








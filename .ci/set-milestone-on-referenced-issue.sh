#!/bin/bash

set -e

source ./.ci/util.sh

if [[ -z $1 ]]; then
  echo "[ERROR] Pull request number is not set."
  echo "Usage: $BASH_SOURCE <pull request number>"
  exit 1
fi

PULL_REQUEST_NUMBER=$1
echo "PULL_REQUEST_NUMBER=$PULL_REQUEST_NUMBER"

checkForVariable "GITHUB_TOKEN"

echo "Fetching commit messages that match '^(Pull|Issue) #[0-9]+' from PR #$PULL_REQUEST_NUMBER."
PULL_REQUEST_COMMITS=$(curl -s \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN"\
  https://api.github.com/repos/checkstyle/checkstyle/pulls/"$PULL_REQUEST_NUMBER"/commits)
PULL_REQUEST_COMMIT_MESSAGES=$(echo "$PULL_REQUEST_COMMITS" \
  | jq -r .[].commit.message | grep -E "^(Pull|Issue) #[0-9]+")
echo "PULL_REQUEST_COMMIT_MESSAGES=
$PULL_REQUEST_COMMIT_MESSAGES"

echo "Extracting issue numbers from commit messages."
ISSUE_NUMBERS=$(echo "$PULL_REQUEST_COMMIT_MESSAGES" | grep -oE "#[0-9]+" | cut -c2-)
echo "ISSUE_NUMBERS=
$ISSUE_NUMBERS"

if [ -z "$ISSUE_NUMBERS" ]; then
  echo "[ERROR] No issue numbers found in commit messages."
  exit 0
fi

echo "Fetching latest milestone."
MILESTONE=$(curl -s \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN"\
  https://api.github.com/repos/checkstyle/checkstyle/milestones)
MILESTONE_NUMBER=$(echo "$MILESTONE" | jq .[0].number)
MILESTONE_TITLE=$(echo "$MILESTONE" | jq -r .[0].title)
echo "MILESTONE_NUMBER=$MILESTONE_NUMBER"
echo "MILESTONE_TITLE=$MILESTONE_TITLE"

function setMilestoneOnIssue {
  ISSUE_NUMBER=$1
  echo "Setting milestone $MILESTONE_TITLE to issue #$ISSUE_NUMBER."
  BODY="{\"milestone\": $MILESTONE_NUMBER}"
  curl -s \
    -X PATCH \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN"\
    -d "$BODY" \
    https://api.github.com/repos/checkstyle/checkstyle/issues/"$ISSUE_NUMBER"
}

for ISSUE_NUMBER in $ISSUE_NUMBERS; do
  setMilestoneOnIssue "$ISSUE_NUMBER"
done

#!/bin/bash
set -e

if [ -z "$APPROVALS" ]; then
  echo "Using default approvals == 1"
  APPROVALS=1
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo "Set the GITHUB_TOKEN env variable."
  exit 1
fi

if [ -z "$GITHUB_REPOSITORY" ]; then
  echo "Set the GITHUB_REPOSITORY env variable."
  exit 1
fi

if [ -z "$GITHUB_EVENT_PATH" ]; then
  echo "Set the GITHUB_EVENT_PATH env variable."
  exit 1
fi

if [ -z "$AWS_ACCESS_KEY_ID" -o -z "$AWS_SECRET_ACCESS_KEY" -o -z "$AWS_DEFAULT_REGION" ]; then
  if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "Set AWS_ACCESS_KEY_ID to login to AWS"
  fi
  if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Set AWS_SECRET_ACCESS_KEY to login to AWS"
  fi
  if [ -z "$AWS_DEFAULT_REGION" ]; then
    echo "Set AWS_DEFAULT_REGION to set region for created stacks"
  fi
  exit 1
fi

URI="https://api.github.com"
API_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"

action=$(jq --raw-output .action "$GITHUB_EVENT_PATH")
state=$(jq --raw-output .review.state "$GITHUB_EVENT_PATH")
number=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")

vend_when_approved() {
  # https://developer.github.com/v3/pulls/reviews/#list-reviews-on-a-pull-request
  body=$(curl -sSL -H "${AUTH_HEADER}" -H "${API_HEADER}" "${URI}/repos/${GITHUB_REPOSITORY}/pulls/${number}/reviews?per_page=100")
  reviews=$(echo "$body" | jq --raw-output '.[] | {state: .state} | @base64')

  approvals=0

  for r in $reviews; do
    review="$(echo "$r" | base64 --decode)"
    rState=$(echo "$review" | jq --raw-output '.state')

    if [[ "$rState" == "APPROVED" ]]; then
      approvals=$((approvals+1))
    fi

    echo "${approvals}/${APPROVALS} approvals"

    if [ "$approvals" == "$APPROVALS" ]; then
       echo "Code to do actial vending here!" 
       echo -n "Account ID: "
       ndt account-id
       exit $?
    fi
  done
}

if [ "$action" == "submitted" ] && [ "$state" == "approved" ]; then
  vend_when_approved
else
  echo "Ignoring event ${action}/${state}"
fi

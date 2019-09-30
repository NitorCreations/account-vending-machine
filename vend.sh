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

pwd
ls -la

URI="https://api.github.com"
API_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"

cat "$GITHUB_EVENT_PATH"
ACTION=$(jq --raw-output .action "$GITHUB_EVENT_PATH")
STATE=$(jq --raw-output .review.state "$GITHUB_EVENT_PATH")
PR_NUMBER=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")
FORK=$(jq .pull_request.head.repo.fork "$GITHUB_EVENT_PATH")
NAME=$(jq .pull_request.head.ref "$GITHUB_EVENT_PATH")
# https://developer.github.com/v3/pulls/reviews/#list-reviews-on-a-pull-request
URL="${URI}/repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/reviews?per_page=100"
echo $URL

# Find out if pull request is a fork. If it's not, we are all set.
if [[ "$FORK" == "false" ]]; then
  echo "Pull request not from fork. Code already checked out correctly"
else
  # Check out remote branch based on pull request number
  # Credit: https://github.community/t5/How-to-use-Git-and-GitHub/Checkout-a-branch-from-a-fork/m-p/78/highlight/true#M11
  git fetch origin pull/${PR_NUMBER}/head:pr/${PR_NUMBER}
  git checkout "pr/${PR_NUMBER}"
  echo "Checked out code from pull request #${PR_NUMBER}. Last commit: $(git log --oneline -n 1)"
fi

vend_when_approved() {
  BODY=$(curl -sSL -H "${AUTH_HEADER}" -H "${API_HEADER}" "$URL")
  echo "$BODY"
  REVIEWS=$(echo "$BODY" | jq --raw-output '.[] | {state: .state} | @base64')

  READ_APPROVALS=0

  for REV in $REVIEWS; do
    REVIEW="$(echo "$REV" | base64 --decode)"
    REVIEW_STATE=$(echo "$REVIEW" | jq --raw-output '.state')

    if [[ "$REVIEW_STATE" == "APPROVED" ]]; then
      READ_APPROVALS=$((READ_APPROVALS+1))
    fi

    echo "${READ_APPROVALS}/${APPROVALS} approvals"

    if [ "$READ_APPROVALS" == "$APPROVALS" ]; then
      eval "$(ndt load-parameters $NAME -e)"
      if [ -z "$EMAIL" ]; then
        echo "EMAIL needs to be a defined and unique parameter"
        exit 1
      fi
      ndt create-account $EMAIL $NAME
      CREATED_ACCOUNT=$(ndt show-stack-params-and-outputs managed-account-$NAME -p paramManagedAccount)
      MANAGE_ROLE=$(ndt show-stack-params-and-outputs managed-account-$NAME -p ManageRole)
      echo -n "Account ID: $CREATED_ACCOUNT"
      COMPONENTS=$(mktemp -p .)
      ndt list-jobs -c $NAME -b $NAME -j | jq .branches[0].components[0].subcomponents > $COMPONENTS
      OLD_AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
      OLD_AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
      eval "$(ndt assume-role $MANAGE_ROLE)"
      for COMPONENT in $(jq -r '.[]|select(.name != null)|.name' < $COMPONENTS | sort); do
        TYPE=$(jq -r ".[]|select(.name == \"$COMPONENT\")|.type" < $COMPONENTS)
        ndt deploy-$TYPE $NAME $COMPONENT
      done
      exit $?
    fi
  done
}

if [ "$ACTION" == "submitted" ] && [ "$STATE" == "approved" ]; then
  vend_when_approved
else
  echo "Ignoring event ${ACTION}/${STATE}"
fi
#foo

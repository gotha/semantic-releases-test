#!/usr/bin/env bash

getMajorVersion() {
  local RELEASE_NAME
  RELEASE_NAME="$1"
  if [ -z "$RELEASE_NAME" ]; then
    echo "You must provide release name"
    exit 1
  fi
  local VERSION
  VERSION=$(echo "$RELEASE_NAME" | awk -F- '{print $1}')
  echo "$VERSION" | awk -F. '{print $1}'
}

getMinorVersion() {
  local RELEASE_NAME
  RELEASE_NAME="$1"
  if [ -z "$RELEASE_NAME" ]; then
    echo "You must provide release name"
    exit 1
  fi
  local VERSION
  VERSION=$(echo "$RELEASE_NAME" | awk -F- '{print $1}')
  echo "$VERSION" | awk -F. '{print $2}'
}

getPatchVersion() {
  local RELEASE_NAME
  RELEASE_NAME="$1"
  if [ -z "$RELEASE_NAME" ]; then
    echo "You must provide release name"
    exit 1
  fi
  local VERSION
  VERSION=$(echo "$RELEASE_NAME" | awk -F- '{print $1}')
  echo "$VERSION" | awk -F. '{print $3}'
}

getLatestRelease() {
  local RELEASES
  local NEWEST_RELEASE_TIME=0
  local NEWEST_RELEASE_NAME=""
  RELEASES=$(hub release -f "%T,%pt,%pI %n" --exclude-prereleases)

  if [ -z "$RELEASES" ]; then
    echo "$NEWEST_RELEASE_NAME"
    return
  fi

  while read -r line; do
    local RELEASE
    RELEASE=$(echo "$line" | awk -F, '{print $1}')
    local TIME
    TIME=$(echo "$line" | awk -F, '{print $2}')

    if [ $TIME -gt $NEWEST_RELEASE_TIME ]; then
      NEWEST_RELEASE_TIME=$TIME
      NEWEST_RELEASE_NAME=$RELEASE
    fi
  done <<<"$RELEASES"

  echo "$NEWEST_RELEASE_NAME"
}

getLatestReleaseCommit() {
  local RELEASE_NAME
  RELEASE_NAME="$1"
  if [ -z "$RELEASE_NAME" ]; then
    echo "You must provide release name"
    exit 1
  fi
  local COMMIT
  COMMIT=$(git rev-list -n 1 "$RELEASE_NAME")
  echo "$COMMIT"
}

getAllCommitsBetweenCommitAndHead() {
  local COMMIT
  COMMIT=$1
  if [ -z "$COMMIT" ]; then
    echo "You must proivde commit"
    exit 1
  fi

  local SHORT_COMMIT
  SHORT_COMMIT=${COMMIT:0:7}

  local LIST
  LIST=$(git rev-list --ancestry-path "$SHORT_COMMIT"..HEAD)
  echo "$LIST"
}

getCommitMessage() {
  local HASH
  HASH=$1
  if [ -z "$HASH" ]; then
    echo "You must provide commit hash"
    exit 1
  fi

  local MESSAGE
  MESSAGE=$(git log --format=%B -n 1 "$HASH")
  echo "$MESSAGE"
}

proposeNextVersionName() {
  local RELEASE_NAME
  RELEASE_NAME="$1"
  if [ -z "$RELEASE_NAME" ]; then
    echo "You must provide release name"
    exit 1
  fi

  local MAJOR_VERSION
  MAJOR_VERSION=$(getMajorVersion "$RELEASE_NAME")
  local MINOR_VERSION
  MINOR_VERSION=$(getMinorVersion "$RELEASE_NAME")
  local PATCH_VERSION
  PATCH_VERSION=$(getPatchVersion "$RELEASE_NAME")

  local LATEST_RELEASE_COMMIT
  LATEST_RELEASE_COMMIT=$(getLatestReleaseCommit "$RELEASE_NAME")

  local COMMITS
  COMMITS=$(getAllCommitsBetweenCommitAndHead "$LATEST_RELEASE_COMMIT")

  local MAJOR_CHANGES
  MAJOR_CHANGES=0
  local MINOR_CHANGES
  MINOR_CHANGES=0
  local PATCH_CHANGES
  PATCH_CHANGES=0

  while read -r commit_hash; do
    local MESSAGE
    MESSAGE=$(getCommitMessage "$commit_hash")
    local PREFIX
    PREFIX=$(echo "$MESSAGE" | awk '{print $1}')

    if [ "$PREFIX" == "fix" ]; then
      PATCH_CHANGES=$(($PATCH_CHANGES + 1))
    elif [ "$PREFIX" == "feature" ]; then
      MINOR_CHANGES=$(($MINOR_CHANGES + 1))
    elif [ "$PREFIX" == "major" ]; then
      MAJOR_CHANGES=$(($MAJOR_CHANGES + 1))
    fi
  done <<<"$COMMITS"

  if [ $MAJOR_CHANGES -gt 0 ]; then
    MAJOR_VERSION=$(($MAJOR_VERSION + $MAJOR_CHANGES))
    MINOR_VERSION=0
    PATCH_VERSION=0
  elif [ $MINOR_CHANGES -gt 0 ]; then
    MINOR_VERSION=$(($MINOR_VERSION + $MINOR_CHANGES))
    PATCH_VERSION=0
  elif [ $PATCH_CHANGES -gt 0 ]; then
    PATCH_VERSION=$(($PATCH_VERSION + $PATCH_CHANGES))
  fi

  echo "$MAJOR_VERSION.$MINOR_VERSION.$PATCH_VERSION"
}

release() {

  local CURRENT_TAG
  CURRENT_TAG=$(git tag -l --contains HEAD)
  if [ ! -z "$CURRENT_TAG" ]; then
    echo "There is already tag '${CURRENT_TAG}' for this commit"
    exit 1
  fi

  local LATEST_RELEASE
  LATEST_RELEASE=$(getLatestRelease)

  local PROPOSED_VERSION
  if [ "$LATEST_RELEASE" == "" ]; then
    PROPOSED_VERSION="0.0.1"
  else
    PROPOSED_VERSION=$(proposeNextVersionName "$LATEST_RELEASE")
  fi

  local VERSION
  read -p "Version [$PROPOSED_VERSION]: " VERSION
  if [ -z "$VERSION" ]; then
    VERSION="$PROPOSED_VERSION"
  fi

  local NAME
  read -p "Name: " NAME

  local IS_PRERELEASE
  local RELEASE_TYPE
  local HUB_PARAMS
  read -p "Is this pre-release ? [y]: " -n 1 -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    IS_PRERELEASE=0
    RELEASE_TYPE="release"
    HUB_PARAMS=""
  else
    IS_PRERELEASE=1
    RELEASE_TYPE="pre-release"
    HUB_PARAMS="-p"
  fi
  echo

  # @todo add option to track RC number

  local NEW_RELEASE_NAME
  NEW_RELEASE_NAME="$VERSION"

  if [ ! -z "$NAME" ]; then
    NEW_RELEASE_NAME="$NEW_RELEASE_NAME-$NAME"
  fi

  echo "You are going to create $RELEASE_TYPE named $NEW_RELEASE_NAME "
  read -p "Press Y|y to continue: " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting ..."
    exit 0
  fi

  git tag "$NEW_RELEASE_NAME"
  git push origin --tags
  hub release create "$NEW_RELEASE_NAME" -m "$NEW_RELEASE_NAME" "$HUB_PARAMS"
}

release

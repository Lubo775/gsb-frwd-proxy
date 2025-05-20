#!/bin/bash
if test $# -eq 0; then
  echo "Usage: $0 <tag> [<commit>]" 1>&2
  echo "<commit> defaults to the HEAD of the current branch, and can be any commit pattern." 1>&2
  exit 1
fi
TAG=$1
COMMIT=$2

#does the VW git tagging
if test -n "$(git tag --list $TAG)"; then
  git tag --delete $TAG && git push origin :$TAG
fi &&
git tag $TAG $COMMIT && git push origin $TAG

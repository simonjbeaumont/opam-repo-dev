#!/bin/bash
set -e

ALL_PKGS=$(find packages -mindepth 2 -maxdepth 2 -type d -printf '%f\n' | sort -u)

echo "Building Docker image for testing..."
docker build -t opam-repo-dev .

echo "Pull request: ${TRAVIS_PULL_REQUEST}"
if [ "${TRAVIS_PULL_REQUEST}" != "false" ]; then
  curl -L https://github.com/$TRAVIS_REPO_SLUG/pull/$TRAVIS_PULL_REQUEST.diff -o diff
else
  git show > diff.tmp
  merge=`grep "^Merge: " diff.tmp | awk -F: '{print $2}'`
  if [ "$merge" = "" ]; then
    echo Not a merge
    mv diff.tmp diff
  else
    echo Merge detected, extracting $merge diff
    git show $merge > diff
  fi
fi

cd ${TRAVIS_BUILD_DIR}
echo "Pull request:"
cat diff
cat diff | sort -u | grep '^... b/packages' | sed -E 's,\+\+\+ b/packages/.*/(.*)/.*,\1,' | grep -v '^files' | grep -v '^patches' | awk -F. '{print $1}'| sort -u > tobuild.txt
echo To Build:
cat tobuild.txt
exit 0

for p in $(cat tobuild.txt); do
  echo "Testing installation of packages in container: ${p}"
  docker run --rm -it opam-repo-dev bash /opam-repo-dev/test/install-package.sh $p
done

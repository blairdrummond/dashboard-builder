#!/bin/bash

# Get the sha256 of a repo. Defaults to master
# usage: ./get-master.sh user/repo

# Note: some github repos are now using "main" instead.
# This might break as a result.
REPO="$1"
COMMIT=${2:-master}

if test -z "$REPO"; then
    echo "Error: No repo specified. Exiting." >&2
    exit 1
fi

tmpfile=$(mktemp /tmp/repo.XXXXXX.zip)
trap 'rm -f -- "$tmpfile"' INT TERM HUP EXIT


get_zip () {
    COMMIT="$1"
    wget -q "https://github.com/${REPO}/archive/${COMMIT}.zip" -O $tmpfile
}

get_commit_sha () {
    if [ "$COMMIT" = master ] || [ "$COMMIT" = main ]; then
        curl --silent "https://api.github.com/repos/$REPO/commits?per_page=1" | jq -r '.[0].sha | .[0:7]'
    else
        echo "$COMMIT"
    fi
}

# error handling for "main" branch name
if ! { get_zip "$COMMIT" || get_zip main; }; then
    echo "Error: Repo or Commit not found" >&2
    exit 1
fi


cat <<EOF
repo:
   path: $REPO
   url: https://github.com/$REPO
   commit: $(get_commit_sha)
   zipsha: $(sha256sum $tmpfile | awk '{print $1}')
EOF

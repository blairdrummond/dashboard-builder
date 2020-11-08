#!/usr/bin/env bash
set -euo pipefail

# docker login

trap "rm -rf .unpack app" EXIT

get_zip () {
    REPO="$1"
    COMMIT="$2"
    echo wget -q "https://github.com/${REPO}/archive/${COMMIT}.zip" -O repo.zip
    if ! wget -q "https://github.com/${REPO}/archive/${COMMIT}.zip" -O repo.zip; then
        echo "Error: Repo or Commit not found" >&2
        exit 1
    fi
}


get_dockerfile () {
    if ! [ -d dockerfiles/${1}-s2i ]; then
        echo "Error: $1 is unsupported." >&2
        exit 1
    fi
    echo dockerfiles/${1}-s2i
}


while read line; do

    # Read through the DASHBOARDS file
    IFS=" " read -r -a array <<< "$line"
    NAME="${array[0]}"
    TYPE="${array[1]}"
    COMMIT="${array[2]}"
    REPO="${array[3]}"
    SHA256="${array[4]}"

    # Skip header
    [ "${array[0]}" = "#Application" ] && continue

    # Clean up name, remove leading+trailing /
    REPO="${REPO##"/"}"
    REPO="${REPO%%"/"}"

    # normalize the case
    TYPE="$(echo "$TYPE" | tr '[:upper:]' '[:lower:]')"

    # make sure we support the application type
    DOCKERFILE=$(get_dockerfile "$TYPE")
    [ $? = 0 ] || exit 1

    echo "Starting $NAME"
    echo "=========================="

    # Create the s2i-builder. (if it doesn't already exist)
    (cd $DOCKERFILE; docker build . -t "${TYPE}-s2i-builder")

    # Get & validate the zip
    get_zip "$REPO" "$COMMIT"

    echo "Check Shaaa"
    if sha256sum repo.zip | grep -q 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'; then
        echo "Error: Commit or Repo not found." >&2
        exit 1
    fi

    echo "Check Sha"
    if ! echo "$SHA256  repo.zip" | sha256sum -c - ; then
        echo "Check of ${NAME} failed. Exiting." >&2
        exit 1
    fi

    rm -rf .unpack app
    unzip repo.zip -d .unpack > /dev/null 2>&1 \
        && mv .unpack/* app \
        && rm -rf .unpack

    # Docker build
    echo "Starting the docker build"
    s2i build "https://github.com/${REPO}" "${TYPE}-s2i-builder" "$NAME:${COMMIT}"

    docker push "$NAME:${COMMIT}"

done < DASHBOARDS

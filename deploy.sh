#!/usr/bin/env bash

# Script to build and push docker images for
# user submitted dashboards, and create the yaml
# for them too.
#
#
#
#
# usage:
#
#     $ export NAMESPACE=apps
#     $ export REGISTRY=blairdrummond
#     $ ./deploy.sh [ build | push | yaml ]
#
#
# By default, ./deploy.sh does all three,
# but if you add an argument, it will do
# a subset instead. For instance
#
#     yaml  ->  YAML
#     build ->  BUILD
#     oush  ->  BUILD + PUSH
#
# author: blair drummond
#

set -eo pipefail

# docker login
#trap "rm -rf .unpack .repo.zip" INT TERM HUP EXIT

REGISTRY=${REGISTRY:-blairdrummond}
NAMESPACE=${NAMESPACE:-apps}

# FALSE if ""
# TRUE otherwise.
BUILD="yes"
PUSH="yes"
YAML="yes"


while test -n "$1"; do
    case "$1" in
        -n)
            shift
            NAMESPACE="$1"
            ;;
        -r)
            shift
            REGISTRY="$1"
            ;;
        yaml)
            BUILD=""
            PUSH=""
            ;;
        build)
            PUSH=""
            YAML=""
            ;;
        push)
            YAML=""
            ;;
    esac
    shift
done



#################################
###      Helper Functions     ###
#################################

# Get the github repo at a commit
get_zip () {
    REPO="$1"
    COMMIT="$2"
    SHA256="$3"

    echo wget -q "https://github.com/${REPO}/archive/${COMMIT}.zip" -O .repo.zip
    if ! wget -q "https://github.com/${REPO}/archive/${COMMIT}.zip" -O .repo.zip; then
        echo "Error: Repo or Commit not found" >&2
        exit 1
    fi

    echo "Check Sha $REPO:$COMMIT"
    if ! echo "$SHA256  .repo.zip" | sha256sum -c - ; then
        echo "Check of ${NAME} failed. Exiting." >&2
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



validate_build_push () {
    NAME="$1"
    TYPE="$2"
    COMMIT="$3"
    REPO="$4"
    SHA256="$5"

    echo "Starting $NAME"
    echo "=========================="

    # Create the s2i-builder. (if it doesn't already exist)
    (cd $DOCKERFILE; docker build . -t "${TYPE}-s2i-builder")

    # Get & validate the zip (.repo.zip)
    get_zip "$REPO" "$COMMIT" "$SHA256"

    # Unpack it
    rm -rf .unpack
    unzip .repo.zip -d .unpack > /dev/null 2>&1

    # The s2i build
    echo "Starting the docker build"
    # s2i build "https://github.com/${REPO}" "${TYPE}-s2i-builder" "$NAME:${COMMIT}"
    (cd .unpack/*/ && s2i build . "${TYPE}-s2i-builder" "$REGISTRY/$NAME:${COMMIT}")

    test -n "$PUSH" && docker push "$REGISTRY/$NAME:${COMMIT}"

    echo "Done $NAME."
}




generate_manifest () {
    NAME="$1"
    TYPE="$2"
    COMMIT="$3"
    REPO="$4"

    DESCRIPTION="$(curl --silent "https://api.github.com/repos/$REPO" | jq -r .description)"
    if [ "$DESCRIPTION" = null ]; then
        DESCRIPTION="No Github description found."
    fi

    MAINTAINER="$(curl --silent "https://api.github.com/repos/$REPO" | jq -r .owner.login)"

    helm template ./chart \
        --set namespace=$NAMESPACE \
        --set image.image="$REGISTRY/$NAME:$COMMIT" \
        --set metadata.name="$NAME" \
        --set metadata.maintainer="$MAINTAINER" \
        --set metadata.description="$DESCRIPTION" > yaml/$NAME-manifest.yaml
}


# Clear the old yaml
rm -rf yaml && mkdir -p yaml

#############################
###   Loop through list   ###
#############################
while read line; do

    # Read through the DASHBOARDS file
    IFS=" " read -r -a array <<< "$line"
    NAME="${array[0]}"
    TYPE="${array[1]}"
    COMMIT="${array[2]}"
    REPO="${array[3]}"
    SHA256="${array[4]}"

    # Skip header
    [ "$NAME" = "#Application" ] && continue

    # Clean up name, remove leading+trailing /
    REPO="${REPO##"/"}"
    REPO="${REPO%%"/"}"

    # normalize the case
    TYPE="$(echo "$TYPE" | tr '[:upper:]' '[:lower:]')"

    # make sure we support the application type
    DOCKERFILE=$(get_dockerfile "$TYPE")
    [ $? = 0 ] || exit 1

    test -n "${BUILD}${PUSH}" && validate_build_push $NAME $TYPE $COMMIT $REPO $SHA256
    test -n "$YAML"           && generate_manifest   $NAME $TYPE $COMMIT $REPO

done < DASHBOARDS

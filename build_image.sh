#!/bin/bash

set -Eeo pipefail

set -a
[ -f .env ] && . .env
set +a

while getopts D:f:r:u:i:t:pP:l: flag
do
    case "${flag}" in
        D) DOCKERFILE_DIR=$OPTARG;;
        f) DOCKERFILE="$OPTARG";;
        r) REGISTRY="$OPTARG";;
        u) REPOSITORY=$OPTARG;;
        i) IMAGE=$OPTARG;;
        p) OUTPUT="--push";;
        P) PLATFORMS=$OPTARG;;
        :) exit 1;;
        \?) exit 1;; 
    esac
done

if [ ! "$DOCKERFILE_DIR" ]; then DOCKERFILE_DIR="."; fi
if [ ! "$DOCKERFILE" ]; then 
    echo "Dockerfile not specified, abort..."
    exit 1
fi

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$ROOT_DIR"

# Register/update emulators
docker run --rm --privileged tonistiigi/binfmt --install all >/dev/null

# create multiarch builder if needed
builder=multiarch_builder
if [ "$(docker buildx ls | grep $builder)" == "" ]
then
    docker buildx create --name $builder
fi

# Use the builder
docker buildx use $builder

set -x
# Build image
docker buildx build \
    -f "$DOCKERFILE" \
    --platform "$PLATFORMS" "$DOCKERFILE_DIR"
set +x

IFS=',' read -r -a platforms <<< "$PLATFORMS"
for platform in "${platforms[@]}"
do
    arch="$(sed 's#linux/##' <<< $platform)"
    tag="$(sed 's#/##' <<< $arch)"

    docker buildx build \
        -f "$DOCKERFILE" \
        --platform "$platform" \
        --load \
        -t "$([ "$REGISTRY" ] && echo $REGISTRY/)$REPOSITORY/$IMAGE:$tag" \
        "$DOCKERFILE_DIR"
done
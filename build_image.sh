#!/bin/bash

set -Eeo pipefail

print_help() {
    cat <<EOF
Usage: $0 [options]

Options:
  -D <dir>      Docker build context (default: .)         [DOCKER_CONTEXT]
  -f <file>     Dockerfile path (optional)                [DOCKERFILE]
  -r <registry> Registry (optional)                       [REGISTRY]
  -u <repo>     Repository (required)                     [REPOSITORY]
  -i <image>    Image name (required)                     [IMAGE]
  -t <tag>      Tag (required)                            [TAG]
  -p            Push multi-platform image to registry (overrides default)
  -P <plats>    Platforms (comma-separated, required)     [PLATFORMS]
  -h            Show this help and exit

Default behavior (without -p): builds and loads each platform image locally as
[<registry>/]<repository>/<image>:<tag>-<platform>.

With -p: pushes a multi-platform image to the registry as
[<registry>/]<repository>/<image>:<tag>.

You can also set any of the bracketed environment variables above in a .env file
in the script directory, instead of passing them as command line arguments.
Command line arguments take precedence over settings defined in the .env file.

EOF
}

set -a
[ -f .env ] && . .env
set +a

while getopts D:f:r:u:i:t:pP:h flag
do
    case "${flag}" in
        D) DOCKER_CONTEXT=$OPTARG;;
        f) DOCKERFILE="$OPTARG";;
        r) REGISTRY="$OPTARG";;
        u) REPOSITORY=$OPTARG;;
        i) IMAGE=$OPTARG;;
        t) TAG=$OPTARG;;
        p) PUSH=1;;
        P) PLATFORMS=$OPTARG;;
        h) print_help; exit 0;;
        :) exit 1;;
        \?) exit 1;; 
    esac
done

if [ ! "$DOCKER_CONTEXT" ]; then DOCKER_CONTEXT="."; fi
if [ ! "$DOCKERFILE" ]; then DOCKERFILE="Dockerfile"; fi

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$ROOT_DIR"

# Register/update emulators
docker pull tonistiigi/binfmt:latest >/dev/null
docker run --rm --privileged tonistiigi/binfmt --uninstall qemu-* >/dev/null
docker run --rm --privileged tonistiigi/binfmt --install all >/dev/null

# create multiarch builder if needed
builder=multiarch_builder
if [ "$(docker buildx ls | grep $builder)" == "" ]
then
    docker buildx create --name $builder
fi

# Use the builder
docker buildx use $builder

if [ "$PUSH" = "1" ]; then
    # Push multi-platform image to registry
    (set -x;
    docker buildx build \
        -f "$DOCKERFILE" \
        --platform "$PLATFORMS" \
        --push \
        -t "$([ "$REGISTRY" ] && echo $REGISTRY/)$REPOSITORY/$IMAGE:$TAG" \
        "$DOCKER_CONTEXT")
else
    # Build all platforms to cache first (concurrent build)
    (set -x;
    docker buildx build \
        -f "$DOCKERFILE" \
        --platform "$PLATFORMS" \
        --output=type=cacheonly \
        "$DOCKER_CONTEXT")
    # For each platform, load locally and tag as <tag>-<platform>
    IFS=',' read -r -a platforms <<< "$PLATFORMS"
    for platform in "${platforms[@]}"
    do
        arch="$(sed 's#linux/##' <<< $platform)"
        plat_tag="$(sed 's#/##' <<< $arch)"
        (set -x;
        docker buildx build \
            -f "$DOCKERFILE" \
            --platform "$platform" \
            --load \
            -t "$([ "$REGISTRY" ] && echo $REGISTRY/)$REPOSITORY/$IMAGE:${TAG}-${plat_tag}" \
            "$DOCKER_CONTEXT")
    done
fi
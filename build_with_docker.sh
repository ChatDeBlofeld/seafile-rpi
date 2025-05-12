#!/bin/bash

set -Eeo pipefail

print_help() {
    cat <<EOF
Usage: $0 [options]

Options:
  -B <builder>  Builder image prefix (required)            [BUILDER]
  -c <dir>      Cache directory (default: ./build)         [CACHE_DIR]
  -o <dir>      Output directory (default: ./packages)     [OUTPUT_DIR]
  -l <dir>      Logs directory (default: ./logs)           [LOGS_DIR]
  -P <plats>    Platforms (comma-separated, required)      [PLATFORMS]
  -v <ver>      Seafile server version, passed to build.sh [SEAFILE_SERVER_VERSION]
  -r <arg>      Pass -r to build.sh
  -f <file>     Pass -f to build.sh
  -0..-9, -A, -T  Pass these flags to build.sh
  -h            Show this help and exit

You can also set any of the bracketed environment variables above in a .env file
in the script directory, instead of passing them as command line arguments.
Command line arguments take precedence over settings defined in the .env file.

EOF
}

set -a
[ -f .env ] && . .env
set +a

if [ "$SEAFILE_SERVER_VERSION" ]; then
    ARGS="-v $SEAFILE_SERVER_VERSION"
fi

while getopts B:c:o:l:P:0123456789ATv:r:f:h flag
do
    case "${flag}" in
        B) BUILDER=$OPTARG;;
        c) CACHE_DIR=$OPTARG;;
        o) OUTPUT_DIR=$OPTARG;;
        l) LOGS_DIR=$OPTARG;;
        P) PLATFORMS=$OPTARG;;
        v) ARGS=$ARGS" -v $OPTARG";;
        0) ARGS=$ARGS" -0";;
        1) ARGS=$ARGS" -1";;
        2) ARGS=$ARGS" -2";;
        3) ARGS=$ARGS" -3";;
        4) ARGS=$ARGS" -4";;
        5) ARGS=$ARGS" -5";;
        6) ARGS=$ARGS" -6";;
        7) ARGS=$ARGS" -7";;
        8) ARGS=$ARGS" -8";;
        9) ARGS=$ARGS" -9";;
        A) ARGS=$ARGS" -A";;
        T) ARGS=$ARGS" -T";;
        r) ARGS=$ARGS" -r $OPTARG";;
        f) ARGS=$ARGS" -f $OPTARG";;
        h) print_help; exit 0;;
        :) exit 1;;
        \?) exit 1;; 
    esac
done

if [ ! "$CACHE_DIR" ]; then CACHE_DIR="./build"; fi
if [ ! "$OUTPUT_DIR" ]; then OUTPUT_DIR="./packages"; fi
if [ ! "$LOGS_DIR" ]; then LOGS_DIR="./logs"; fi
if [ ! "$BUILDER" ]; then 
    echo "Builder not specified, abort..."
    exit 1
fi

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$ROOT_DIR"

mkdir -p "$LOGS_DIR"

IFS=',' read -r -a platforms <<< "$PLATFORMS"
for platform in "${platforms[@]}"
do
    arch="$(sed 's#linux/##' <<< $platform)"
    tag="$(sed 's#/##' <<< $arch)"

    if [ ! -d "$CACHE_DIR/$tag" ]; then
        mkdir -p "$OUTPUT_DIR/$tag"
    fi

    if [ ! -d "$OUTPUT_DIR/$tag" ]; then
        mkdir -p "$OUTPUT_DIR/$tag"
    fi

    cmd="/build.sh $ARGS \
        && chown -R $(id -u):$(id -g) /built-seafile-server-pkgs"

    timestamp=$(date +"%Y%m%d_%H%M%S")
    log_file="$LOGS_DIR/build_${tag}_$timestamp.log"

    (set -x;
    docker run -it --rm \
        -v "$ROOT_DIR/build.sh":/build.sh \
        -v "$ROOT_DIR/build-server.py":/build-server.py \
        -v "$ROOT_DIR/requirements":/requirements \
        -v "$CACHE_DIR/$tag/haiwen-build":/haiwen-build \
        -v "$CACHE_DIR/$tag/built-seafile-sources":/built-seafile-sources \
        -v "$CACHE_DIR/$tag/root/opt/local":/root/opt/local \
        -v "$OUTPUT_DIR/$tag":/built-seafile-server-pkgs \
        $BUILDER-$tag /bin/bash -c "$cmd" |& tee >(sed -r 's/\x1b\[([0-9;]*m|K)//g' > "$log_file"))
done

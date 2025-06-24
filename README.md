Seafile server package for Raspberry Pi. Fork of [haiwen/seafile-rpi](github.com/haiwen/seafile-rpi), tailored for serving as base package of my docker images.

## Native build

See below for (cross-)compilation with docker.

E.g. to compile Seafile server v11.0.13:

```shell
$ git clone --depth=1 https://github.com/haiwen/seafile-rpi.git && cd seafile-rpi
$ chmod u+x build.sh
$ sudo ./build.sh -DTA -v 11.0.13
```

Calling `./build.sh` without arguments will return usage information and a list of all available arguments:

```shell
seafile@rpi-focal:~$ sudo ./build.sh

Usage:
  build.sh [OPTIONS]

  OPTIONS:
    -D          Install build dependencies
    -T          Install thirdparty requirements

    -0          Build/update libevhtp
    -1          Build/update libsearpc
    -2          Build/update seafile (c_fileserver)
    -3          Build/update seafile (go_fileserver)
    -4          Build/update seafile (notification_server)
    -5          Build/update seahub
    -6          Build/update seafobj
    -7          Build/update seafdav
    -8          Build/update seafevents
    -9          Build/update Seafile server

    -A          All options -0 to -9 in one go

    -v <vers>   Set seafile server version to build
                default: 11.0.13
    -r <vers>   Set libsearpc version
                default: 3.3-latest
    -f <vers>   Set fixed libsearpc version
                default: 3.1.0

    use --version for version info of this script.
```

Schema of created directory structure after execution of `./build.sh`:

```
seafile@rpi-focal:~$ tree . -L 3
.
├── build.sh
├── build-server.py.patch
├── built-seafile-server-pkgs
│   └── seafile-server-11.0.13-focal-armv7l.tar.gz
├── built-seafile-sources
│   └── R11.0.13
├── go
│   └── pkg
├── haiwen-build
│   ├── libevhtp
│   ├── libsearpc
│   ├── seafdav
│   ├── seafile-server
│   ├── seafobj
│   ├── seahub
│   └── seahub_thirdparty
└── opt
    └── local
```

## Docker build

This section describes cross-compilation using Docker buildx.

### Builder image creation

You first need to create an image with all required toolchains. Copy the `.env.example` to `.env` and choose the name of your builder image and the target platforms.

Then use the `build_image.sh` script to build it.

```bash
./build_image.sh
```

Script reference:

```
Usage: build_image.sh [options]

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
```

### Build

Again, use the `.env` to set your parameters, i.e. Seafile version and builder image. The use the `build_with_docker.sh` script to build packages. Basically just a wrapper over `build.sh` for cross-compilation. You'll need one or more working builder images (see above).

What you *want* is probably just building in one pass:

```bash
$ ./build_with_docker.sh -TA
```

Package will be stored in the `packages/<platform>` folder.

Script reference:

```
Usage: build_with_docker.sh [options]

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
```

### Targeting older distributions

The only provided `Dockerfile` uses a recent Ubuntu version. This can be an issue when used to build packages that target older distributions, due to GLIBC not being forward-compatible (as expected). Some hints are given here, but good luck and have fun.

Your first need to create a builder image based on a distribution that ships with a compatible GLIBC version. Debian Buster (10) is a good candidate. Copy and tweak the `Dockerfile` to use Buster as base image.

Things can quickly become tricky though. Golang parts (fileserver & notification server) typically won't build with an image based on a distribution older than Ubuntu 22.04 (jammy). Since go binaries are statically linked, you can use two builders to achieve your goal:

```bash
$ ./build_with_docker.sh -B local/seafile-builder:jammy-arm64  -45
$ ./build_with_docker.sh -B local/seafile-builder:buster-arm64 -T1236789
```

## Manual and Guides

- [Build Seafile server](https://manual.seafile.com/build_seafile/rpi/)
- [Deploy Seafile server](https://manual.seafile.com/deploy/)

## Contributors

See [CONTRIBUTORS](https://github.com/haiwen/seafile-rpi/graphs/contributors).

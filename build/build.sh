#!/bin/bash

set -ex

VERSION=$1

URL=https://github.com/ruby/ruby.git

case $VERSION in
trunk)
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=master
    ;;
4.*)
    RUBY_MINOR_VERSION=${VERSION%.*}
    FULLNAME=ruby-${VERSION}
    OUTPUT=$2/${FULLNAME}.tar.xz
    TARBALL_URL=https://cache.ruby-lang.org/pub/ruby/${RUBY_MINOR_VERSION}/ruby-${VERSION}.tar.gz
    TARBALL_DOWNLOAD=/tmp/ruby-${VERSION}.tar.gz
    SOURCE_DIR=${ROOT}/ruby-${VERSION}
    INSTALL_DIR=/opt/compiler-explorer/${FULLNAME}
    REVISION=$(curl -sI "${TARBALL_URL}" | grep -i last-modified | sha256sum | cut -d' ' -f1)
    LAST_REVISION="${3}"
    echo "ce-build-revision:${REVISION}"
    echo "ce-build-output:${OUTPUT}"
    if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
        echo "ce-build-status:SKIPPED"
        exit
    fi
    rm -rf "${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}"
    curl -L "${TARBALL_URL}" -o "${TARBALL_DOWNLOAD}"
    tar xzf "${TARBALL_DOWNLOAD}" -C "${ROOT}"
    cd "${SOURCE_DIR}"
    ./configure --prefix="${INSTALL_DIR}" --disable-install-doc
    make -j $(nproc)
    make install
    export XZ_DEFAULTS="-T 0"
    tar Jcf "${OUTPUT}" --transform "s,^./,./${FULLNAME}/," -C "${INSTALL_DIR}" .
    echo "ce-build-status:OK"
    exit
    ;;
*)
    TAG=v${VERSION//./_}
    ;;
esac

# use tag name as branch if otherwise unspecified
BRANCH=${BRANCH-$TAG}

# some builds checkout a tag instead of a branch
# these builds have a different prefix for ls-remote
REF=refs/heads/${BRANCH}
if [[ ! -z "${TAG}" ]]; then
    REF=refs/tags/${TAG}
fi

FULLNAME=ruby-${VERSION}
OUTPUT=$2/${FULLNAME}.tar.xz

# determine build revision
REVISION=$(git ls-remote "${URL}" "${REF}" | cut -f 1)
LAST_REVISION="${3}"

echo "ce-build-revision:${REVISION}"
echo "ce-build-output:${OUTPUT}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
  echo "ce-build-status:SKIPPED"
  exit
fi

BUILD_DIR=${ROOT}/build
STAGING_DIR=/opt/compiler-explorer/${FULLNAME}
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
mkdir -p "${BUILD_DIR}"

# Setup ruby checkout
git clone --depth 1 --single-branch -b "${BRANCH}" "${URL}" "${ROOT}/ruby"

# Generate autoconf
cd "${ROOT}/ruby"
if [[ -f "./autogen.sh" ]]; then
    ./autogen.sh
else
    # older ruby doesn't have autogen.sh
    autoreconf --install
fi

# Configure build
cd "${BUILD_DIR}"
../ruby/configure \
    --prefix="${STAGING_DIR}" \
    --disable-install-doc

# Build and install artifacts
make -j $(nproc)
make install

# Don't try to compress the binaries as they don't like it

export XZ_DEFAULTS="-T 0"
tar Jcf ${OUTPUT} --transform "s,^./,./${FULLNAME}/," -C ${STAGING_DIR} .

echo "ce-build-status:OK"

#!/bin/bash

set -ex

ROOT=$PWD
VERSION=$1

URL=https://github.com/ruby/ruby.git

case $VERSION in
trunk)
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=master
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

# determine build revision
REVISION=$(git ls-remote "${URL}" "${REF}" | cut -f 1)
LAST_REVISION="${3}"

echo "ce-build-revision:${REVISION}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
  echo "ce-build-status:SKIPPED"
  exit
fi

FULLNAME=ruby-${VERSION}
OUTPUT=${ROOT}/${FULLNAME}.tar.xz
S3OUTPUT=
if [[ $2 =~ ^s3:// ]]; then
    S3OUTPUT=$2
else
    if [[ -d "${2}" ]]; then
        OUTPUT=$2/${FULLNAME}.tar.xz
    else
        OUTPUT=${2-$OUTPUT}
    fi
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

if [[ ! -z "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi

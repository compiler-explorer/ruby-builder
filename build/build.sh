#!/bin/bash

set -ex

VERSION=$1

case $VERSION in
trunk)
    VERSION=trunk-$(date +%Y%m%d)
    TARBALL_URL=https://cache.ruby-lang.org/pub/ruby/snapshot/snapshot-master.tar.gz
    SOURCE_DIR=${ROOT}/ruby-master
    ;;
*)
    RUBY_MINOR_VERSION=${VERSION%.*}
    TARBALL_URL=https://cache.ruby-lang.org/pub/ruby/${RUBY_MINOR_VERSION}/ruby-${VERSION}.tar.gz
    SOURCE_DIR=${ROOT}/ruby-${VERSION}
    ;;
esac

FULLNAME=ruby-${VERSION}
OUTPUT=$2/${FULLNAME}.tar.xz
TARBALL_DOWNLOAD=/tmp/ruby-${VERSION}.tar.gz
INSTALL_DIR=/opt/compiler-explorer/${FULLNAME}

# determine build revision
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
mkdir -p "${SOURCE_DIR}"
curl -L "${TARBALL_URL}" | tar xzf - -C "${SOURCE_DIR}" --strip-components=1
cd "${SOURCE_DIR}"

# Configure build
./configure \
    --prefix="${INSTALL_DIR}" \
    --disable-install-doc

# Build and install artifacts
make -j $(nproc)
make install

# Don't try to compress the binaries as they don't like it

export XZ_DEFAULTS="-T 0"
tar Jcf "${OUTPUT}" --transform "s,^./,./${FULLNAME}/," -C "${INSTALL_DIR}" .

echo "ce-build-status:OK"

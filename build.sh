#!/bin/bash

REPO:=~/DrifuzzRepo
NP=$(nproc)

mkdir -p ${REPO}

sudo apt-get install -y \
build-essential flex bison git debootstrap genisoimage \
libelf-dev libssl-dev bc vim sudo fakeroot ncurses-dev \
xz-utils protobuf-compiler python3-dev python3-pip kmod \
libprotobuf-c-dev libprotoc-dev python3-protobuf g++-8 \
pkg-config libwiretap-dev libwireshark-dev wget curl \
zip protobuf-c-compiler automake software-properties-common \
libz3-dev libglib2.0-dev libpixman-1-dev

pip3 install sysv_ipc lz4 mmh3 psutil shortuuid tempdir pexpect intervaltree

git clone --depth 1 https://github.com/buszk/drifuzz-concolic.git ${REPO}/drifuzz-concolic

# Build Linux kernel
git clone --branch dev --depth 1 https://github.com/buszk/Drifuzz.git ${REPO}/Drifuzz
(cd ${REPO}/Drifuzz && \
./compile.sh --build-linux -j ${NP})

# Build panda fork
git clone --branch merge --depth 1 https://github.com/buszk/panda.git ${REPO}/panda
(cd ${REPO}/panda && \
    drifuzz/scripts/generate_filter_pc.py --vmlinux ${REPO}/Drifuzz/linux-module-build/vmlinux && \
panda/scripts/install_ubuntu.sh)
(cd ${REPO}/Drifuzz && \
./compile.sh --build-panda -j ${NP})

# Build driver modules
(cd ${REPO}/Drifuzz && \
./compile.sh --build-module)

# Download and copy linux firmware
git clone --depth 1 https://github.com/wkennington/linux-firmware.git ${REPO}/linux-firmware
(cd ${REPO}/Drifuzz/image/chroot && \
    mkdir -p lib/firmware && \
cp -r ${REPO}/linux-firmware/* lib/firmware)

# Build qcow image
(cd ${REPO}/Drifuzz && \
./compile.sh --build-image)

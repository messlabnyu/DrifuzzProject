#!/bin/bash

REPO=$HOME/DrifuzzRepo1
NP=$(nproc)

mkdir -p ${REPO}

set -ex

# Install lsb_release and git before anything else if either are missing
# Note package names should be consistent across Ubuntu versions.
# lsb_release --help &>/dev/null || $SUDO apt-get update -qq && $SUDO apt-get -qq install -y --no-install-recommends lsb-release
# git --help &>/dev/null || $SUDO apt-get -qq update && $SUDO apt-get -qq install -y --no-install-recommends git

# some globals
PANDA_GIT="https://github.com/panda-re/panda.git"
PANDA_PPA="ppa:phulin/panda"
LIBDWARF_GIT="git://git.code.sf.net/p/libdwarf/code"
UBUNTU_FALLBACK="xenial"

# system information
vendor=$(lsb_release --id | awk -F':[\t ]+' '{print $2}')
codename=$(lsb_release --codename | awk -F':[\t ]+' '{print $2}')
version=$(lsb_release -r| awk '{print $2}' | awk -F'.' '{print $1}')
arch=$(uname -m)

progress() {
  echo
  echo -e "\e[32m[build.sh]\e[0m \e[1m$1\e[0m"
}

ppa_list_file() {
  local SOURCES_LIST_D="/etc/apt/sources.list.d"
  local PPA_OWNER=$(echo "$1" | awk -F'[:/]' '{print $2}')
  local PPA_NAME=$(echo "$1" | awk -F'[:/]' '{print $3}')
  printf "%s/%s-%s-%s-%s.list" \
    "$SOURCES_LIST_D" "$PPA_OWNER" "$(echo "$2" | tr A-Z a-z)" \
    "$PPA_NAME" "$3"
}

apt_enable_src() {
  local SOURCES_LIST="/etc/apt/sources.list"
  if grep -q "^[^#]*deb-src .* $codename .*main" "$SOURCES_LIST"; then
    progress "deb-src already enabled in $SOURCES_LIST."
    return 0
  fi
  progress "Enabling deb-src in $SOURCES_LIST."
  sudo sed -E -i 's/^([^#]*) *# *deb-src (.*)/\1 deb-src \2/' "$SOURCES_LIST"
}
apt_enable_src

progress "Installing qemu dependencies..."
sudo apt-get update || true
if [ "$version" -le "19" ]; then
  sudo apt-get -y build-dep qemu
fi

progress "Installing PANDA dependencies..."
sudo apt-get -y install --no-install-recommends $(cat requirements_debian.txt | grep -o '^[^#]*')

python3 -m venv ./drifuzz_env
source ./drifuzz/bin/activate
python3 -m pip install -r requirements_python.txt

pushd /tmp

if [ "$vendor" = "Ubuntu" ]; then
  # sudo apt-get -y install software-properties-common
  panda_ppa_file=$(ppa_list_file "$PANDA_PPA" "$vendor" "$codename")
  panda_ppa_file_fallback=$(ppa_list_file "$PANDA_PPA" "$vendor" "$UBUNTU_FALLBACK")

  # add custom ppa
  case $codename in
    trusty)  ;&
    xenial)  ;&
    yakkety)
      # directly supported release
      sudo add-apt-repository -y "$PANDA_PPA"
      ;;
    *)
      # use fallback release
      sudo rm -f "$panda_ppa_file" "$panda_ppa_file_fallback"
      sudo add-apt-repository -y "$PANDA_PPA" || true
      sudo sed -i "s/$codename/$UBUNTU_FALLBACK/g" "$panda_ppa_file"
      sudo mv -f "$panda_ppa_file" "$panda_ppa_file_fallback"
      ;;
  esac

  # For Ubuntu 18.04 the vendor packages are more recent than those in the PPA
  # and will be preferred.
  # sudo apt-get update
  # sudo apt-get -y install libcapstone-dev libdwarf-dev chrpath
else
  if [ ! \( -e "/usr/local/lib/libdwarf.so" -o -e "/usr/lib/libdwarf.so" \) ]
  then
    git clone "$LIBDWARF_GIT" libdwarf-code
    pushd libdwarf-code
    progress "Installing libdwarf..."
    ./configure --prefix=/usr/local --includedir=/usr/local/include/libdwarf --enable-shared
    make -j$(nproc)
    sudo make install
    popd
  else
    progress "Skipping libdwarf..."
  fi
fi

popd

progress "Trying to update DTC submodule"
git submodule update --init dtc || true

# Drifuzz Concolic
progress "Cloning drifuzz-concolic"
git clone --depth 1 https://github.com/buszk/drifuzz-concolic.git ${REPO}/drifuzz-concolic

# Build Linux kernel
progress "Building Linux kernel..."
git clone --branch dev --depth 1 https://github.com/buszk/Drifuzz.git ${REPO}/Drifuzz
(cd ${REPO}/Drifuzz && \
./compile.sh --build-linux -j ${NP})

# Build panda fork
git clone --branch merge --depth 1 https://github.com/buszk/panda.git ${REPO}/panda
(cd ${REPO}/panda && \
    drifuzz/scripts/generate_filter_pc.py --vmlinux ${REPO}/Drifuzz/linux-module-build/vmlinux)
(cd ${REPO}/Drifuzz && \
./compile.sh --build-panda -j ${NP})

# Build driver modules
progress "Building Driver Modules..."
(cd ${REPO}/Drifuzz && \
./compile.sh --build-module)


# Build the image for the first time
progress "Building qcow Image..."
(cd ${REPO}/Drifuzz && \
./compile.sh --build-image)

# Download and copy linux firmware
progress "Building Linux firmware..."
git clone --depth 1 https://github.com/wkennington/linux-firmware.git ${REPO}/linux-firmware
(cd ${REPO}/Drifuzz/image/chroot && \
    sudo mkdir -p lib/firmware && \
sudo cp -r ${REPO}/linux-firmware/* lib/firmware)

# Build qcow image again with firmware
progress "Rebuilding qcow image with firmware..."
(cd ${REPO}/Drifuzz && \
./compile.sh --build-image)

# deactivate the virtualenv
deactivate
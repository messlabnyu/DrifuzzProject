#!/bin/bash
apt update && apt install -y sudo git
git clone https://github.com/messlabnyu/DrifuzzProject.git
export PATH=/usr/lib/llvm-11/bin:$PATH

# Avoid interactive input request from tzdata install
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
echo 'tzdata tzdata/Areas select Etc' | debconf-set-selections; \
echo 'tzdata tzdata/Zones/Etc select UTC' | debconf-set-selections; \
apt-get update -qqy \
    && apt-get install -qqy --no-install-recommends \
            tzdata

cd DrifuzzProject && ./build.sh 2>&1 |tee build.log
source ./drifuzz_env/bin/activate
cd ~/DrifuzzRepo
exit
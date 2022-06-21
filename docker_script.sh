#!/bin/bash
apt update && apt install -y sudo git
git clone https://github.com/messlabnyu/DrifuzzProject.git
export PATH=/usr/lib/llvm-11/bin:$PATH
export DEBIAN_FRONTEND=noninteractive
cd DrifuzzProject && ./build.sh 2>&1 |tee build.log
source ./drifuzz_env/bin/activate
cd ~/DrifuzzRepo
exit
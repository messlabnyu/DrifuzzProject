# DrifuzzProject

## Introduction
Peripheral hardware in modern computers is typically assumed to be secure and not malicous, and device drivers are implemented in a way that trusts inputs from hardware. In this project, we propose a hardware-free concolic-augmented fuzzer and a technique for generating high-quality initial seeds.

## How to build
### Installation
The Drifuzz project contains three major repositories: fuzzing related code, custom PANDA, concolic exploration scripts. The build script in this repository helps download them to `~/DrifuzzRepo`. The script is tested in Ubuntu 20, and Ubuntu 21 could be supported with [the patch](https://github.com/buszk/Drifuzz/blob/dev/ubuntu_21.patch).

```bash
git clone https://github.com/messlabnyu/DrifuzzProject.git
cd DrifuzzProject && ./build.sh 2>&1 |tee build.log
# Activate python env
source ./drifuzz_env/bin/activate
```
### Docker alternative
If you wish to skip installation, we conveniently provide a docker image. You must start the container with `--privileged` flag for QEMU-KVM to work.
```bash
docker run -it --privileged buszk/drifuzz-docker
# Inside docker
source /DrifuzzProject/drifuzz_env/bin/activate
```

## How to run
### Prerequisite
Please check if the following files are created correctly. If any of the file was not created properly, please check the build log and script to triage the problem.
```bash
cd ~/DrifuzzRepo/Drifuzz
ls image/buster.img
ls panda-build/x86_64-softmmu/panda-system-x86_64
ls panda-build/x86_64-softmmu/panda/plugins/panda_taint2.so
ls linux-module-build/vmlinux
```

### Concolic tracing
```bash
cd ~/DrifuzzRepo/drifuzz-concolic

# Create a driver specific snapshot
./snapshot_helper.py ath9k
ls work/ath9k/ath9k.qcow2 # should exists

# Run concolic script with random input
head -c 4096 /dev/urandom >rand
./concolic.py ath9k rand
cat work/ath9k/drifuzz_path_constraints # path constraints
cat work/ath9k/drifuzz_index # accessed MMIO/DMA
ls work/ath9k/out # generated inputs with flipped branch
```

### Golden seed
```bash
cd ~/DrifuzzRepo/drifuzz-concolic
# Run the golden seed script
./search_greedy.py ath9k rand
ls work/ath9k/out/0 # generated seed
```

### Fuzzing
```bash
cd ~/DrifuzzRepo/Drifuzz

# Fuzz ath9k with random seed on 4 cores
fuzzer/drifuzz.py -D -p 4 seed/seed-random work/ath9k ath9k
# Ctrl^C once to stop

# Reproduce a generated input
scripts/reproduce.sh ath9k work/ath9k/ work/ath9k/corpus/payload_1

# Process stacktrace when you see a crash
scripts/decode_stacktrace.sh crash.log
```

We also provide some helpful scripts to combine our golden seed and concolic support with our fuzzer. 
<span style="color:gray">Note: You need to run the golden seed generation script before running some of the following scripts.</span>
```bash
cd ~/DrifuzzRepo/Drifuzz

# Fuzzing random input without concolic support
scripts/run_random.sh ath9k
# Fuzzing random input with concolic support
scripts/run_conc_rand.sh ath9k
# Fuzzing golden seed without concolic support
scripts/run_model.sh ath9k
# Fuzzing golden seed with concolic support
scripts/run_conc_model.sh ath9k
```

### Experimentation
You can find notes about our experiemntation in the paper [here](https://github.com/messlabnyu/DrifuzzProject/blob/main/EXPERIMENTATION.md).
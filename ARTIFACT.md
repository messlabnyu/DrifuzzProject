# Artifact Evaluation

## Abstract
Our artifact includes three major parts: hardware-free device driver fuzzer, modified PANDA/QEMU with full-system concolic tracing support and concolic code exploration scripts. The code require a 64-bit x86 system with clean Ubuntu 20.04 install.

## Checklist
* Compilation: It's best to use the default Ubuntu 20.04 compilers
* Run-time environment: Linux (preferably Ubuntu 20.04)
* Hardware: 64-bit x86 computer
* Disk space: 40G
* Publicly available: Github

## Description
### How to access
Clone from https://github.com/messlabnyu/DrifuzzProject/
### Hardware Dependencies
64-bit x86 machine.
### Software Dependencies
Ubuntu 20.04

## Installation
```
git clone https://github.com/messlabnyu/DrifuzzProject.git
cd DrifuzzProject && ./build.sh 2>&1 |tee build.log
```

## Evaluation and Expected Results
Evaluation should show that Drifuzz is able to perform concolic tracing in device driver execution and our golden seed search algorithm is able to provide a good initial seed resulting more code coverage.


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

### Coverage comparison
You can compare coverage of different settings by checking the fuzzing UI, or use the following command. Generally, you can observe that settings using the golden seed ("model") have more coverage than those which doesn't. Concolic settings often outperform conventional random mutation methods.
```
tail -n1 work/work-ath9k-random/evaluation/data.csv |awk -F';' '{print $16}'
tail -n1 work/work-ath9k-conc/evaluation/data.csv |awk -F';' '{print $16}'
tail -n1 work/work-ath9k-model/evaluation/data.csv |awk -F';' '{print $16}'
tail -n1 work/work-ath9k-conc-model/evaluation/data.csv |awk -F';' '{print $16}'
```

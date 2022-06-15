
# Experimentation Note

This page contains the details for running some of the experiementation in the paper. Note that we cannot garantee that Agamotto and SymDrive work as intended on your setup, but we include as much information here to help you get them to work.

## Ablation Study

```bash
cd ~/DrifuzzRepo/Drifuzz
# Edit scripts/fuzz.sh for num_trial and targets to test
# By default, the script runs 7 targets with 4 setting for 10 trials, which takes 280 hours.

# Run ablation test
scripts/fuzz.sh

# Collect statistics
# NOTE: small num_trail (<10) can make p-value less significant
scripts/stats.py
```

## Agamotto vs Drifuzz
First, install Agamotto with instructions from [our repository](https://github.com/buszk/agamotto).
NOTE: You have to compile and load Agamotto's custom kernel. There might be issues with drivers because they may not exist in Linux v4.18. If your machine is relatively old, drivers should work fine.

### PCI drivers
You can probably skip running Drifuzz in this experiment by using results from ablation study.
```bash
cd $AGPATH/scripts
./bench_pci.py
# Collect statistics
cd ~/DrifuzzRepo/Drifuzz
scripts/stats.py --agamotto
```

### USB drivers
```bash
# Fuzz USB drivers with Agamotto
cd $AGPATH/scripts
./bench_usb.py
```

Then, you need to modify Drifuzz to collect block coverage.
TODO: gen diff.
```bash
cd ~/DrifuzzRepo/Drifuzz
scripts/bench_usb.sh
# Collect statistics
scripts/stats.py --usb
```

## SymDrive
```bash
docker create --name symdrive --privileged -p 5902:5902 -it buszk/symdrive:latest
docker start -ai symdrive

## Inside docker container
cd s2e/symdrive/qemu && tar xvf ./i386.tbz

# Run tmux for multiple windows in docker container
tmux

# Start chroot jail
cd ~/s2e/symdrive/qemu && ./debian32.sh

# Inside chroot jail
# Supported targets are ath5k ath9k atmel orinoco
cd /root/test && ./make.sh ath5k

# New Tab in tmux
# Ctrl-b C
./qemu.sh 4982 ath5k 10

# Wait for initialization about a minute
# Then copy compiled files and create snapshot
./qemu.sh 1000

# Start symbolic qemu
./qemu.sh ath5k 11

# Use a VNC software to connect to localhost:5902 which is exposed by docker container
# Inside VNC
./insmod_pre.sh # helper script to load dep
insmod ath5k-stub.ko
# Check network interface
ip link
```

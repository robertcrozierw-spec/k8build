#!/usr/bin/env bash
# This script creates Lima VMs, one for each YAML config file listed below.
# Edit the filenames below to match YAML location, then run: ./create_VMs.sh

# List yaml files here
VM1="./VMs/jumpbox.yaml"
VM2="./VMs/server.yaml"
VM3="./VMs/node-0.yaml"
VM4="./VMs/node-1.yaml"

# For each yaml file, "limactl start" will:
#   - create a new VM using that config
#   - name it whatever we pass to --name
#   - start it up automatically
limactl start --name=jumpbox "$VM1" --tty=false
limactl start --name=server "$VM2" --tty=false
limactl start --name=node-0 "$VM3" --tty=false
limactl start --name=node-1 "$VM4" --tty=false

# Show the status of all VMs
limactl list
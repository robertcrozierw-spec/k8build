# K8build

Personal project to build Kubernetes cluster from scratch
Main learning goal is to gain bottom up understanding of clusters

## Prerequisites 
First we need to configure 4 VMs, as I am using a Macbook and plan on building everything locally I will use "Lima"
Lima was chosen for its ease of use and flexible network configuration options.

4 yaml files are specified in the VMs diecroty. For now the command will need to ran manually to create each one:
limactl create --name=nameofVM ./locationofyaml

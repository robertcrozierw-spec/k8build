# Prerequisites

First I need to configure 4 VMs. As I am using a MacBook and plan on building everything locally, I will use [Lima](https://lima-vm.io/). Lima was chosen for its ease of use and flexible network configuration options.

## Create VMs
The 4 YAML files are in the [`VMs`](./VMs/) folder of this repo. Initially I used the following command to create each VM:

```bash
limactl create --name=nameofVM ./locationofyaml
```
Moving forward I will use the [`createVM.sh`](./VMs/createVMs.sh) script instead.
I have also included [`delerteVM.sh`](./VMs/deleteVMs.sh), as it can be used to destroy environment if no longer required.

## Networking

All VMs and the host need to be able to communicate with each other over SSH, so I went with the `socket_vmnet` (shared) option. This is configured with:

```yaml
networks:
- lima: shared
```

This provides 2 network interfaces on each VM:

- `eth0` has the IP `192.168.5.15`. It is a special IP used by Lima's internal tools to talk to the VMs. It is the same on all of the VMs.
- `lima0` has an IP in the `192.168.105.x` range. This is the IP used for communication between the VMs and the host using standard IP routing. It is what gets configured by the `shared` option.

In shared mode, a virtual network is configured by Lima, with DHCP handled internally. This is fine for my lab environment, but it would cause issues if I wanted to add external devices to the network.

In future projects, bridged mode may be used instead, which would allow external devices to connect. However, the caveat in bridged mode is DHCP is handled by the external router, which could change the IPs and range of the VMs.

## Provisioning Pod Network Routes

We need to configure routes between the Nodes as right now pods created on each will not have access to other

Using our machines.txt we will seperate the IPs of VM and also the IP subnet each node will use to assign to pods

       {
         SERVER_IP=$(grep server machines.txt | cut -d " " -f 1)
         NODE_0_IP=$(grep node-0 machines.txt | cut -d " " -f 1)
         NODE_0_SUBNET=$(grep node-0 machines.txt | cut -d " " -f 4)
         NODE_1_IP=$(grep node-1 machines.txt | cut -d " " -f 1)
         NODE_1_SUBNET=$(grep node-1 machines.txt | cut -d " " -f 4)
       }
       
Lets print out the values to confirm what we have:
       {
       echo SERVER_IP $SERVER_IP
       echo NODE_0_IP $NODE_0_IP
       echo NODE_0_SUBNET $NODE_0_SUBNET
       echo NODE_1_IP $NODE_1_IP
       echo NODE_1_SUBNET $NODE_1_SUBNET
       }

output:
```
SERVER_IP 192.168.105.5
NODE_0_IP 192.168.105.6
NODE_0_SUBNET 10.200.0.0/24
NODE_1_IP 192.168.105.7
NODE_1_SUBNET 10.200.1.0/24
```

### Add the routes
A network route is a manual entry that creates a pathway to reach another network when access is not already configured

We will make it that the node_$_IP is the gateway for its corresponding SUBNET
We will need to do this for all 3 of our server
We will use the " ip route add "destination" via "gateway" "

        ssh root@server <<EOF
          ip route add ${NODE_0_SUBNET} via ${NODE_0_IP}
          ip route add ${NODE_1_SUBNET} via ${NODE_1_IP}
        EOF

We can run the ip table show command on the SERVER VM after and see the routes have been added
10.200.0.0/24 via 192.168.105.6 dev lima0 
10.200.1.0/24 via 192.168.105.7 dev lima0 

For the node-0 VM
        ssh root@node-0 <<EOF
          ip route add ${NODE_1_SUBNET} via ${NODE_1_IP}
        EOF

output:
10.200.1.0/24 via 192.168.105.7 dev lima0 

For the node-1 VM
        ssh root@node-1 <<EOF
          ip route add ${NODE_0_SUBNET} via ${NODE_0_IP}
        EOF

output:
10.200.0.0/24 via 192.168.105.6 dev lima0 
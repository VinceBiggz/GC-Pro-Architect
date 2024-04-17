#Here we start the creation of the Cloud network and instances
#Set up a Global VPC environment

#In Cloud Shell, create a VPC network called vpc-demo:
gcloud compute networks create vpc-demo --subnet-mode custom

#In Cloud Shell, create subnet vpc-demo-subnet1 in the region us-central1:
gcloud compute networks subnets create vpc-demo-subnet1 \
    --network vpc-demo \
    --range 10.1.1.0/24 \
    --region "us-central1"

#In Cloud Shell, create subnet vpc-demo-subnet2 in the region us-east4:
gcloud compute networks subnets create vpc-demo-subnet2 \
    --network vpc-demo \
    --range 10.2.1.0/24 \
    --region us-east4

#Create a firewall rule to allow all custom traffic within the network:
gcloud compute firewall-rules create vpc-demo-allow-custom \
  --network vpc-demo \
  --allow tcp:0-65535,udp:0-65535,icmp \
  --source-ranges 10.0.0.0/8

#Create a firewall rule to allow SSH, ICMP traffic from anywhere:
gcloud compute firewall-rules create vpc-demo-allow-ssh-icmp \
    --network vpc-demo \
    --allow tcp:22,icmp

#Create a VM instance vpc-demo-instance2 in zone us-east4-a:
gcloud compute instances create vpc-demo-instance2 \
    --machine-type=e2-medium \
    --zone us-east4-a \
    --subnet vpc-demo-subnet2

#Create a VM instance vpc-demo-instance1 in zone us-central1-a:
gcloud compute instances create vpc-demo-instance1 \
    --machine-type=e2-medium \
    --zone us-central1-a \
    --subnet vpc-demo-subnet1

#Here, we start creating the on-prem network and instances
#Set up a simulated on-premises environment

#In Cloud Shell, create a VPC network called on-prem:
gcloud compute networks create on-prem \
    --subnet-mode custom

#Create a subnet called on-prem-subnet1:
gcloud compute networks subnets create on-prem-subnet1 \
    --network on-prem \
    --range 192.168.1.0/24 \
    --region us-central1

#Create a firewall rule to allow all custom traffic within the network:
gcloud compute firewall-rules create on-prem-allow-custom \
    --network on-prem \
    --allow tcp:0-65535,udp:0-65535,icmp \
    --source-ranges 192.168.0.0/16

#Create a firewall rule to allow SSH, RDP, HTTP, and ICMP traffic to the instances:
gcloud compute firewall-rules create on-prem-allow-ssh-rdp-http-icmp \
    --network on-prem \
    --allow tcp:22,tcp:3389,tcp:80,icmp

#Create an instance called on-prem-instance1 in the region us-central1.
gcloud compute instances create on-prem-instance1 \
    --machine-type=e2-medium \
    --zone us-central1-b \
    --subnet on-prem-subnet1

#Here, we create a HA VPN Gateway
#Set up an HA VPN gateway

#In Cloud Shell, create an HA VPN in the vpc-demo network:
gcloud compute vpn-gateways create vpc-demo-vpn-gw1 \
    --network vpc-demo \
    --region us-central1

#Create an HA VPN in the on-prem network:
gcloud compute vpn-gateways create on-prem-vpn-gw1 \
    --network on-prem \
    --region us-central1

#View details of the vpc-demo-vpn-gw1 gateway to verify its settings:
gcloud compute vpn-gateways describe vpc-demo-vpn-gw1 \
    --region us-central1

#View details of the on-prem-vpn-gw1 vpn-gateway to verify its settings:
gcloud compute vpn-gateways describe on-prem-vpn-gw1 \
    --region us-central1


#Here, we create cloud routers

#Create a cloud router in the vpc-demo network:
gcloud compute routers create vpc-demo-router1 \
    --network vpc-demo \
    --region us-central1 \
    --asn 65001

#Create a cloud router in the on-prem network:
gcloud compute routers create on-prem-router1 \
    --network on-prem \
    --region us-central1 \
    --asn 65002

#Create 2 VPN Tunnels

#Create the first VPN tunnel in the vpc-demo network:
gcloud compute vpn-tunnels create vpc-demo-tunnel0 \
    --peer-gcp-gateway on-prem-vpn-gw1 \
    --region us-central1 \
    --ike-version 2 \
    --shared-secret [SHARED_SECRET] \
    --router vpc-demo-router1 \
    --vpn-gateway vpc-demo-vpn-gw1 \
    --interface 0

#Create the second VPN tunnel in the vpc-demo network:
gcloud compute vpn-tunnels create vpc-demo-tunnel1 \
    --peer-gcp-gateway on-prem-vpn-gw1 \
    --region us-central1 \
    --ike-version 2 \
    --shared-secret [SHARED_SECRET] \
    --router vpc-demo-router1 \
    --vpn-gateway vpc-demo-vpn-gw1 \
    --interface 1

#Create the first VPN tunnel in the on-prem network:
gcloud compute vpn-tunnels create on-prem-tunnel0 \
    --peer-gcp-gateway vpc-demo-vpn-gw1 \
    --region us-central1 \
    --ike-version 2 \
    --shared-secret [SHARED_SECRET] \
    --router on-prem-router1 \
    --vpn-gateway on-prem-vpn-gw1 \
    --interface 0

#Create the second VPN tunnel in the on-prem network:
gcloud compute vpn-tunnels create on-prem-tunnel1 \
    --peer-gcp-gateway vpc-demo-vpn-gw1 \
    --region us-central1 \
    --ike-version 2 \
    --shared-secret [SHARED_SECRET] \
    --router on-prem-router1 \
    --vpn-gateway on-prem-vpn-gw1 \
    --interface 1

#Create Border Gateway Protocol (BGP) peering for each tunnel

#Create the router interface for tunnel0 in network vpc-demo:
gcloud compute routers add-interface vpc-demo-router1 \
    --interface-name if-tunnel0-to-on-prem \
    --ip-address 169.254.0.1 \
    --mask-length 30 \
    --vpn-tunnel vpc-demo-tunnel0 \
    --region us-central1

#Create the BGP peer for tunnel0 in network vpc-demo:
gcloud compute routers add-bgp-peer vpc-demo-router1 \
    --peer-name bgp-on-prem-tunnel0 \
    --interface if-tunnel0-to-on-prem \
    --peer-ip-address 169.254.0.2 \
    --peer-asn 65002 \
    --region us-central1

#

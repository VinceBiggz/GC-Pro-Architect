# Set the REGION variable by removing the substring after the last hyphen in the ZONE variable.
export REGION="${ZONE%-*}"

# Create a VPC named "nucleus-vpc" with auto-generated subnet mode.
gcloud compute networks create nucleus-vpc --subnet-mode=auto

# Create a compute instance named $INSTANCE_NAME within the nucleus-vpc network, in the specified zone, with specified machine type and Debian 10 image.
gcloud compute instances create $INSTANCE_NAME \
          --network nucleus-vpc \
          --zone $ZONE  \
          --machine-type e2-micro  \
          --image-family debian-10  \
          --image-project debian-cloud 

# Create a Google Kubernetes Engine (GKE) cluster named "nucleus-backend" with 1 node, within the nucleus-vpc network, in the specified zone.
gcloud container clusters create nucleus-backend \
--num-nodes 1 \
--network nucleus-vpc \
--zone $ZONE

# Get credentials for the "nucleus-backend" GKE cluster in the specified zone.
gcloud container clusters get-credentials nucleus-backend \
--zone $ZONE

# Create a Kubernetes deployment named "hello-server" using the specified Docker image.
kubectl create deployment hello-server \
--image=gcr.io/google-samples/hello-app:2.0
  
# Expose the "hello-server" deployment to the internet as a LoadBalancer service on the specified port.
kubectl expose deployment hello-server \
--type=LoadBalancer \
--port $PORT

# Create a startup script named "startup.sh" to update packages, install nginx, start nginx, and modify the default nginx page.
cat << EOF > startup.sh
#! /bin/bash
apt-get update
apt-get install -y nginx
service nginx start
sed -i -- 's/nginx/Google Cloud Platform - '"\$HOSTNAME"'/' /var/www/html/index.nginx-debian.html
EOF

# Create a compute instance template named "web-server-template" with the startup script, within the nucleus-vpc network, using g1-small machine type, in the specified region.
gcloud compute instance-templates create web-server-template \
--metadata-from-file startup-script=startup.sh \
--network nucleus-vpc \
--machine-type g1-small \
--region $ZONE

# Create a target pool named "nginx-pool" in the specified region.
gcloud compute target-pools create nginx-pool --region=$REGION

# Create a managed instance group named "web-server-group" with 2 instances, using the "web-server-template", in the specified region.
gcloud compute instance-groups managed create web-server-group \
--base-instance-name web-server \
--size 2 \
--template web-server-template \
--region $REGION

# Create a firewall rule allowing TCP traffic on port 80 within the nucleus-vpc network.
gcloud compute firewall-rules create $FIREWALL_NAME \
--allow tcp:80 \
--network nucleus-vpc

# Create an HTTP health check named "http-basic-check".
gcloud compute http-health-checks create http-basic-check

# Set named ports for the "web-server-group" instance group to route HTTP traffic to port 80, in the specified region.
gcloud compute instance-groups managed \
set-named-ports web-server-group \
--named-ports http:80 \
--region $REGION

# Create an HTTP backend service named "web-server-backend" with HTTP protocol and linked to the "http-basic-check" health check, globally.
gcloud compute backend-services create web-server-backend \
--protocol HTTP \
--http-health-checks http-basic-check \
--global

# Add the "web-server-group" as a backend to the "web-server-backend" service, globally.
gcloud compute backend-services add-backend web-server-backend \
--instance-group web-server-group \
--instance-group-region $REGION \
--global

# Create a URL map named "web-server-map" with the "web-server-backend" as the default service.
gcloud compute url-maps create web-server-map \
--default-service web-server-backend

# Create a target HTTP proxy named "http-lb-proxy" with the "web-server-map" URL map.
gcloud compute target-http-proxies create http-lb-proxy \
--url-map web-server-map

# Create a global forwarding rule named "http-content-rule" to route incoming HTTP traffic to the "http-lb-proxy" target HTTP proxy on port 80.
gcloud compute forwarding-rules create http-content-rule \
--global \
--target-http-proxy http-lb-proxy \
--ports 80

# Create a global forwarding rule with the specified name to route incoming HTTP traffic to the "http-lb-proxy" target HTTP proxy on port 80.
gcloud compute forwarding-rules create $FIREWALL_NAME \
--global \
--target-http-proxy http-lb-proxy \
--ports 80

# List the forwarding rules.
gcloud compute forwarding-rules list

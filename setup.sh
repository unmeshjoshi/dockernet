#!/bin/bash

# Install required packages
apt-get update
apt-get install -y \
    iproute2 \
    iputils-ping \
    net-tools \
    tcpdump \
    iptables \
    bridge-utils \
    curl

apt-get install -y ca-certificates curl 
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y

apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin net-tools
service docker stop
ulimit -n 65536 in /etc/init.d/docker
service docker start


# Function to wait for Docker to be ready
wait_for_docker() {
    echo "Waiting for Docker to start..."
    local max_attempts=30
    local attempt=1
    
    while ! docker info >/dev/null 2>&1; do
        if [ $attempt -gt $max_attempts ]; then
            echo "Docker did not start within $max_attempts attempts"
            exit 1
        fi
        echo "Attempt $attempt/$max_attempts: Docker is not ready yet..."
        sleep 2
        attempt=$((attempt + 1))
    done
    echo "Docker is ready!"
}

# Wait for Docker to be ready
wait_for_docker

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Following the instructions from https://docs.docker.com/network/bridge/

# A bridge network for the containers to communicate on
docker network create -o com.docker.network.bridge.name=docker_br \
        --subnet 10.0.0.0/24 vxlan-net


# Setup VXLAN
if [ "$(hostname)" = "node1" ]; then
    # Node1 VXLAN setup
    ip link add vxlan-demo type vxlan id 100 remote 192.168.56.11 dstport 4789 
    ip link set vxlan-demo up

    # Add the vxlan interface to the docker bridge
    brctl addif docker_br vxlan-demo

    # Start nginx container
    docker run -d --name web1 --ip 10.0.0.2 --network vxlan-net nginx
    
elif [ "$(hostname)" = "node2" ]; then
    # Node2 VXLAN setup
    ip link add vxlan-demo type vxlan id 100 remote 192.168.56.10 dstport 4789 
    ip link set vxlan-demo up
    # Add the vxlan interface to the docker bridge
    brctl addif docker_br vxlan-demo

    # Start nginx container
    docker run -d --name web2  --ip 10.0.0.12 --network vxlan-net nginx 
   
fi 

# Keep the script running
echo "Setup completed, keeping container alive..."
tail -f /dev/null
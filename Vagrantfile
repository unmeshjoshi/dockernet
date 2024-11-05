# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "perk/ubuntu-2204-arm64"
  config.vm.provider "qemu" do |qemu|
    # set the port of your preference
    qemu.ssh_port = "8888"
  end 
  config.vm.network "public_network", use_dhcp_assigned_default_route: true
  config.vm.provision "shell", path: "docker-install.sh"
end

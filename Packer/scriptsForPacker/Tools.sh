#!/bin/bash

#disable OS firewall
sudo ufw disable

#make debconf non-interactive
echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections

#update ubuntu respository links
sudo apt-get update

#install unzip, jq
#install build-essential, zlib1g-dev, libssl-dev --> (to compile files in Patching.sh)
sudo apt-get --assume-yes -o DPkg::Lock::Timeout=600  install unzip jq build-essential zlib1g-dev libssl-dev

#install awscli v2
sudo mkdir /temp && sudo chmod 755 /temp && cd /temp
sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo unzip -q awscliv2.zip
sudo ./aws/install 1>/dev/null

#update snap packages
sudo snap refresh

#assign loop value
sha256_match=false
#vault version value
vault_version="1.16.2"

# Loop until SHA1 hashes match
while [ $sha256_match = false ]; 
do
    #download vault .zip
    vault_releases="https://releases.hashicorp.com"
    vault_latest_release="/vault/${vault_version}"
    latest_vault=$(sudo curl -kL "$vault_releases$vault_latest_release" | egrep -o "vault_[0-9.]+_linux_amd64.zip" | head -n 1)
    sudo curl -kfLRO "$vault_releases$vault_latest_release/$latest_vault"

    #assign local value
    sha256_local=$(sudo sha256sum /temp/vault_1.16.2_linux_amd64.zip| awk '{print $1}')

    #download vault .sha
    vault_releases="https://releases.hashicorp.com"
    vault_latest_release="/vault/${vault_version}"
    latest_vault_sha=$(sudo curl -kL "$vault_releases$vault_latest_release" | egrep -o "vault_[0-9.]+_SHA256SUMS" | head -n 1)
    sudo curl "$vault_releases$vault_latest_release/$latest_vault_sha" -o /temp/sha256_vault

    #assign remote value
    sha256_remote=$(sudo cat /temp/sha256_vault | grep "vault_${vault_version}_linux_amd64.zip" | awk '{print $1}')

    #compare local and remote value
    if [ $sha256_local = $sha256_remote ]; 
    then
        echo "Hashes match, vault will now install"
        sha256_match=true
    else
        echo "Hashes do not match"
        echo "Retrying..."
        sleep 5 # Wait for 5 seconds before retrying
    fi
done

#unzip to sbin
cd /temp
sudo unzip "$latest_vault" -d /usr/sbin
#!/bin/sh

#install jq
apk add jq

#install curl
apk add curl

#install awscli
apk add aws-cli

#assign loop value
sha256_match=false
#vault version value
vault_version="1.16.2"

# Loop until SHA1 hashes match
mkdir /temp
cd /temp
while [ $sha256_match = false ]; 
do
    #download vault .zip
    vault_releases="https://releases.hashicorp.com"
    vault_latest_release="/vault/${vault_version}"
    latest_vault=$(curl -kL "$vault_releases$vault_latest_release" | egrep -o "vault_[0-9.]+_linux_amd64.zip" | head -n 1)
    curl -kfLRO "$vault_releases$vault_latest_release/$latest_vault"

    #assign local value
    sha256_local=$(sha256sum /temp/vault_1.16.2_linux_amd64.zip| awk '{print $1}')

    #download vault .sha
    vault_releases="https://releases.hashicorp.com"
    vault_latest_release="/vault/${vault_version}"
    latest_vault_sha=$(curl -kL "$vault_releases$vault_latest_release" | egrep -o "vault_[0-9.]+_SHA256SUMS" | head -n 1)
    curl "$vault_releases$vault_latest_release/$latest_vault_sha" -o /temp/sha256_vault

    #assign remote value
    sha256_remote=$(cat /temp/sha256_vault | grep "vault_${vault_version}_linux_amd64.zip" | awk '{print $1}')

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
unzip "$latest_vault" -d /usr/sbin
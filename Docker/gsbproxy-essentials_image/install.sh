#!/bin/sh

#install jq
apk add jq

#install coreutils to use "date" command properly
apk add coreutils

#install curl
apk add curl

#install awscli
apk add aws-cli

#install Terraform 1.8.2
curl https://releases.hashicorp.com/terraform/1.8.2/terraform_1.8.2_linux_amd64.zip -o terraform.zip
unzip terraform.zip
mv terraform /usr/bin/terraform

#install Packer
wget https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_linux_amd64.zip
unzip packer_1.9.4_linux_amd64.zip -d /usr/local/bin
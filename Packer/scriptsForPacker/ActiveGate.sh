#!/bin/bash

#retrieve PAAS Token to dynatrace cluster
export paas_token=$(sudo aws secretsmanager get-secret-value --secret-id dp/shs/$environment/gsbproxy-dynatrace/paas-token --query SecretString --output text | jq -r .Token)

#Download ActiveGate installer
cd /temp
sudo curl -kX GET "https://$apmaas_vpc_endpoint/e/$dynatrace_tui_cluster_id/api/v1/deployment/installer/gateway/unix/latest?arch=x86" -H  "Authorization: Api-Token $paas_token" --output "Dynatrace-ActiveGate-Linux.sh"
sudo chmod u+x Dynatrace-ActiveGate-Linux.sh

#install ActiveGate
sudo ./Dynatrace-ActiveGate-Linux.sh --ignore-cluster-runtime-info SERVER=https://$apmaas_vpc_endpoint:443/communication --set-group=GSB_Proxy

#stop configured service
sudo systemctl disable dynatracegateway
sudo systemctl stop dynatracegateway

#remove files to let it generate unique values on startup
sudo rm /var/lib/dynatrace/gateway/config/id.properties
sudo rm /var/lib/dynatrace/gateway/config/eec.token
#!/bin/bash

#retrieve PAAS Token to dynatrace cluster
export paas_token=$(sudo aws secretsmanager get-secret-value --secret-id dp/shs/$environment/gsbproxy-dynatrace/paas-token --query SecretString --output text | jq -r .Token)

#download OneAgent installer
cd /temp
sudo curl -kX GET "https://$apmaas_vpc_endpoint/e/$dynatrace_tui_cluster_id/api/v1/deployment/installer/agent/unix/default/latest?arch=x86&flavor=default" -H  "Authorization: Api-Token $paas_token" --output "Dynatrace-OneAgent-Linux.sh"
sudo chmod u+x Dynatrace-OneAgent-Linux.sh

#install OneAgent
sudo ./Dynatrace-OneAgent-Linux.sh --set-infra-only=false --set-app-log-content-access=true --set-host-group=GSB_Proxy

#stop configured service
sudo systemctl disable oneagent
sudo systemctl stop oneagent
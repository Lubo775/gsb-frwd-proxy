#!/bin/sh

#export outbound proxy variables (has to be first step in bootstrap !)
export http_proxy="socks5h://${op_username}:${op_password}@proxy.saas.vwapps.cloud:8000"
export https_proxy="socks5h://${op_username}:${op_password}@proxy.saas.vwapps.cloud:8000"
export no_proxy="169.254.169.254,.vwgroup.com,.vwg,.internal,.amazonaws.com"

#variables needed for bootstrap
export dynatrace_cluster_id="${dynatrace_cluster_id}"
export apmaas_vpc_endpoint="${apmaas_vpc_endpoint}"
export ENVIRONMENT="${environment}"
export active_gate_clb="${active_gate_clb}"
export VAULT_ADDR="${vault_address}"
export ORG_SCOPE="${org_scope}"
export FUNC_SCOPE="${func_scope}"
export STAGE="${stage}"
export VAULT_SKIP_VERIFY=true
export AWS_IAM_ROLE="${aws_iam_role}"


export dynatrace_bucket="${s3_bucket}"
export VAULT_PATH="${vault_path}"
export CONCOURSE_NAME="${concourse_name}"
export CONCOURSE_TEAM="${concourse_team}"
export NAME="${instance_name}"
export APP="${application_id}"
export HOST=$(hostname)
export REGION="${region}"
export MODULE_NAME_S3="${module_name}-activegate"
export MODULE_NAME="${module_name}-dynatrace"
export APPLICATION_VERSION="${app_version}"
export PROJECTID="${project_id}"
export TIER="${tier}"
export OWNEREMAIL="${owner_email}"
export NETWORK="${network}"
export SC_ASS_GROUP="${sc_ass_group}"
export SC_CI_NAME="${sc_ci_name}"
export PLT_NAME="${platform_name}"
export APPLICATION_ID="${application_id}"
export SHIPPER_NAME=$(hostname)_vpc_${org_scope}_${func_scope}_${environment}
export METRICBEAT=1
export HEARTBEAT=1

###########################################
##Configure ActiveGate for specific stage##
###########################################

#replace cluster id with correct value
sed -i "1s/\[\(.*\)\]/[$dynatrace_cluster_id]/" /var/lib/dynatrace/gateway/config/authorization.properties

#replace tenantToken with correct value
export paas_token=$(aws secretsmanager get-secret-value --secret-id dp/shs/$ENVIRONMENT/gsbproxy-dynatrace/paas-token --query SecretString --output text | jq -r .Token)
export tenantToken=$(curl -kX GET "https://$apmaas_vpc_endpoint/e/$dynatrace_cluster_id/api/v1/deployment/installer/agent/connectioninfo" -H  "Authorization: Api-Token $paas_token" | jq -r .tenantToken)
sed -i "2s/=.*/= $tenantToken/" /var/lib/dynatrace/gateway/config/authorization.properties

#generate activegate token 
export activegate_token=$(curl -kX POST \
	--url https://$apmaas_vpc_endpoint/e/$dynatrace_cluster_id/api/v2/activeGateTokens \
  	--header "Authorization: Api-Token $paas_token" \
  	--header 'Content-Type: application/json' \
  	--data '{
  	"name": "gsbproxy-activegate-token",
  	"activeGateType": "ENVIRONMENT",
  	"seedToken": "false",
  	"expirationDate": "now+90d/d"
	}' | jq -r .token)

#replace activegate token with correct value
sed -i "3s/=.*/= $activegate_token/" /var/lib/dynatrace/gateway/config/authorization.properties

#set DNSENTRYPOINT (our clb url)
sed -i "2a\dnsEntryPoint = https://$active_gate_clb:9999" /var/lib/dynatrace/gateway/config/custom.properties

#replace seedServerUrl value with correct apmaas endpoint
sed -i "/seedServerUrl/s/=.*/= https:\/\/$apmaas_vpc_endpoint:443\/communication/" /var/lib/dynatrace/gateway/config/config.properties

#enable activegate on startup
systemctl enable dynatracegateway

#start activegate
systemctl start dynatracegateway

########################################################################################################################################################################################################################################

######################################
##Configure Vault for specific stage##
######################################

#retrieve self-signed certificate
VAULT_SERVER=$(echo $VAULT_ADDR | cut -d/ -f3)
openssl s_client -showcerts -connect $VAULT_SERVER:443 -servername $VAULT_SERVER </dev/null 2>/dev/null|sed -n '/^-----BEGIN CERT/,/^-----END CERT/p' > /tmp/ca.pem
export VAULT_CACERT="/tmp/ca.pem"

#generate random nonce
[ ! -f /etc/nonce ] && openssl rand -base64 36 > /etc/nonce

#authenticate and acquire the token
export TOKEN_IMDSv2=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
export VAULT_TOKEN=$(vault write -field=token auth/$ORG_SCOPE.$FUNC_SCOPE.aws-auth.$STAGE/login \
	role="$AWS_IAM_ROLE" \
	identity=$( curl -sS -H "X-aws-ec2-metadata-token: $TOKEN_IMDSv2" http://169.254.169.254/latest/dynamic/instance-identity/document | base64 -w 0 ) \
	signature=$( curl -sS -H "X-aws-ec2-metadata-token: $TOKEN_IMDSv2" http://169.254.169.254/latest/dynamic/instance-identity/signature | paste -s -d '' ) \
	nonce=@/etc/nonce \
	header_value=$ORG_SCOPE.$FUNC_SCOPE.vault.$STAGE)

########################################################################################################################################################################################################################################

######################################
##Configure Beats for specific stage##
######################################

#download beats script
aws s3 cp s3://bkt.$ORG_SCOPE.$FUNC_SCOPE.gsbproxy-nginx.$ENVIRONMENT/beatsScript/configure-beats.sh /temp/configure-beats.sh

#run configuration script
bash /temp/configure-beats.sh

#add activegate-availability.yml for heartbeat
aws s3 cp s3://bkt.$ORG_SCOPE.$FUNC_SCOPE.gsbproxy-activegate.$ENVIRONMENT/beatsScript/heartbeat/monitors.d/activegate-availability.yml /etc/heartbeat/monitors.d/activegate-availability.yml 

#enable metricbeat on startup
systemctl enable metricbeat

#start metricbeat
systemctl start metricbeat

#enable heartbeat on startup
systemctl enable heartbeat-elastic

#start heartbeat
systemctl start heartbeat-elastic

########################################################################################################################################################################################################################################

#make env persistent
env > /etc/environment

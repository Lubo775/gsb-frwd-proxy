#!/bin/sh

#export outbound proxy variables (has to be first step in bootstrap !)
export http_proxy="socks5h://${op_username}:${op_password}@proxy.saas.vwapps.cloud:8000"
export https_proxy="socks5h://${op_username}:${op_password}@proxy.saas.vwapps.cloud:8000"
export no_proxy="169.254.169.254,.vwgroup.com,.vwg,.internal,.amazonaws.com"

#variables needed for bootstrap
export apmaas_vpc_endpoint="${apmaas_vpc_endpoint}"
export dynatrace_cluster_id="${dynatrace_cluster_id}"
export ENVIRONMENT="${environment}"
export GSBPROXY_BUCKET="${gsbproxy_bucket}"
export REGION="${region}"
export VAULT_ADDR="${vault_address}"
export VAULT_PATH="${vault_path}"
export VAULT_SKIP_VERIFY=true
export ORG_SCOPE="${org_scope}"
export FUNC_SCOPE="${func_scope}"
export STAGE="${stage}"
export AWS_IAM_ROLE="${aws_iam_role}"
export SHIPPER_NAME="$(hostname)_vpc_${org_scope}_${func_scope}_${environment}"
export NAME="${instance_name}"
export APP="${application_id}"
export HOST=$(hostname)
export MODULE_NAME_S3="${module_name}-nginx"
export MODULE_NAME="${module_name}"
export APPLICATION_VERSION="${app_version}"
export APPLICATION_ID="${application_id}"
export PROJECTID="${project_id}"
export TIER="${tiers_transfer}"
export OWNEREMAIL="${ops_team_mailbox}"
export NETWORK="${network}"
export PLT_NAME="${plattform_name}"
export SC_ASS_GROUP="${sc_ass_group}"
export SC_CI_NAME="${sc_ci_name}"
export CONCOURSE_NAME="${concourse_name}"
export CONCOURSE_TEAM="${concourse_team}"
export FILEBEAT=1
export METRICBEAT=1
export HEARTBEAT=1

export ENV_DNS=$(
  case $ENVIRONMENT in
    ("plint-001") echo "plint001" ;;
    ("plint-002") echo "plint002" ;;

    ("tui-dev-001") echo "dev001" ;;
    ("tui-demo") echo "dmo" ;;

    ("approval") echo "app" ;;
    ("prelive") echo "pre" ;;
    ("preprod") echo "pre" ;;

    ("live") echo "prd" ;;
    ("prod") echo "prd" ;;

    ("dev-001") echo "dev001" ;;
    (*) echo $ENVIRONMENT ;;
  esac
)

#########################################
##Configure OneAgent for specific stage##
#########################################

#retrieve PAAS Token to dynatrace cluster
export paas_token=$(aws secretsmanager get-secret-value --secret-id dp/shs/$ENVIRONMENT/gsbproxy-dynatrace/paas-token --query SecretString --output text | jq -r .Token)

#retrieve tenant tokent
export tenantToken=$(curl -kX GET "https://$apmaas_vpc_endpoint/e/$dynatrace_cluster_id/api/v1/deployment/installer/agent/connectioninfo" -H  "Authorization: Api-Token $paas_token" | jq -r .tenantToken)

#set proper values to oneagent and restart service
/opt/dynatrace/oneagent/agent/tools/oneagentctl --set-server=https://dynatrace.$ENV_DNS.shs.eu.$ORG_SCOPE.odp.cloud.vwgroup.com:9999/communication --set-tenant=$dynatrace_cluster_id --set-tenant-token=$tenantToken

#start on startup
systemctl enable oneagent

#restart service
systemctl start oneagent

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
##Configure Nginx for specific stage##
######################################

#copy nginx conf and add permissions to config
aws s3 cp s3://$GSBPROXY_BUCKET/nginx/nginx.conf /etc/nginx/nginx.conf --region $REGION
chmod 777 /etc/nginx/nginx.conf

#retrieve necessary gsbproxy certificates from Vault
vault read -field=cert $VAULT_PATH/nginx-cert/vw-ca-root-05 | base64 -d > /etc/nginx/ssl/VW-CA-ROOT-05.pem
if [ "$ENVIRONMENT" = "preprod" ]; then

	mkdir /etc/nginx/ssl/tui
	vault read -field=cert $VAULT_PATH/nginx-cert/tui | base64 -d > /etc/nginx/ssl/tui/cert.pem
	vault read -field=key $VAULT_PATH/nginx-cert/tui | base64 -d > /etc/nginx/ssl/tui/cert.key

	mkdir /etc/nginx/ssl/pre
	vault read -field=cert $VAULT_PATH/nginx-cert/pre | base64 -d > /etc/nginx/ssl/pre/cert.pem
	vault read -field=key $VAULT_PATH/nginx-cert/pre | base64 -d > /etc/nginx/ssl/pre/cert.key

	mkdir /etc/nginx/ssl/prd
	cp /etc/nginx/ssl/pre/cert.pem /etc/nginx/ssl/prd/cert.pem
	cp /etc/nginx/ssl/pre/cert.key /etc/nginx/ssl/prd/cert.key

	mkdir /etc/nginx/ssl/fod
	vault read -field=cert $VAULT_PATH/nginx-cert/fod | base64 -d > /etc/nginx/ssl/fod/cert.pem
	vault read -field=key $VAULT_PATH/nginx-cert/fod | base64 -d > /etc/nginx/ssl/fod/cert.key

else

	vault read -field=cert $VAULT_PATH/nginx-cert/client-cert | base64 -d > /etc/nginx/ssl/cert.pem
	vault read -field=key $VAULT_PATH/nginx-cert/client-cert | base64 -d > /etc/nginx/ssl/cert.key

fi

vault read -field=key $VAULT_PATH/nginx-cert/server-cert | base64 -d > /etc/nginx/ssl/server-cert.key
vault read -field=cert $VAULT_PATH/nginx-cert/server-cert | base64 -d > /etc/nginx/ssl/server-cert.pem

#start on startup
systemctl enable nginx

#restart service
systemctl start nginx

########################################################################################################################################################################################################################################

######################################
##Configure Beats for specific stage##
######################################

#download beats script
aws s3 cp s3://$GSBPROXY_BUCKET/beatsScript/configure-beats.sh /temp/configure-beats.sh

#run configuration script
bash /temp/configure-beats.sh

#activate NGINX-Logs for filebeat
#mv /etc/filebeat/modules.d/nginx.yml.disabled /etc/filebeat/modules.d/nginx.yml

#add nginx.yml for metricbeat
aws s3 cp s3://$GSBPROXY_BUCKET/beatsScript/metricbeat/modules.d/nginx.yml /etc/metricbeat/modules.d/nginx.yml 

#add gsbproxy-availability.yml for heartbeat
aws s3 cp s3://$GSBPROXY_BUCKET/beatsScript/heartbeat/monitors.d/gsbproxy-availability.yml /etc/heartbeat/monitors.d/gsbproxy-availability.yml

#enable filebeat on startup
systemctl enable filebeat

#start filebeat
systemctl start filebeat

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

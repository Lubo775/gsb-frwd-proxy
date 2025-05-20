#!/bin/sh

# retrieve credentials
credentials=$(aws --region $AWS_DEFAULT_REGION secretsmanager get-secret-value --secret-id /proxy/paas/service/credentials/$PROXY_ID --query 'SecretString' --output text)
 
# parse username and password without jq
username=$(echo $credentials | grep -o '\"username\": \"[a-zA-Z0-9+-]\{0,\}\"' | awk -F":" '{ print $2 }' | xargs)
password=$(echo $credentials | grep -o '\"password\": \"[a-zA-Z0-9+-]\{0,\}\"' | awk -F":" '{ print $2 }' | xargs)

vault write $skip_verify $concourse_name/$concourse_team/$org_scope-$func_scope-$module_name-$environment/OP_USERNAME value=$username
vault write $skip_verify $concourse_name/$concourse_team/$org_scope-$func_scope-$module_name-$environment/OP_PASSWORD value=$password
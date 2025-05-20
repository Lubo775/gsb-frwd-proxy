#!/bin/bash
######################################################################
#Definitions of defaults
######################################################################
CONCOURSE_NAME=${CONCOURSE_NAME:=platformcicd}
CONCOURSE_TEAM=${CONCOURSE_TEAM:=platform_deployment}
SC_ASS_GROUP=${SC_ASS_GROUP:=undefined}
SC_CI_NAME=${SC_CI_NAME:=undefined}
PLT_NAME=${PLT_NAME:=odp}
SUBMODULE_VERSION=${SUBMODULE_VERSION:=undefined}
######################################################################
S3_PATH="s3://bkt.${ORG_SCOPE}.${FUNC_SCOPE}.${MODULE_NAME_S3}.${ENVIRONMENT}/beatsScript"
MLS_VAULT_PATH="/$CONCOURSE_NAME/$CONCOURSE_TEAM"
######################################################################
REGION_DNS="eu"


ENV_DNS=$(
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
  esac)

case $ORG_SCOPE in
  ("dp")
    FUNC_DNS=$(
      case $FUNC_SCOPE in
        ("connectivity") echo "$FUNC_SCOPE.$ENV_DNS.apl" ;;
        ("sharedservices") echo "$ENV_DNS.shs" ;;
        ("corebe") echo "$ENV_DNS.apl" ;;
        (*) echo "$ENV_DNS.$FUNC_SCOPE" ;;
      esac) ;;
  ("pti")
    FUNC_DNS=$(
      case $FUNC_SCOPE in
        ("connectivity") echo "$FUNC_SCOPE.$ENV_DNS.apl" ;;
        ("sharedservices") echo "$ENV_DNS.shs" ;;
        ("corebe") echo "$ENV_DNS.apl" ;;
        (*) echo "$ENV_DNS.$FUNC_SCOPE" ;;
      esac) ;;
  (*)
    FUNC_DNS=$(
      case $FUNC_SCOPE in
        ("sharedservices") echo "shs.$ENV_DNS" ;;
        ("spr-corebe") echo "sprcbe.$ENV_DNS" ;;
        ("corebe") echo "apl.$ENV_DNS" ;;
        (*) echo "$FUNC_SCOPE.$ENV_DNS" ;;
      esac) ;;
esac

ORG_DNS=$(
  case $ORG_SCOPE in
    ("gs") echo "aws" ;;
    (*) echo "odp" ;;
  esac)

MLAAS_DNS="aws-in.mlaas.mls-ml.prd.eu.gs.aws.cloud.vwgroup.com"

MLAAS_PROTO="https"

######################################################################

exitOnError() {
    errorcode=$1
    if [ $errorcode -ne 0 ]; then
        echo "$2"
        exit $errorcode
    fi
}

addToKeyStore() {
    beat=$1
    key=$2
    value=$3

    echo "$value" | $beat keystore add $key --stdin --force
    exitOnError $? "Key store load failed for the key "$key
}


installVault() {
    # Install latest vault
    apt-get --assume-yes install unzip
    vault_releases="https://releases.hashicorp.com"
    vault_latest_release=$(curl -kl "https://releases.hashicorp.com/vault/" | grep "vault_*" | awk -F '<*+>' '{ print substr( $2, 1, length($2)-3) }' | awk '/^vault_[0-9]+\.[0-9]+\.[0-9]+$/' | head -n 1 | sed -r 's/[_]+/\//g' | awk '{ print "/"$1 }')
    latest_vault=$(curl -kL "$vault_releases$vault_latest_release" | egrep -o "vault_[0-9.]+_linux_amd64.zip" | head -n 1)

    (curl -kfLRO "$vault_releases$vault_latest_release/$latest_vault" && unzip "$latest_vault" -d /usr/sbin) &
    wait

    rm -f ca.pem
    VAULT_SERVER=$(echo $VAULT_ADDR | cut -d/ -f3)
    openssl s_client -showcerts -connect $VAULT_SERVER:443 -servername $VAULT_SERVER </dev/null 2>/dev/null|sed -n '/^-----BEGIN CERT/,/^-----END CERT/p' > ca.pem
    export VAULT_CAPATH="ca.pem"

}

readVaultKey() {
    key=$1

    val=$(vault kv get -field=value ${MLS_VAULT_PATH}/shared/${ENVIRONMENT}_${key})
    # App-specific value not set in Vault. Get the default value.
    if [ $? -ne 0 ]; then
        val=$(vault kv get -field=value ${MLS_VAULT_PATH}/${ORG_SCOPE}-${FUNC_SCOPE}-${MODULE_NAME}-${ENVIRONMENT}/${key})
        if [ $? -ne 0 ]; then
            val=$(vault kv get -field=value ${MLS_VAULT_PATH}/shared/${STAGE}_${key})
            if [ $? -ne 0 ]; then
                val=$(vault kv get -field=value ${MLS_VAULT_PATH}/shared_${key})
                exitOnError $? "Unable to read the following key from Vault: "$key
            fi
        fi
    fi
    echo $val
}

installBeat() {
    
    aws s3 cp $2 /etc/$1/$1.yml
    exitOnError $? $1" YAML file download failed with error "$?
    if ! [ -z "$3" ]; then
      if [ "$1" == "filebeat" ]; then
          aws s3 cp "$3" "/etc/$1/modules.d/"
      else
          aws s3 cp "$3" "/etc/$1/monitors.d/"
      fi
	fi


    $1 keystore create --force
    exitOnError $? "Unable to create keystore for "$1

    addToKeyStore $1 "SHIPPER_NAME" "$SHIPPER_NAME"
    addToKeyStore $1 "NAME" "$NAME"
    addToKeyStore $1 "APP" "$APP"
    addToKeyStore $1 "STAGE" "$STAGE"
    addToKeyStore $1 "HOST" "$HOST"
    addToKeyStore $1 "REGION" "$REGION"
    addToKeyStore $1 "ORG_SCOPE" "$ORG_SCOPE"
    addToKeyStore $1 "MODULE_NAME" "$MODULE_NAME"
    addToKeyStore $1 "ENVIRONMENT" "$ENVIRONMENT"
    addToKeyStore $1 "APPLICATION_VERSION" "$APPLICATION_VERSION"
    addToKeyStore $1 "APPLICATION_ID" "$APPLICATION_ID"
    addToKeyStore $1 "PROJECTID" "$PROJECTID"
    addToKeyStore $1 "FUNC_SCOPE" "$FUNC_SCOPE"
    addToKeyStore $1 "TIER" "$TIER"
    addToKeyStore $1 "OWNEREMAIL" "$OWNEREMAIL"
    addToKeyStore $1 "NETWORK" "$NETWORK"
    addToKeyStore $1 "KIBANA_HOST" "$KIBANA_HOST"
    addToKeyStore $1 "KIBANA_USER" "$KIBANA_USER"
    addToKeyStore $1 "KIBANA_PWD" "$KIBANA_PWD"
    addToKeyStore $1 "ELASTICSEARCH_HOST" "$ELASTICSEARCH_HOST"
    addToKeyStore $1 "ELASTICSEARCH_USER" "$ELASTICSEARCH_USER"
    addToKeyStore $1 "ELASTICSEARCH_PWD" "$ELASTICSEARCH_PWD"
    addToKeyStore $1 "PLT_NAME" "$PLT_NAME"
    addToKeyStore $1 "SC_ASS_GROUP" "$SC_ASS_GROUP"
    addToKeyStore $1 "SC_CI_NAME" "$SC_CI_NAME"
    addToKeyStore $1 "FUNCTIONAL_SCOPE" "$FUNC_SCOPE"
    addToKeyStore $1 "SUBMODULE_VERSION" "$SUBMODULE_VERSION"

}

# Begin running...
# Validation of environment variables

if [[ -z "$SHIPPER_NAME" || -z "$APP" || -z "$STAGE" || -z "$ENVIRONMENT" || -z "$HOST" ]]
then
    echo "SHIPPER_NAME, APP, STAGE, ENVIRONMENT, AND HOST environment variables are not set."
    exit 1
fi

if [[ -z "$PACKETBEAT" && -z "$METRICBEAT" && -z "$FILEBEAT" && -z "$AUDITBEAT" && -z "$HEARTBEAT" ]]
then
    echo "At least one beat must be enabled."
    exit 1
fi


# Install and configure Vault CLI and then retrieve Vault values for later use.
#if ! [ -x "$(command -v vault)" ]; then
#    installVault
#fi

MLAAS_PORT=$(readVaultKey "mlaas_port")
if ! [ $? -eq 0 ]; then
    echo "MLAAS_PORT ERROR: $MLAAS_PORT"
    # next steps will still fail, but error messages will not be nested any more
    MLAAS_PORT=0
fi

KIBANA_API_CLUSTER_ID=$(readVaultKey "mlaas_kibana_api_cluster_id")
if ! [ $? -eq 0 ]; then
    echo "KIBANA_API_CLUSTER_ID ERROR: $KIBANA_API_CLUSTER_ID"
    KIBANA_API_CLUSTER_ID=__INSTALL-BEATS-SH_ERROR__
fi
KIBANA_HOST="$MLAAS_PROTO://$KIBANA_API_CLUSTER_ID.$MLAAS_DNS:$MLAAS_PORT"
KIBANA_USER=$(readVaultKey "mlaas_user_id")
if ! [ $? -eq 0 ]; then
    echo "KIBANA_USER ERROR: $KIBANA_USER"
    KIBANA_USER=__INSTALL-BEATS-SH_ERROR__1
fi
KIBANA_PWD=$(readVaultKey "mlaas_password")
if ! [ $? -eq 0 ]; then
    echo "KIBANA_PWD ERROR: $KIBANA_PWD"
    KIBANA_PWD=__INSTALL-BEATS-SH_ERROR__
fi

ELASTICSEARCH_API_CLUSTER_ID=$(readVaultKey "mlaas_elasticsearch_api_cluster_id")
if ! [ $? -eq 0 ]; then
    echo "ELASTICSEARCH_API_CLUSTER_ID EROR: $ELASTICSEARCH_API_CLUSTER_ID"
    ELASTICSEARCH_API_CLUSTER_ID=__INSTALL-BEATS-SH_ERROR__
fi
ELASTICSEARCH_HOST="$MLAAS_PROTO://$ELASTICSEARCH_API_CLUSTER_ID.$MLAAS_DNS:$MLAAS_PORT"
ELASTICSEARCH_USER=$(readVaultKey "mlaas_user_id")
if ! [ $? -eq 0 ]; then
    echo "ELASTICSEARCH_USER ERROR: $ELASTICSEARCH_USER"
    ELASTICSEARCH_USER=__INSTALL-BEATS-SH_ERROR__
fi
ELASTICSEARCH_PWD=$(readVaultKey "mlaas_password")
if ! [ $? -eq 0 ]; then
    echo "ELASTICSEARCH_PWD ERROR: $ELASTICSEARCH_PWD"
    ELASTICSEARCH_PWD=__INSTALL-BEATS-SH_ERROR__
fi

# Install and configure the beats requested through environment variables.

if [ ! -z "$AUDITBEAT" ]
then
    installBeat "auditbeat" "${AUDITBEAT_YAML:-$S3_PATH/auditbeat/auditbeat.yml}"
    mkdir -p /etc/systemd/system/auditbeat.service.d/
    echo '[Service]
Environment="BEAT_LOG_OPTS="' > /etc/systemd/system/auditbeat.service.d/debug.conf
fi


if [ ! -z "$METRICBEAT" ]
then
    installBeat "metricbeat" "${METRICBEAT_YAML:-$S3_PATH/metricbeat/metricbeat.yml}" "${METRICBEAT_MONITORSD_YAML:-$S3_PATH/metricbeat/modules.d/nginx.yml}"
    mkdir -p /etc/systemd/system/metricbeat.service.d/
    echo '[Service]
Environment="BEAT_LOG_OPTS="' > /etc/systemd/system/metricbeat.service.d/debug.conf
fi


if [ ! -z "$FILEBEAT" ]
then
    installBeat "filebeat" "${FILEBEAT_YAML:-$S3_PATH/filebeat/filebeat.yml}" "${FILEBEAT_MODULESD_YAML:-$S3_PATH/filebeat/modules.d/nginx.yml}"
    mkdir -p /etc/systemd/system/filebeat.service.d/
    echo '[Service]
Environment="BEAT_LOG_OPTS="' > /etc/systemd/system/filebeat.service.d/debug.conf
fi


if [ ! -z "$HEARTBEAT" ]
then
    installBeat "heartbeat" "${HEARTBEAT_YAML:-$S3_PATH/heartbeat/heartbeat.yml}" "${HEARTBEAT_MONITORSD_YAML:-$S3_PATH/heartbeat/monitors.d/gsbproxy-availability.yml}"
    mkdir -p /etc/systemd/system/heartbeat-elastic.service.d/
    echo '[Service]
Environment="BEAT_LOG_OPTS="' > /etc/systemd/system/heartbeat-elastic.service.d/debug.conf
fi


if [ ! -z "$PACKETBEAT" ]
then
    installBeat "packetbeat" "${PACKETBEAT_YAML:-$S3_PATH/packetbeat/packetbeat.yml}"
    mkdir -p /etc/systemd/system/packetbeat.service.d/
    echo '[Service]
Environment="BEAT_LOG_OPTS="' > /etc/systemd/system/packetbeat.service.d/debug.conf
fi

#!/bin/sh
cd /certRenewal

#create folders for actual(old) and renewed(new) certs
mkdir gsbproxy-certificates
mkdir ./gsbproxy-certificates/new
mkdir ./gsbproxy-certificates/old

#log into vault
vault login $vault_token

#download actual(old) certs from Vault
vault read -field=key $VAULT_PATH_KEY | base64 -d > ./gsbproxy-certificates/old/client_or_server_cert.key
vault read -field=cert $VAULT_PATH_PEM | base64 -d > ./gsbproxy-certificates/old/client_or_server_cert.pem

#renew certs based on actual(old) certs
chmod u+x ./tcrp-tool/vwcc
./tcrp-tool/vwcc -Configuration ./$1.yaml

#backup and upload certs only in situation where tcrp tool renewed certs successfully
if [ -e "vwcc.log" ]; then
    if ! (cat vwcc.log | grep "error") && ! (cat vwcc.log | grep "renewal not required"); then
        echo "Backup of old and upload of new cert is in process"

        #backup actual(old) certs into Vault
        content1="$(cat ./gsbproxy-certificates/old/client_or_server_cert.pem |base64)"
        content2="$(cat ./gsbproxy-certificates/old/client_or_server_cert.key |base64)"
        vault write $VAULT_PATH_PEM/backup cert="$content1" key="$content2"

        #do only if vault write was successful
        if [ $? -eq 0 ]; then
            #upload renewed(new) certs into Vault
            content1="$(cat ./gsbproxy-certificates/new/client_or_server_cert.pem |base64)"
            content2="$(cat ./gsbproxy-certificates/new/client_or_server_cert.key |base64)"
            vault write $VAULT_PATH_PEM cert="$content1" key="$content2"

            #upload public certificate into cert notifier bucket
            echo "Uploading public key into CertNotifier bucket"
            aws s3 cp ./gsbproxy-certificates/new/client_or_server_cert.pem s3://bkt.${org_scope}.${func_scope}.${module_name}-certnotifier.${stage}/gsbproxy/${server_or_client_cert_name}.pem
        else
            echo "Vault command to upload backup of certificate did not work. Aborted."
        fi
    else 
        echo "Process to renew certificate was aborted due to error/reason written above this line."
    fi
else
    echo "For some reason vwcc.log was not generated by tcrp tool. Aborted."
fi
#!/bin/sh

VAULT_CA_SSM_PATH=/proxy/vault-ca/root-ca

aws ssm get-parameter --name $VAULT_CA_SSM_PATH \
| jq -r .Parameter.Value \
> vault-ca.crt

grep -- '-----BEGIN CERTIFICATE-----' vault-ca.crt || {
  mv vault-ca.crt vault-ca.b64
  base64 -d vault-ca.b64 > vault-ca.crt
}

cp vault-ca.crt /usr/local/share/ca-certificates/
update-ca-certificates

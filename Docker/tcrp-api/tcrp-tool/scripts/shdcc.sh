#!/bin/sh
# ------------------------------------
# Purpose:
# - Certificate Client (DispenseCertificate, TCRP via Intranet or Internet)
# 
# Description:
# - Acts as Certificate Client (CC) within Technical Certificate Renewal Portal (TCRP).
# 
# Author:
# - Klaus Tockloth (DJVN80Z, extern.klaus.tockloth@volkswagen.de)
# 
# Copyright:
# - © 2022-2023 | Volkswagen AG
# 
# Contact:
# K-DSO/2 | Authentication & Encryption Services
# Group Information Security
# Volkswagen Aktiengesellschaft
# 38436 Wolfsburg
# Mail: pki@volkswagen.de
# 
# Remarks:
# - Return codes:
#   0  : success
#   11 : failure
# - TCRP can be used via:
#   + Intranet (typical usage)
#   + Internet (special usage)
# - This script acts as API description and code blueprint if you want to use the TCRP API.
#
# Intranet usage:
# - certificate offered by TCRP service (Registration Authority) is issued by VW Office PKI
# - as of 2023/01 this is:
#   + issuer = "VW-CA-PROC-08"
#   + root   = "VW-CA-ROOT-05"
# - search in this script for string 'Intranet'
#
# Internet usage:
# - internet usage requires mTLS connection with dedicated client certificate
# - client certificate must be additional authorized in TCRP infrastructure
# - (optional) Internet proxy can be set via curl option --proxy
# - --proxy 'http://USERNAME:PASSWORD@proxy-server.mycorp.com:3128'
# - it is also possible to define the proxy setting via environment variable "HTTPS_PROXY"
# - HTTPS_PROXY=http://USERNAME:PASSWORD@proxy-server.mycorp.com:3128
# - certificate offered by TCRP infrastructure (LTM/F5) is issued by public certificate provider
# - as of 2023/01 this is:
#   + issuer = "QuoVadis Global SSL ICA G3"
#   + root   = "QuoVadis Root CA2 G3"
# - search in this script for string 'Internet'
#
# TCRP URLs:
# - QA Intranet   : https://tcrp-qs.qs2x.vwg:443/api/1/dispense/certificate
# - QA Internet   : https://tcrp-qs.vwgroup.com:443/api/1/dispense/certificate
# - PROD Intranet : see TCRP wiki page
# - PROD Internet : see TCRP wiki page
#
# TCRP integration:
# - Always test against quality assurance (qa/qs), never against production (prod)!
# - You can dispense as much certificates as needed for your TCRP integration work flow.
# - After you are done, it's typical only required to switch the URL from QA to PROD.
#
# Master certificate security policy (for production):
# - The private key of the master certificate must be stored in a highly secure environment.
# - The private key of the master certificate cannot be exported from this environment.
#
# This script is intended: 
# - Only for testing.
# - As API reference.
#
# Links:
# - https://group-wiki.wob.vw.vwg/wikis/pages/viewpage.action?pageId=1504581982
#
# Note:
# The generated private key for the certificate is to be regarded as secret according to the security
# classification. Protect it from unauthorized access in accordance with the security regulations!
# ------------------------------------

# set -o xtrace
# set -o verbose

script=$(basename "$0")
printf "%s - v1.6.0 - 2023-02-03 (dispense certificate via intranet/internet)\n" "$script"

# file references to master certificate and private key (main domain)
masterCertificateFile="./mastercerts/master-tcrp-example.crt"
masterPrivatekeyFile="./mastercerts/master-tcrp-example.key"

# file names for new certificate and new private key (sub domain(s))
newCertificateFile="./dispensedcerts/languages.tcrp-example.crt"
newPrivatekeyFile="./dispensedcerts/languages.tcrp-example.key"

# force removing of possibly existing files
rm -f "$newCertificateFile"
rm -f "$newPrivatekeyFile"

if [ ! -r "$masterCertificateFile" ]; then
  printf "ERROR: Could not read master certificate file: %s\n" "$masterCertificateFile"
  exit 11
fi
if [ ! -r "$masterPrivatekeyFile" ]; then
  printf "ERROR: Could not read master private key file: %s\n" "$masterPrivatekeyFile"
  exit 11
fi
directoryDispensed=$(dirname $newPrivatekeyFile)
if [ ! -w "$directoryDispensed" ]; then
  printf "ERROR: Could not write to dispensation directory: %s\n" "$directoryDispensed"
  exit 11
fi

# The system cert pool often contains only the operating system default issuer/root certificates,
# and no trusted enterprise issuer/root certificates. If this is the case, we must explicit trust
# (with curl option --cacert) the issuer/root of the TCRP server certificate.
# Intranet: "./servercerts/vw-ca-root-05.crt"
# Internet: "./servercerts/QuoVadis-Root-CA2-G3.crt"
trustedTCRPCACertificates="./servercerts/vw-ca-root-05.crt"
if [ ! -r "$trustedTCRPCACertificates" ]; then
  printf "ERROR: Could not read trusted TCRP CA certificate file: %s\n" "$trustedTCRPCACertificates"
  exit 11
fi

# client certificate and private key for mutual TLS connection (mTLS) with TCRP service
# A client certificate is only required if you want to use TCRP via mTLS Internet connection.
# In this case, we must explicit specify the client certificate and private key with the curl
# options --cert and --key.
# A client certificate is not required if you want to use TCRP via Intranet connection. In
# this case, we comment out this block.
# Intranet: deactivate this block
# Internet: activate this block
# clientCertificateFile="./clientcerts/Systemuser-TCRPCLIENT-VWPKI-2B5BA0458C9D9118.crt"
# clientPrivatekeyFile="./clientcerts/Systemuser-TCRPCLIENT-VWPKI-2B5BA0458C9D9118.key"
# if [ ! -r "$clientCertificateFile" ]; then
#   printf "ERROR: Could not read client certificate file: %s\n" "$clientCertificateFile"
#   exit 11
# fi
# if [ ! -r "$clientPrivatekeyFile" ]; then
#   printf "ERROR: Could not read client private key file: %s\n" "$clientPrivatekeyFile"
#   exit 11
# fi

printf "1. Generating unique identifier (e.g. UUID) ...\n"
ID=$(uuidgen)

# temporary files
csrConfigurationFile="${ID}_csr_configuration.tmp"
csrContentFile="${ID}_csr_content.tmp"
signingContentFile="${ID}_signing_content.tmp"
responseHeaderFile="${ID}_responseHeader.dump.tmp"
responseDataFile="${ID}_responseData.dump.tmp"

printf "2. Generating certificate signing request (CSR) configuration ...\n"
# Subjects of new certificate and master certificate must be identical (except CommenName and serialNumber).
# DNS names in SAN of CSR must be sub domain names of DNS names in master certificate.
cat > "$csrConfigurationFile" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
O = VW AG
CN = languages.tcrp-example.vw.vwg

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = en.tcrp-example.vw.vwg
DNS.2 = de.tcrp-example.vw.vwg
EOF

printf "3. Generating private key for new certificate ...\n"
oldumask=$(umask)
umask 0377
# RSA (eg. 2048, 4096)
openssl genrsa -out "$newPrivatekeyFile" 4096 2>/dev/null
# ECDSA (eg. prime256v1, secp384r1)
# openssl ecparam -name secp384r1 -genkey -noout -out "$newPrivatekeyFile"
if [ ! $? ] || [ ! -s "$newPrivatekeyFile" ]; then
  printf "ERROR: Could not create new private key file: %s\n" "$newPrivatekeyFile"
  rm -f "${ID}_"*
  exit 11
fi
umask "$oldumask"

printf "4. Generating certificate signing request (CSR) for new certificate ...\n"
openssl req -new -key "$newPrivatekeyFile" -out "$csrContentFile" -config "$csrConfigurationFile"
if [ ! $? ] || [ ! -s "$csrContentFile" ]; then
  printf "ERROR: Could not create CSR file: %s\n" "$csrContentFile"
  rm -f "${ID}_"*
  exit 11
fi

printf "5. Generating TCRP dispense certificate request (JSON) ...\n"
# replace CRLF with '\r\n' and LF with '\n' (using sed)
Certificate=$(sed -z 's/\r\n/\\r\\n/g' "$masterCertificateFile" | sed -z 's/\n/\\n/g')
CSR=$(sed -z 's/\r\n/\\r\\n/g' "$csrContentFile" | sed -z 's/\n/\\n/g')

# sign 'certificate+csr' with private key
cp "$masterCertificateFile" "$signingContentFile"
cat "$csrContentFile" >> "$signingContentFile"
Signature=$(openssl dgst -sha256 -sign "$masterPrivatekeyFile" "$signingContentFile" | openssl base64 -A)

Hostname=$(hostname -f)

# Metadata: Used by certificate authority (CA) to identify certificate consumer (application).
# EmailRemindingAddress: The CA uses this email group address for reminding or notification.
# Requestor: Requestor of new certificate.
# CostCenter: Corresponding cost center.
# AppID: PlanningIT Application ID.
# CI: Configuration Item.
# CustomCI: Custom specific Configuration Item (use this only if CI doesn't exist).
# Hostname: Describes the hostname of the requesting system (often not certificate consumer).
# ServiceCenterGroup: Service center group responsible for certificate consumer (application).
# DaysCertificateValid: Number of days new certificate should be valid.
dispenseRequest=$(printf '
{
  "Type": "DispenseCertificateRequest",
  "ID": "%s",
  "Attributes": {
    "Certificate": "%s",
    "CSR": "%s",
    "Signature": "%s",
    "Metadata": {
      "EmailRemindingAddress": "admin.group42@volkswagen.de",
      "Requestor": {
        "UserName": "ffyjomg",
        "LastName": "Jomann",
        "GivenName": "Marco",
        "Email": "marco.jomann@volkswagen.de"
      },
      "CostCenter": {
        "Name": "L-GIT-P/3",
        "Number": "4242",
        "Company": "Volkswagen AG",
        "Manager": {
          "UserName": "ddwbere",
          "LastName": "Berner",
          "GivenName": "Hanco",
          "Email": "hanco.berner@volkswagen.de"
        }
      },
      "AppID": "APP-99999",
      "CI": "CI00123456",
      "CustomCI": "",
      "Hostname": "%s",
      "ServiceCenterGroup": "OPS TCRP VW Group",
      "DaysCertificateValid": "365"
    }
  }
}' "$ID" "$Certificate" "$CSR" "$Signature" "$Hostname")

# for debugging only (for security reasons, we don't log the signature)
# escapedSignature=$(printf '%s\n' "$Signature" | sed 's:[][\\/.^$*]:\\&:g')
# loggingDispenseRequest=$(printf '%s\n' "$dispenseRequest" | sed -e "s/$escapedSignature/-----SIGNATURE NOT LOGGED-----/g")
# printf "loggingDispenseRequest = %s\n" "$loggingDispenseRequest"

printf "6. Sending dispense certificate request to registration authority (RA) ...\n"
# URL of TCRP service (registration authority) 
# Intranet: "https://tcrp-qs.qs2x.vwg:443/api/1/dispense/certificate"
# Internet: "https://tcrp-qs.vwgroup.com:443/api/1/dispense/certificate"
dispenseCertificateService="https://tcrp-qs.qs2x.vwg:443/api/1/dispense/certificate"

# Internet: typical curl options to send dispense request to TCRP: 
# curl \
# --silent \
# --dump-header "$responseHeaderFile" \
# --output "$responseDataFile" \
# --cacert "$trustedTCRPCACertificates" \
# --proxy "http://user:password@10.252.76.110:8080" \
# --url "$dispenseCertificateService" \
# --request "POST" \
# --cert "$clientCertificateFile" \
# --key "$clientPrivatekeyFile" \
# --show-error \
# --include \
# --header "Content-Type: application/json; charset=utf-8" \
# --header "Accept: application/json; charset=utf-8" \
# --data-binary "$dispenseRequest"

# Intranet: typical curl options to send dispense request to TCRP: 
# curl \
# --silent \
# --dump-header "$responseHeaderFile" \
# --output "$responseDataFile" \
# --cacert "$trustedTCRPCACertificates" \
# --url "$dispenseCertificateService" \
# --request "POST" \
# --show-error \
# --include \
# --header "Content-Type: application/json; charset=utf-8" \
# --header "Accept: application/json; charset=utf-8" \
# --data-binary "$dispenseRequest"

curl \
--silent \
--dump-header "$responseHeaderFile" \
--output "$responseDataFile" \
--cacert "$trustedTCRPCACertificates" \
--url "$dispenseCertificateService" \
--request "POST" \
--show-error \
--include \
--header "Content-Type: application/json; charset=utf-8" \
--header "Accept: application/json; charset=utf-8" \
--data-binary "$dispenseRequest"

curlReturnCode=$?
responseHeader=$(cat "$responseHeaderFile")
responseData=$(cat "$responseDataFile")

# for debugging only
# printf "curl return code: %s\n" "$curlReturnCode"
# printf "curl response header: %s\n" "$responseHeader"
# printf "curl response data: %s\n" "$responseData"

printf "7. Evaluating curl return code and HTTP status code ...\n"
httpStatusLine=$(echo "$responseHeader" | grep "HTTP" | tail -1)
httpStatusCode=$(echo "$httpStatusLine" | grep -o "[0-9][0-9][0-9]")

# for debugging only
# printf "httpStatusLine (last): %s\n" "$httpStatusLine"
# printf "httpStatusCode (last): %s\n" "$httpStatusCode"

if [ $curlReturnCode -eq 0 ]; then
  # evaluate HTTP status code from response
  if [ "$httpStatusCode" = "200" ]; then
    # extract and save certificate from response
    printf "8. Writing PEM certificate file ...\n"    
    # everything between first '-----BEGIN CERTIFICATE-----' and last '-----END CERTIFICATE-----'
    certChainRaw=$(grep -Po '(?<=-----BEGIN CERTIFICATE-----).*(?=-----END CERTIFICATE-----)' "$responseDataFile")
    certChain=$(echo "$certChainRaw" | sed -z 's/\\r\\n/\r\n/g' | sed -z 's/\\n/\n/g')
    printf '%s%s\n%s\n' "-----BEGIN CERTIFICATE-----" "$certChain" "-----END CERTIFICATE-----" > "$newCertificateFile"
    printf "Done - certificate dispensed.\n"
    printf "\nNote:\n"
	printf "The generated private key is to be regarded as secret according to the security classification.\n"
    printf "Protect it from unauthorized access in accordance with the security regulations!\n"
    rm -f "${ID}_"*
    exit 0
  else
    # print error response
    printf "ERROR: Unexpected HTTP status: %s\n" "$httpStatusLine"
    rm -f "${ID}_"*
    exit 11
  fi
else
  printf "ERROR: Error calling registration authority (RA): %s\n" "$curlReturnCode"
  rm -f "${ID}_"*
  exit 11
fi

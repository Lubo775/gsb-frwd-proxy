#!/bin/sh
# ------------------------------------
# Purpose:
# - Certificate Client (IssueCertificate, TCRP via Intranet)
# 
# Description:
# - Acts as Certificate Client (CC) within Technical Certificate Renewal Portal (TCRP).
# 
# Author:
# - Klaus Tockloth (DJVN80Z, extern.klaus.tockloth@volkswagen.de)
# 
# Copyright:
# - © 2023 | Volkswagen AG
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
# - This script acts as API description and code blueprint if you want to use the TCRP API.
# - This script demonstrates the usage of SSH Agent Forwarding:
#   + script runs on Linux Server
#   + script uses your personal PKI card connected to Windows PC
#   + SSH connection established 'Windows PC -> Linux Server'
#   + crypto operations forwarded 'Linux Server -> Windows PC'
# - There is currently no Linux script that demonstrates the direct use of the PKI card:
#   + Contact 'K-DSO/2 | Authentication & Encryption Services' for more informations.
#
# Intranet usage:
# - certificate offered by TCRP service (Registration Authority) is issued by VW Office PKI
# - as of 2023/01 this is:
#   + issuer = "VW-CA-PROC-08"
#   + root   = "VW-CA-ROOT-05"
#
# TCRP URLs:
# - QA Intranet   : https://tcrp-qs.qs2x.vwg:443/api/1/issue/certificate
# - PROD Intranet : see TCRP wiki page
#
# TCRP integration:
# - Always test against quality assurance (qa/qs), never against production (prod)!
# - You can issue as much certificates as needed for your TCRP integration work flow.
# - After you are done, it's typical only required to switch the URL from QA to PROD.
#
# SSH Agent Forwarding via PuTTY: 
# - special setting required: Connection -> SSH -> Auth: Allow agent forwarding
#
# Links:
# - https://group-wiki.wob.vw.vwg/wikis/pages/viewpage.action?pageId=1504581982
#
# Required external tools:
# - OpenSSL
# - cURL
# - tcrp-hsm
#
# Create CSR (Certificate Signing Request) with:
# - vwcsr (tool supported by VW PKI)
# - OpenSSL
# - ...
#
# Note:
# The generated private key for the certificate is to be regarded as secret according to the security
# classification. Protect it from unauthorized access in accordance with the security regulations!
# ------------------------------------

# set -o xtrace
# set -o verbose

script=$(basename "$0")
printf "%s - v1.6.0 - 2023-02-03 (issue certificate via intranet)\n" "$script"

# file names for new certificate and new private key (sub domain(s))
newCertificateFile="./issuedcerts/tcrp-example.vw.vwg.crt"
newPrivatekeyFile="./issuedcerts/tcrp-example.vw.vwg.key"

# force removing of possibly existing files
rm -f "$newCertificateFile"
rm -f "$newPrivatekeyFile"

directoryIssued=$(dirname $newPrivatekeyFile)
if [ ! -w "$directoryIssued" ]; then
  printf "ERROR: Could not write to issue directory: %s\n" "$directoryIssued"
  exit 11
fi

# The system cert pool often contains only the operating system default issuer/root certificates,
# and no trusted enterprise issuer/root certificates. If this is the case, we must explicit trust
# (with curl option --cacert) the issuer/root of the TCRP server certificate.
# Intranet: "./servercerts/vw-ca-root-05.crt"
trustedTCRPCACertificates="./servercerts/vw-ca-root-05.crt"
if [ ! -r "$trustedTCRPCACertificates" ]; then
  printf "ERROR: Could not read trusted TCRP CA certificate file: %s\n" "$trustedTCRPCACertificates"
  exit 11
fi

printf "1. Generating unique identifier (e.g. UUID) ...\n"
ID=$(uuidgen)

# temporary files
csrConfigurationFile="${ID}_csr_configuration.tmp"
csrContentFile="${ID}_csr_content.tmp"
signingCertificateDERFile="${ID}_signing_certificate_der.tmp"
signingCertificatePEMFile="${ID}_signing_certificate_pem.tmp"
signingContentFile="${ID}_signing_content.tmp"
signingContentFileSignature="${ID}_signing_content_signature.tmp"
responseHeaderFile="${ID}_responseHeader.dump.tmp"
responseDataFile="${ID}_responseData.dump.tmp"

printf "2. Generating certificate signing request (CSR) configuration ...\n"
cat > "$csrConfigurationFile" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
O = VW AG
OU = 4242
CN = tcrp-example.vw.vwg

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = tcrp-example.vw.vwg
DNS.2 = www.tcrp-example.vw.vwg
EOF

printf "3. Generating private key for new certificate ...\n"
oldumask=$(umask)
umask 0377
# RSA (eg. 2048, 4096)
# openssl genrsa -out "$newPrivatekeyFile" 4096 2>/dev/null
# ECDSA (eg. prime256v1, secp384r1)
openssl ecparam -name secp384r1 -genkey -noout -out "$newPrivatekeyFile"
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

printf "5. Generating TCRP issue certificate request (JSON) ...\n"

# settings for PKI card (via SSH Agent Forwarding)
SlotPKICard="0"
LabelSignatureCertificatePKICard="Digital Signature"
signingCertificateDERFile="VW-CA-AUTS-02-Tockloth-Klaus-VWPKI-BEBCCE033DB2F9E1.crt"

printf "5a. Converting signing certificate from DER to PEM format ...\n"
# convert signing certificate from DER to PEM
openssl x509 -inform der -in "$signingCertificateDERFile" -out "$signingCertificatePEMFile"
if [ ! $? ] || [ ! -s "$signingCertificatePEMFile" ]; then
  printf "ERROR: Could not convert signing certificate from DER to PEM: %s\n" "$signingCertificatePEMFile"
  rm -f "${ID}_"*
  exit 11
fi

# replace CRLF with '\r\n' and LF with '\n' (using sed)
Certificate=$(sed -z 's/\r\n/\\r\\n/g' "$signingCertificatePEMFile" | sed -z 's/\n/\\n/g')
CSR=$(sed -z 's/\r\n/\\r\\n/g' "$csrContentFile" | sed -z 's/\n/\\n/g')

printf "5b. Signing TCRP request data with private key of signing certificate via PKI card  ...\n"
# sign 'certificate+csr' with private key of signing certificate on PKI card 
cp "$signingCertificatePEMFile" "$signingContentFile"
cat "$csrContentFile" >> "$signingContentFile"
echo
./tcrp-hsm -d -i "$signingContentFile" -o "$signingContentFileSignature" -c "$signingCertificateDERFile" SSHSignFile SHA256
if [ ! $? ] || [ ! -s "$signingContentFileSignature" ]; then
  printf "ERROR: Could not calculate signature on PKI card: %s\n" "$signingContentFileSignature"
  rm -f "${ID}_"*
  exit 11
fi
echo
Signature=$(cat "$signingContentFileSignature" | openssl base64 -A)

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
# CertificateType: Type of requested certificate (SSL, OFTP2, PROCASUSER, 802.1XC, 802.1XS).
# AdditionalData: Additional request data (typically empty).
issueRequest=$(printf '{
  "Type": "IssueCertificateRequest",
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
    },
    "CertificateType": "SSL",
    "AdditionalData": ""
  }
}' "$ID" "$Certificate" "$CSR" "$Signature" "$Hostname")

# for debugging only (for security reasons, we don't log the signature)
# escapedSignature=$(printf '%s\n' "$Signature" | sed 's:[][\\/.^$*]:\\&:g')
# loggingIssueRequest=$(printf '%s\n' "$issueRequest" | sed -e "s/$escapedSignature/-----SIGNATURE NOT LOGGED-----/g")
# printf "loggingIssueRequest = %s\n" "$loggingIssueRequest"

printf "6. Sending issue certificate request to registration authority (RA) ...\n"
# URL of TCRP service (registration authority) 
# issueCertificateService="https://tcrp-qs.qs2x.vwg:443/api/1/issue/certificate"
issueCertificateService="https://tcrp-qs.qs2x.vwg:443/api/1/issue/certificate"

curl \
--silent \
--dump-header "$responseHeaderFile" \
--output "$responseDataFile" \
--cacert "$trustedTCRPCACertificates" \
--url "$issueCertificateService" \
--request "POST" \
--cert "$clientCertificateFile" \
--key "$clientPrivatekeyFile" \
--show-error \
--include \
--header "Content-Type: application/json; charset=utf-8" \
--header "Accept: application/json; charset=utf-8" \
--data-binary "$issueRequest"

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
    printf "Done - certificate issued.\n"
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

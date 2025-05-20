#!/bin/sh

# ------------------------------------
# Function:
# - List certificate and key objects in store.
#
# Version:
# - v1.0.0 - 2022-05-03 : initial release
#
# Remarks:
# - Export HSM pin with "export NAME=VALUE"
#   export GERP='dhfjk126'
# ------------------------------------

# set -o xtrace
set -o verbose

# set output file
HSMData="hsm-list.data"

# remove old output file
rm "$HSMData"

# fetch HSM data (slots: 19=TCRP, 20=GERP)
./tcrp-hsm -d -o "$HSMData" -l './libcs_pkcs11_R3.so' -s 20 -P 'env:GERP' 'List'

# list HSM data
cat "$HSMData"


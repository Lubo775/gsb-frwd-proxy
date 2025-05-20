#!/bin/sh

# ------------------------------------
# Purpose:
# - create template
# 
# Releases:
# - v1.0.0 - 2022-06-03: initial release
# 
# Author:
# - Klaus Tockloth
# ------------------------------------

# remove 'old' log files
rm vwcsr.log
rm vwcsr.log.pretty

# remove 'old' data files
rm robinson-example.vw.vwg.template
rm -f robinson-example.vw.vwg.key
rm robinson-example.vw.vwg.csr
rm robinson-example.vw.vwg.p7b

# create template
./vwcsr \
-Configuration vwcsr.yaml \
-Basename robinson-example.vw.vwg \
-TrustStore HSM \
-CertificateType TLS \
CreateTemplate

# pretty print log file
./log-pretty vwcsr.log >vwcsr.log.pretty

# list template file
cat robinson-example.vw.vwg.template

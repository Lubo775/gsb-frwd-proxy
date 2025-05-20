#!/bin/sh

# ------------------------------------
# Purpose:
# - create CSR
# 
# Releases:
# - v1.0.0 - 2022-05-13: initial release
# 
# Author:
# - Klaus Tockloth
# ------------------------------------

# create certificate signing request
./vwcsr \
-Configuration vwcsr.yaml \
-Basename robinson-example.vw.vwg \
CreateCSR

# pretty print log file
./log-pretty vwcsr.log >vwcsr.log.pretty

# list certificate signing request
openssl req -text -noout -verify -in robinson-example.vw.vwg.csr

#!/bin/sh

# ------------------------------------
# Purpose:
# - import certificate
# 
# Releases:
# - v1.0.0 - 2022-05-13: initial release
# 
# Author:
# - Klaus Tockloth
# ------------------------------------

# import certificate
./vwcsr \
-Configuration vwcsr.yaml \
-Basename robinson-example.vw.vwg \
ImportCertificate

# pretty print log file
./log-pretty vwcsr.log >vwcsr.log.pretty

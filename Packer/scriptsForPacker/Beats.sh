#!/bin/bash

#beats config vars
BEAT_VERSION=8.17.3

#exit on error
set -e

#fn to install beats
installBeats() {
    sudo curl https://artifacts.elastic.co/downloads/beats/$1/$1-$BEAT_VERSION-amd64.deb -o $1-$BEAT_VERSION-amd64.deb
    sudo curl https://artifacts.elastic.co/downloads/beats/$1/$1-$BEAT_VERSION-amd64.deb.sha512 -o $1-$BEAT_VERSION-amd64.deb.sha512
    sudo sha512sum -c $1-$BEAT_VERSION-amd64.deb.sha512
    sudo apt-get -y -o DPkg::Lock::Timeout=600 install ./$1-$BEAT_VERSION-amd64.deb
}

#install specific beats
cd /temp

if [ "$FILEBEAT" -eq 1 ]
then
    installBeats "filebeat"
    sudo systemctl disable filebeat
    sudo systemctl stop filebeat
fi

if [ "$METRICBEAT" -eq 1 ]
then
    installBeats "metricbeat"
    sudo systemctl disable metricbeat
    sudo systemctl stop metricbeat
fi

if [ "$HEARTBEAT" -eq 1 ]
then
    installBeats "heartbeat"
    sudo systemctl disable heartbeat-elastic
    sudo systemctl stop heartbeat-elastic
fi



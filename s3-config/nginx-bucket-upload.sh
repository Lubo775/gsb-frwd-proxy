#!/bin/bash
cd "$(dirname "$0")"

export GSBPROXY_BUCKET="bkt.$ORG_SCOPE.$FUNC_SCOPE.$MODULE_NAME-nginx.$ENVIRONMENT"

#copy files to gsbproxy bucket
aws s3 cp ./filesToUpload/nginx.conf.$ENVIRONMENT s3://$GSBPROXY_BUCKET/nginx/nginx.conf
aws s3 cp ./filesToUpload/configure-beats.sh s3://$GSBPROXY_BUCKET/beatsScript/configure-beats.sh
aws s3 cp ./filesToUpload/heartbeat.yml s3://$GSBPROXY_BUCKET/beatsScript/heartbeat/heartbeat.yml
aws s3 cp ./filesToUpload/gsbproxy-availability.yml s3://$GSBPROXY_BUCKET/beatsScript/heartbeat/monitors.d/gsbproxy-availability.yml
aws s3 cp ./filesToUpload/metricbeat.yml s3://$GSBPROXY_BUCKET/beatsScript/metricbeat/metricbeat.yml
aws s3 cp ./filesToUpload/nginx.yml.metricbeat s3://$GSBPROXY_BUCKET/beatsScript/metricbeat/modules.d/nginx.yml
aws s3 cp ./filesToUpload/nginx.yml.filebeat s3://$GSBPROXY_BUCKET/beatsScript/filebeat/modules.d/nginx.yml
aws s3 cp ./filesToUpload/filebeat.yml s3://$GSBPROXY_BUCKET/beatsScript/filebeat/filebeat.yml

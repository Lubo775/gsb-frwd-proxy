#!/bin/bash
cd "$(dirname "$0")"

export DYNATRACE_BUCKET="bkt.$ORG_SCOPE.$FUNC_SCOPE.$MODULE_NAME-activegate.$ENVIRONMENT"

#s3 upload heartbeat config files
aws s3 cp ./filesToUpload/heartbeat.yml s3://$DYNATRACE_BUCKET/beatsScript/heartbeat/heartbeat.yml
aws s3 cp ./filesToUpload/activegate-availability.yml s3://$DYNATRACE_BUCKET/beatsScript/heartbeat/monitors.d/activegate-availability.yml
aws s3 cp ./filesToUpload/metricbeat.yml s3://$DYNATRACE_BUCKET/beatsScript/metricbeat/metricbeat.yml
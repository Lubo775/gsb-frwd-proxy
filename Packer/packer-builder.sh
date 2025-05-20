#!/bin/bash
cd "$(dirname "$0")"

cd $1
packer init .
packer build golden_ami.pkr.hcl

#remove all AMIs and Snapshots older than specified amount of time from AWS
#as discussed with SO 3 months are good amount of days
days=92

retention_date=$(date '+%Y-%m-%d' --date="$days days ago")
amiid=$(aws ec2 describe-images --filters "Name=tag:AMIFor,Values=$AMIFor" --query 'Images[*].[ImageId,CreationDate]' --output text | awk '{print substr($0,0,32)}' | awk -v d="$retention_date" '$2 <= d' | awk '{print $1}')

if [[ ! -z "$amiid" ]]; then
    echo -e "Found AMIs to be deregistrated \n$amiid"
    snapshot=$(aws ec2 describe-images --image-ids $amiid --output text --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId')
    echo "Removing AMIs and Snapshots older than $days days"
        for i in $amiid;
        do
            echo "Deregistring AMI ID $i"
            aws ec2 deregister-image --image-id "$i"
        done
        for j in $snapshot;
        do
            echo "Deleting AMI snapshot $j"
            aws ec2 delete-snapshot --snapshot-id "$j"
        done
else
    echo "No AMIs older than $days days found"
fi
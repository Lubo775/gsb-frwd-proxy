#!/bin/bash

export TF_VAR_account_number="$ACCOUNT_NUMBER"
export TF_VAR_region="$AWS_DEFAULT_REGION"
export TF_VAR_module_name="$MODULE_NAME"
export TF_VAR_org_scope="$ORG_SCOPE"
export TF_VAR_func_scope="$FUNC_SCOPE"
export TF_VAR_environment="$ENVIRONMENT"

cd "$(dirname "$0")"

s3BucketName="bkt.$ORG_SCOPE.$FUNC_SCOPE.$MODULE_NAME-nginx.$ENVIRONMENT"
s3BucketRegion="$AWS_DEFAULT_REGION"
s3BucketEncrypt="false"
s3TfLocation="cq/certnotifier/terraform.tfstate"
#wrong path to tfvars for now
#tfvarsFile="../TFVARS/ASG/$1.tfvars"

terraform init \
  -backend-config="key=$s3TfLocation" \
  -backend-config="bucket=$s3BucketName" \
  -backend-config="region=$s3BucketRegion" \
  -backend-config="encrypt=$s3BucketEncrypt" \
  -force-copy

if [ -z "$1" ]
then
  terraform plan \
    -var "s3_tf_location=$s3TfLocation" \
    -var "s3_bucket_name=$s3BucketName" \
    -var "s3_bucket_region=$s3BucketRegion" \
    -var "s3_bucket_encrypt=$s3BucketEncrypt" \
    -out="generatedPlanToBuild"

  #store generated plan for terraform apply
  if [ -e generatedPlanToBuild ]
  then
    aws s3 cp generatedPlanToBuild s3://$s3BucketName/cq/certnotifier/
  fi

  if [ -e ../CertNotifier.zip ]
  then
    aws s3 cp ../CertNotifier.zip s3://$s3BucketName/cq/certnotifier/
  fi
fi

if [ "$1" == "apply" ]
then
  aws s3 cp s3://$s3BucketName/cq/certnotifier/generatedPlanToBuild .
  aws s3 cp s3://$s3BucketName/cq/certnotifier/CertNotifier.zip .
  terraform apply "generatedPlanToBuild"
fi

if [ "$1" == "destroy-plan" ]
then
  terraform plan -destroy -var "s3_tf_location=$s3TfLocation" \
    -var "s3_bucket_name=$s3BucketName" \
    -var "s3_bucket_region=$s3BucketRegion" \
    -var "s3_bucket_encrypt=$s3BucketEncrypt"
fi

if [ "$1" == "destroy" ]
then
  terraform destroy -var "s3_tf_location=$s3TfLocation" \
    -var "s3_bucket_name=$s3BucketName" \
    -var "s3_bucket_region=$s3BucketRegion" \
    -var "s3_bucket_encrypt=$s3BucketEncrypt"  \
    -auto-approve
fi


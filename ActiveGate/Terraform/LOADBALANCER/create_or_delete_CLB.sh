#!/bin/bash

export TF_VAR_org_scope="$ORG_SCOPE"
export TF_VAR_func_scope="$FUNC_SCOPE"
export TF_VAR_environment="$ENVIRONMENT"
export TF_VAR_dynatrace_clb_sg="sg.$ORG_SCOPE.$FUNC_SCOPE.$MODULE_NAME-dynatrace.$ENVIRONMENT.clb"
export TF_VAR_load_balancer_name="lb-shs-$MODULE_NAME-dtrace-$ENVIRONMENT"

export ENV_DNS=$(
  case $ENVIRONMENT in
    ("plint-001") echo "plint001" ;;
    ("plint-002") echo "plint002" ;;

    ("tui-dev-001") echo "dev001" ;;
    ("tui-demo") echo "dmo" ;;

    ("approval") echo "app" ;;
    ("prelive") echo "pre" ;;
    ("preprod") echo "pre" ;;

    ("live") echo "prd" ;;
    ("prod") echo "prd" ;;

    ("dev-001") echo "dev001" ;;
    (*) echo $ENVIRONMENT ;;
  esac
)

export TF_VAR_route53_zone_name="$ENV_DNS.shs.eu.$ORG_SCOPE.odp.cloud.vwgroup.com."
export TF_VAR_route53_internal_name="dynatrace.$ENV_DNS.shs.eu.$ORG_SCOPE.odp.cloud.vwgroup.com"

cd "$(dirname "$0")"
#print TF version in docker image
terraform version

s3BucketName="bkt.$ORG_SCOPE.$FUNC_SCOPE.$MODULE_NAME-activegate.$ENVIRONMENT"
s3BucketRegion="$REGION"
s3BucketEncrypt="false"
s3TfLocation="cq/lb/terraform.tfstate"
tfvarsFile="../TFVARS/CLB/$1.tfvars"

#s3 read-check
echo "aws s3 ls 's3://$s3BucketName' : "$(aws s3 ls s3://$s3BucketName)
if aws s3 ls "s3://$s3BucketName" 2>&1 | grep -q 'NoSuchBucket'
then
echo 'creating bucket'
aws s3 mb s3://$s3BucketName --region $REGION
fi

terraform init \
  -backend-config="key=$s3TfLocation" \
  -backend-config="bucket=$s3BucketName" \
  -backend-config="region=$s3BucketRegion" \
  -backend-config="encrypt=$s3BucketEncrypt" \
  -force-copy

if [ -z "$2" ]
then
  terraform plan \
    -var "s3_tf_location=$s3TfLocation" \
    -var "s3_bucket_name=$s3BucketName" \
    -var "s3_bucket_region=$s3BucketRegion" \
    -var "s3_bucket_encrypt=$s3BucketEncrypt" \
    -var-file="$tfvarsFile" \
    -out="generatedPlanToBuild"

  #store generated plan for terraform apply
  if [ -e generatedPlanToBuild ]
  then
    aws s3 cp generatedPlanToBuild s3://$s3BucketName/cq/lb/
  fi
fi

if [ "$2" == "apply" ]
then
  aws s3 cp s3://$s3BucketName/cq/lb/generatedPlanToBuild .
  terraform apply "generatedPlanToBuild"
fi

if [ "$2" == "destroy-plan" ]
then
  terraform plan -destroy -var "s3_tf_location=$s3TfLocation" \
    -var "s3_bucket_name=$s3BucketName" \
    -var "s3_bucket_region=$s3BucketRegion" \
    -var "s3_bucket_encrypt=$s3BucketEncrypt"  \
    -var-file=$tfvarsFile
fi

if [ "$2" == "destroy" ]
then
  terraform destroy -var "s3_tf_location=$s3TfLocation" \
    -var "s3_bucket_name=$s3BucketName" \
    -var "s3_bucket_region=$s3BucketRegion" \
    -var "s3_bucket_encrypt=$s3BucketEncrypt"  \
    -var-file=$tfvarsFile \
    -auto-approve
fi
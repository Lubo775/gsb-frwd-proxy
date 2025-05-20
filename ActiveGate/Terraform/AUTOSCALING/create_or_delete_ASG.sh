#!/bin/bash

export TF_VAR_op_username="$OP_USERNAME"
export TF_VAR_op_password="$OP_PASSWORD"
export TF_VAR_org_scope="$ORG_SCOPE"
export TF_VAR_func_scope="$FUNC_SCOPE"
export TF_VAR_module_name="$MODULE_NAME"
export TF_VAR_environment="$ENVIRONMENT"
export TF_VAR_stage="$STAGE"
export TF_VAR_vault_address="$VAULT_ADDRESS"
export TF_VAR_concourse_name="$CONCOURSE_NAME"
export TF_VAR_concourse_team="$CONCOURSE_TEAM"
export TF_VAR_vault_path="secret/$ORG_SCOPE/$FUNC_SCOPE/$MODULE_NAME/$ENVIRONMENT"
export TF_VAR_dynatrace_clb_sg="sg.$ORG_SCOPE.$FUNC_SCOPE.$MODULE_NAME-dynatrace.$ENVIRONMENT.clb"
export TF_VAR_sg_autoscaling="sg.$ORG_SCOPE.$FUNC_SCOPE.$MODULE_NAME-dynatrace.$ENVIRONMENT.asg"
export TF_VAR_load_balancer_name="lb-shs-$MODULE_NAME-dtrace-$ENVIRONMENT"
export TF_VAR_aws_iam_role="rle.$ORG_SCOPE.$FUNC_SCOPE.$MODULE_NAME-runtime.$ENVIRONMENT"
export TF_VAR_instance_name="ec2.$ORG_SCOPE.$FUNC_SCOPE.$MODULE_NAME-activegate.$ENVIRONMENT.node"
export TF_VAR_s3_bucket="bkt.$ORG_SCOPE.$FUNC_SCOPE.$MODULE_NAME-activegate.$ENVIRONMENT"

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

export TF_VAR_active_gate_clb="dynatrace.$ENV_DNS.shs.eu.$ORG_SCOPE.odp.cloud.vwgroup.com"
export TF_VAR_apmaas_vpc_endpoint="apmaas-endpoint.$ENV_DNS.shs.eu.$ORG_SCOPE.odp.cloud.vwgroup.com"

cd "$(dirname "$0")"

s3BucketName="bkt.$ORG_SCOPE.$FUNC_SCOPE.$MODULE_NAME-activegate.$ENVIRONMENT"
s3BucketRegion="$REGION"
s3BucketEncrypt="false"
s3TfLocation="cq/ec2/terraform.tfstate"
tfvarsFile="../TFVARS/ASG/$1.tfvars"

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
    aws s3 cp generatedPlanToBuild s3://$s3BucketName/cq/ec2/
  fi
fi

if [ "$2" == "apply" ]
then
  aws s3 cp s3://$s3BucketName/cq/ec2/generatedPlanToBuild .
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
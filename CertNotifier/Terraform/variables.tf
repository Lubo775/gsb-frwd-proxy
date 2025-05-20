variable "s3_tf_location" {}
variable "s3_bucket_name" {}
variable "s3_bucket_region" {}
variable "s3_bucket_encrypt" {}
variable "account_number" {}
variable "region" {}
variable "module_name" {}
variable "org_scope" {}
variable "func_scope" {}
variable "environment" {}
variable "provider_region" {
    default = "eu-west-1"
}
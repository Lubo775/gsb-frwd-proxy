variable "s3_tf_location" {}
variable "s3_bucket_name" {}
variable "s3_bucket_region" {}
variable "s3_bucket_encrypt" {}
variable "func_scope" {}
variable "org_scope" {}
variable "environment" {}
variable "dynatrace_clb_sg" {}
variable "sg_autoscaling" {}
variable "instance_type" {}
variable "aws_iam_role" {}
variable "volume_type" {}
variable "ebs_volume_size" {}
variable "instance_name" {}
variable "module_name" {}
variable "load_balancer_name" {}
variable "s3_bucket" {}
variable "active_gate_clb" {}
variable "apmaas_vpc_endpoint" {}
variable "vault_address" {}
variable "vault_path" {}
variable "stage" {}
variable "concourse_name" {}
variable "concourse_team" {}
variable "op_password" {}
variable "op_username" {}

variable "provider_region" {
    default = "eu-west-1"
}

variable "tier" {
	default = "application"
}

variable "asg_config" {
	type = map(string)
	default = {
		max_size                  = 3
		min_size                  = 1
		desired_capacity          = 2
		min_elb_capacity          = 1
		health_check_grace_period = 300
		health_check_type         = "ELB"
	}
}

variable "owner_email" {
	default = "martin.wuschke@volkswagen.de"
}

variable "project_id" {
	default = "MBB"
}

variable "application_id" {
	default = "GSB-FORWARD-PROXY-DYNATRACE"
}

variable "network" {
	default = "private"
}

variable "inspector_scan" {
	default = "true"
}
#is this same as GSB Proxy ???
variable "gitc_application_id" {
	default = "CI00763981"
}

variable "gitc_riskclass_mapping" {
	default = {
		"prod" = "2"
	}
}

variable "gitc_dataclassification" {
	default = "internal"
}

variable "gitc_personaldata" {
	default = "false"
}

variable "gitc_vulnscantool" {
	default = "tenable_io"
}

variable "gitc_prodstage_mapping" {
	default = {
		"prod" = "true"
	}
}

variable "gitc_operationscontact" {
	default = "GITC GSB Proxy Support VW Group"
}

variable "gitc-securitycontact" {
	default = "gitc.cloud.security.vwag.r.wob@volkswagen.de"
}

variable "app_version" {
	default = "1.0.0"
}

variable "sc_ass_group" {
  default = "GITC GSB Proxy Support VW Group"
  description = "SC3 Assignment Group of the Service"
}

variable "sc_ci_name" {
  default = "GITC GSB PROXY (Q-AWS EU-WEST-1)"
  description = "SC3 CI Name"
}

variable "platform_name" {
  default = "odp"
}

variable "dynatrace_tui_cluster_id" {
	default = "9ad3b457-4663-4725-955b-75c73d7f234b"
}

variable "dynatrace_approval_cluster_id" {
	default = "5cf3d462-bd74-4042-b4a0-3e4da9808b39"
}

variable "dynatrace_live_cluster_id" {
	default = "487b1f82-6374-461a-9ab1-5377b1c175f7"
}
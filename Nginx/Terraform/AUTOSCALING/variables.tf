variable "region" {
	default = "eu-west-1"
}

variable "project_id" {
	default = "MBB"
}
variable "application_id" {
	default = "GSB-FORWARD-PROXY"
}
variable "app_version" {
	default = "1.2.2"
}
variable "module_name" {}
variable "org_scope" {}
variable "func_scope" {}
variable "environment" {}
variable "stage" {}
variable "aws_iam_role" {}
variable "instance_name" {}
variable "gsbproxy_bucket" {}
variable "vault_address" {}
variable "vault_path" {}
variable "concourse_name" {}
variable "concourse_team" {}
variable "sg_autoscaling" {}
variable "ebs_volume_size" {}
variable "apmaas_vpc_endpoint" {}
variable "op_password" {}
variable "op_username" {}

variable "apps_functional_scope" {
	default = "corebe"
}
variable "tiers" {
	type = map(string)
	default = {
		"transfer" = "application"
	}
}
variable "network" {
	default = "private"
}
variable "inspector_scan" {
	default = "true"
}
variable "owner_email" {
	default = "martin.wuschke@volkswagen.de"
}
#variable "ami_id" {
#}
variable "ami_owner" {
	default = "246348377581"
}
variable "instance_type" {
	default="m5d.large"
}
variable "load_balancer_name" {}
variable "load_balancer" {
	type = map(string)
	default = {
		cross_zone_load_balancing = "true"
		idle_timeout = "60"
		connection_draining = "true"
		connection_draining_timeout = "300"
	}
}

variable "asg_config" {
	type = map(string)
	default = {
		max_size = 4
		min_size = "2"
		desired_capacity = "2"
		min_elb_capacity          = "2"
		health_check_grace_period = "300"
		health_check_type         = "EC2"
	}
}

variable "plattform_name" {
  default = "odp"
}

variable "sc_ci_name" {
  default = "GITC GSB PROXY (Q-AWS EU-WEST-1)"
  description = "SC3 CI Name"
}
variable "sc_ass_group" {
  default = "GITC GSB Proxy Support VW Group"
  description = "SC3 Assignment Group of the Service"
}
variable "ops_team_mailbox" {
  default = "vwgs_gitc_operations_gsbproxy@volkswagen-groupservices.com"
}

#storing State in S3
variable "s3_bucket_region" {}
variable "s3_bucket_name" {}
variable "s3_tf_location" {}
variable "s3_bucket_encrypt" {}

###############################
# Resource tagging variables
###############################
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

variable "dynatrace_tui_cluster_id" {
	default = "9ad3b457-4663-4725-955b-75c73d7f234b"
}

variable "dynatrace_approval_cluster_id" {
	default = "5cf3d462-bd74-4042-b4a0-3e4da9808b39"
}

variable "dynatrace_live_cluster_id" {
	default = "487b1f82-6374-461a-9ab1-5377b1c175f7"
}
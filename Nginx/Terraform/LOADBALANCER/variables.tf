variable "route53_internal_name" {}
variable "route53_zone_name" {}
variable "route53_internal_type" {
	default = "A"
}
variable "provider_region" {
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
variable "org_scope" {}
variable "environment" {}
variable "func_scope" {}
variable "gsb_clb_sg" {}

variable "s3_bucket_name" {}
variable "s3_tf_location" {}
variable "s3_bucket_encrypt" {}
variable "apps_func_scope" {
	default = "corebe"
}
variable "inspector_scan" {
	default = "true"
}
variable "owner_email" {
	default = "martin.wuschke@volkswagen.de"
}
variable "tiers" {
	type = map(string)
	default = {
		"transfer" = "application"
	}
}
variable "corebe_vpc_cidr" {
	type= list(string)
}
variable "s3_bucket_region" {
	default="eu-west-1"
}

# Resource tagging variables
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
variable "gitc_securitycontact" {
	default = "gitc.cloud.security.vwag.r.wob@volkswagen.de"
}


# Load balancer
variable "load_balancer" {
	type = map(string)
	default = {
		cross_zone_load_balancing = "true"
		idle_timeout = "60"
		connection_draining = "true"
		connection_draining_timeout = "300"
	}
}
variable "load_balancer_name" {}
variable "lb_listeners" {
	type = list(object({
		instance_port = number
		instance_protocol = string
		lb_port = number
		lb_protocol = string
	}))
	default = [
		{
    		instance_port = 443
    		instance_protocol = "tcp"
    		lb_port = 443
    		lb_protocol = "tcp"
		}
	]
}
variable "lb_health_checks" {
	type = list(object({
		healthy_threshold = number
		unhealthy_threshold = number
		timeout = number
		target = string
		interval = number
	}))
	default = [
		{
    		healthy_threshold = 2
			unhealthy_threshold = 2
			timeout = 5
			target = "tcp:443"
			interval = 10
		}
	]
}

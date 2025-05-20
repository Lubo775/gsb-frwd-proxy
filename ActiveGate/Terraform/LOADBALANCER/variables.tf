variable "s3_bucket_region" {}
variable "s3_bucket_name" {}
variable "s3_tf_location" {}
variable "s3_bucket_encrypt" {}
variable "environment" {}
variable "org_scope" {}
variable "func_scope" {}
variable "dynatrace_clb_sg" {}
variable "route53_zone_name" {}
variable "load_balancer_name" {}
variable "route53_internal_name" {}

variable "provider_region" {
	default = "eu-west-1"
}

variable "tier" {
	default = "application"
}

variable "route53_internal_type" {
	default = "A"
}

variable "own_vpc_cidr" {
	type= list(string)
}

variable "load_balancer" {
	type = map(string)
	default = {
		cross_zone_load_balancing = "true"
		idle_timeout = "60"
		connection_draining = "true"
		connection_draining_timeout = "300"
	}
}

variable "lb_listeners" {
	type = list(object({
		instance_port = number
		instance_protocol = string
		lb_port = number
		lb_protocol = string
	}))
	default = [
		{
    		instance_port = 9999
    		instance_protocol = "tcp"
    		lb_port = 9999
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
			target = "tcp:9999"
			interval = 10
		}
	]
}
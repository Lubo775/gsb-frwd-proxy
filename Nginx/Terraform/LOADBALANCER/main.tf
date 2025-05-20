terraform {
  backend "s3" {}
}

data "terraform_remote_state" "state" {
  backend = "s3"
  config = {
    region     = "${var.s3_bucket_region}"
    bucket     = "${var.s3_bucket_name}"
    key        = "${var.s3_tf_location}"
    encrypt    = "${var.s3_bucket_encrypt}"
  }
}

######################################################
#Data source for VPCs
######################################################
data "aws_vpc" "default" {
  tags = {
    Environment = "${var.environment}"
    OrgScope = "${var.org_scope}"
    FunctionalScope = "${var.func_scope}"
  }
}

##################################################
#Data source for subnets
##################################################
data "aws_subnets" "transfer" {
  filter {
    name   = "vpc-id"
    values = ["${data.aws_vpc.default.id}"]
  }

  tags = {
    Tier = "${var.tiers["transfer"]}"
    Environment = "${var.environment}"
    OrgScope = "${var.org_scope}"
    FunctionalScope = "${var.func_scope}"
  }
}

data "aws_subnet" "transfer" {
  count = "${length(data.aws_subnets.transfer.ids)}"
  id    = "${tolist(data.aws_subnets.transfer.ids)[count.index]}"
}


#CLB SECURITY GROUP
resource "aws_security_group" "sgCLB" {
  name   = "${var.gsb_clb_sg}"
  vpc_id = "${data.aws_vpc.default.id}"
  description = "SG for gsb lb"

  # https access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = "${var.corebe_vpc_cidr}"
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Route 53 zone
data "aws_route53_zone" "gsbFwdLBZone" {
  name = "${var.route53_zone_name}"
  private_zone = true
}

output "instance_ip_addr" {
  value = "${var.route53_zone_name}"
}

# CLASSIC LOAD BALANCER
resource "aws_elb" "AutoscalingCLB" {
  name = "${var.load_balancer_name}"
	subnets = "${data.aws_subnet.transfer.*.id}"
  internal = true
	security_groups = ["${aws_security_group.sgCLB.id}"]

	listener {
	  instance_port = "${lookup(var.lb_listeners[0], "instance_port")}"
	  instance_protocol = "${lookup(var.lb_listeners[0], "instance_protocol")}"
		lb_port = "${lookup(var.lb_listeners[0], "lb_port")}"
		lb_protocol = "${lookup(var.lb_listeners[0], "lb_protocol")}"
	}

	health_check {
		healthy_threshold = "${lookup(var.lb_health_checks[0], "healthy_threshold")}"
		unhealthy_threshold = "${lookup(var.lb_health_checks[0], "unhealthy_threshold")}"
		timeout = "${lookup(var.lb_health_checks[0], "timeout")}"
		target = "${lookup(var.lb_health_checks[0], "target")}"
		interval = "${lookup(var.lb_health_checks[0], "interval")}"
	}

  cross_zone_load_balancing = "${var.load_balancer["cross_zone_load_balancing"]}"
	idle_timeout = "${var.load_balancer["idle_timeout"]}"
	connection_draining = "${var.load_balancer["connection_draining"]}"
	connection_draining_timeout = "${var.load_balancer["connection_draining_timeout"]}"

	tags = {
    Name = "${var.load_balancer_name}"
    OwnerEmail = "${var.owner_email}"
    ProjectID = "${var.project_id}"
    ApplicationID = "${var.application_id}"
    AppVersion = "${var.app_version}"
    OrgScope = "${var.org_scope}"
    FunctionalScope = "${var.func_scope}"
    GITC-PersonalData = "${var.gitc_personaldata}"
    GITC-VulnScanTool = "${var.gitc_vulnscantool}"
    GITC-OperationsContact = "${var.gitc_operationscontact}"
    GITC-SecurityContact = "${var.gitc_securitycontact}"
  }
}
# Route 53 record set 1
resource "aws_route53_record" "route53InternalGSB" {
  zone_id = "${data.aws_route53_zone.gsbFwdLBZone.zone_id}"
  name = "${var.route53_internal_name}"
  type    = "${var.route53_internal_type}"
  alias {
    name                   = "${aws_elb.AutoscalingCLB.dns_name}"
    zone_id                = "${aws_elb.AutoscalingCLB.zone_id}"
    evaluate_target_health = false
  }
}
# Route 53 record set any
resource "aws_route53_record" "route53InternalGSB2" {
  zone_id = "${data.aws_route53_zone.gsbFwdLBZone.zone_id}"
  name = "*.${var.route53_internal_name}"
  type    = "${var.route53_internal_type}"
  alias {
    name                   = "${aws_elb.AutoscalingCLB.dns_name}"
    zone_id                = "${aws_elb.AutoscalingCLB.zone_id}"
    evaluate_target_health = false
  }
}

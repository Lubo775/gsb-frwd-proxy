terraform {
    backend "s3" {
        bucket  = "${var.s3_bucket_name}"
        key     = "${var.s3_tf_location}"
        region  = "${var.s3_bucket_region}"
        encrypt = "${var.s3_bucket_encrypt}"
    }
}

data "aws_vpc" "default" {
    tags = {
        Environment     = "${var.environment}"
        OrgScope        = "${var.org_scope}"
        FunctionalScope = "${var.func_scope}"
    }
}

data "aws_subnets" "transfer" {
    filter {
        name   = "vpc-id"
        values = ["${data.aws_vpc.default.id}"]
    }

    tags = {
        Tier            = "${var.tier}"
        Environment     = "${var.environment}"
        OrgScope        = "${var.org_scope}"
        FunctionalScope = "${var.func_scope}"
    }
}

data "aws_subnet" "transfer" {
    count = "${length(data.aws_subnets.transfer.ids)}"
    id    = "${tolist(data.aws_subnets.transfer.ids)[count.index]}"
}

resource "aws_security_group" "sgCLB" {
    name        = "${var.dynatrace_clb_sg}"
    vpc_id      = "${data.aws_vpc.default.id}"
    description = "SG for Dynatrace LB"

    ingress {
        from_port   = 9999
        to_port     = 9999
        protocol    = "tcp"
        cidr_blocks = "${var.own_vpc_cidr}"
    }

# outbound internet access
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# CLASSIC LOAD BALANCER
resource "aws_elb" "AutoscalingCLB" {
    name                        = "${var.load_balancer_name}"
    subnets                     = "${data.aws_subnet.transfer.*.id}"
    internal                    = true
    security_groups             = ["${aws_security_group.sgCLB.id}"]
    cross_zone_load_balancing   = "${var.load_balancer["cross_zone_load_balancing"]}"
	idle_timeout                = "${var.load_balancer["idle_timeout"]}"
	connection_draining         = "${var.load_balancer["connection_draining"]}"
	connection_draining_timeout = "${var.load_balancer["connection_draining_timeout"]}"

    listener {
        instance_port     = "${lookup(var.lb_listeners[0], "instance_port")}"
	    instance_protocol = "${lookup(var.lb_listeners[0], "instance_protocol")}"
	    lb_port           = "${lookup(var.lb_listeners[0], "lb_port")}"
	    lb_protocol       = "${lookup(var.lb_listeners[0], "lb_protocol")}"
    }

    health_check {
	    healthy_threshold   = "${lookup(var.lb_health_checks[0], "healthy_threshold")}"
		unhealthy_threshold = "${lookup(var.lb_health_checks[0], "unhealthy_threshold")}"
		timeout             = "${lookup(var.lb_health_checks[0], "timeout")}"
		target              = "${lookup(var.lb_health_checks[0], "target")}"
		interval            = "${lookup(var.lb_health_checks[0], "interval")}"
	}

    tags = {
        Name = "${var.load_balancer_name}"
    }
}

# Route 53 zone
data "aws_route53_zone" "route53Zone" {
    name         = "${var.route53_zone_name}"
    private_zone = true
}

# Route 53 record
resource "aws_route53_record" "route53InternalCLB" {
  zone_id = "${data.aws_route53_zone.route53Zone.zone_id}"
  name    = "${var.route53_internal_name}"
  type    = "${var.route53_internal_type}"
  alias {
    name                   = "${aws_elb.AutoscalingCLB.dns_name}"
    zone_id                = "${aws_elb.AutoscalingCLB.zone_id}"
    evaluate_target_health = false
  }
}
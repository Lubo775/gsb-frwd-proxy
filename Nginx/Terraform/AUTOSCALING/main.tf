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
#Data source for deployment VPC
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

#######################################
#CREATE SECURITY GROUP FOR INSTANCES
#######################################
resource "aws_security_group" "AutoScalingInstancesSG" {
  name  = "${var.sg_autoscaling}"
  vpc_id = "${data.aws_vpc.default.id}"
  description = "GSB AutoScalingInstances SG"

  # TCP access on port 443 for nginx traffic
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = "${data.aws_subnet.transfer.*.cidr_block}"
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
	dynatrace_cluster_id = var.environment == "plint" ? var.dynatrace_tui_cluster_id : var.environment == "preprod" ? var.dynatrace_approval_cluster_id : var.dynatrace_live_cluster_id
}

#############################
#CREATE LAUNCH TEMPLATE
#############################

#create template for must_run scripts which are essential for running whole GSB proxy service properly
data "template_file" "must_run_scripts" {
  template = file("must_run.sh")
  vars = {
    gsbproxy_bucket       = var.gsbproxy_bucket
    instance_name         = var.instance_name
    application_id        = var.application_id
    ops_team_mailbox      = var.ops_team_mailbox
    network               = var.network
    tiers_transfer        = var.tiers["transfer"]
    org_scope             = var.org_scope
    func_scope            = var.func_scope
    environment           = var.environment
    app_version           = var.app_version
    application_id        = var.application_id
    stage                 = var.stage
    region                = var.region
    module_name           = var.module_name
    project_id            = var.project_id
    concourse_name        = var.concourse_name
    concourse_team        = var.concourse_team
    sc_ci_name            = var.sc_ci_name
    sc_ass_group          = var.sc_ass_group
    plattform_name        = var.plattform_name
    vault_address         = var.vault_address
    vault_path            = var.vault_path
    aws_iam_role          = var.aws_iam_role
    dynatrace_cluster_id  = local.dynatrace_cluster_id
    apmaas_vpc_endpoint   = var.apmaas_vpc_endpoint
    op_username           = var.op_username
    op_password           = var.op_password
  }
}

data "aws_ami" "nginx_latest" {
  most_recent = true
  owners = ["335913599016"]

  filter {
    name   = "name"
    values = ["gsbproxy-nginx-ami-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "LaunchTemplate" {
  name_prefix            = "lt-gsb-nginx"
  image_id               = "${data.aws_ami.nginx_latest.id}"
  instance_type          = "${var.instance_type}"
  update_default_version = true

  iam_instance_profile {
    name = "${var.aws_iam_role}"
  }

  network_interfaces {
    security_groups = ["${aws_security_group.AutoScalingInstancesSG.id}"]
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type = "gp3"
      volume_size = "${var.ebs_volume_size}"
    }
  }
  user_data = "${base64encode(data.template_file.must_run_scripts.rendered)}"
}

resource "aws_cloudwatch_metric_alarm" "UnhealthyHostCount" {
  alarm_name                = "GSBProxyUnhealthyHost-Nginx"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 5
  metric_name               = "UnHealthyHostCount"
  namespace                 = "AWS/ELB"
  period                    = 60
  statistic                 = "Maximum"
  threshold                 = 1
  alarm_description         = "This metric monitors UnhealthyHostCount"
  datapoints_to_alarm       = 5
  actions_enabled = false
  dimensions = {
    LoadBalancerName = data.aws_elb.elb.name
  }
}

#################################
# Data source for Loadbalancer
#################################
data "aws_elb" "elb" {
	name = "${var.load_balancer_name}"
}

##########################
#CREATE AUTOSCALING GROUP
##########################
resource "aws_autoscaling_group" "ASG" {
  vpc_zone_identifier       = "${data.aws_subnet.transfer.*.id}"
  name                      = "asg-${aws_launch_template.LaunchTemplate.name}"
  load_balancers            = ["${data.aws_elb.elb.name}"]
  termination_policies      = ["OldestLaunchTemplate"]
  max_size                  = "${var.asg_config["max_size"]}"
  min_size                  = "${var.asg_config["min_size"]}"
  desired_capacity          = "${var.asg_config["desired_capacity"]}"
  min_elb_capacity          = "${var.asg_config["min_elb_capacity"]}"
  health_check_grace_period = "${var.asg_config["health_check_grace_period"]}"
  health_check_type         = "${var.asg_config["health_check_type"]}"
  
  launch_template {
    name = aws_launch_template.LaunchTemplate.name
    version = aws_launch_template.LaunchTemplate.latest_version
  }

   instance_refresh {
    strategy = "Rolling"
    preferences {
      auto_rollback = true
      min_healthy_percentage = 100
      max_healthy_percentage = 200
      alarm_specification {
        alarms = [aws_cloudwatch_metric_alarm.UnhealthyHostCount.alarm_name]
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }
  
  tag {
        key                 = "Name"
        value               = "${var.instance_name}"
        propagate_at_launch = true
  }
  tag {
        key                 = "OwnerEmail"
        value               = "${var.owner_email}"
        propagate_at_launch = true
  }

  tag {
        key                 = "ProjectID"
        value               = "${var.project_id}"
        propagate_at_launch = true
  }

  tag {
        key                 = "ApplicationID"
        value               = "${var.application_id}"
        propagate_at_launch = true
  }

  tag {
        key                 = "ModuleName"
        value               = "${var.module_name}"
        propagate_at_launch = true
  }

  tag {
        key                 = "AppVersion"
        value               = "${var.app_version}"
        propagate_at_launch = true
  }

  tag {
        key                 = "OrgScope"
        value               = "${var.org_scope}"
        propagate_at_launch = true
  }

  tag {
        key                 = "FunctionalScope"
        value               = "${var.func_scope}"
        propagate_at_launch = true
  }

  tag {
        key                 = "Environment"
        value               = "${var.environment}"
        propagate_at_launch = true
  }

  tag {
        key                 = "Tier"
        value               = "${var.tiers["transfer"]}"
        propagate_at_launch = true
  }

  tag {
        key                 = "Network"
        value               = "${var.network}"
        propagate_at_launch = true
  }

  tag {
        key                 = "Inspectorscan"
        value               = "${var.inspector_scan}"
        propagate_at_launch = true
  }

  tag {
        key                 = "GITC-RessourceName"
        value               = "${var.instance_name}"
        propagate_at_launch = true
  }

  tag {
        key                 = "GITC-ApplicationID"
        value               = "${var.gitc_application_id}"
        propagate_at_launch = true
  }

  tag {
        key                 = "GITC-RiskClass"
        value               = "${lookup(var.gitc_riskclass_mapping, var.environment, "4")}"
        propagate_at_launch = true
  }

  tag {
        key                 = "GITC-DataClassification"
        value               = "${var.gitc_dataclassification}"
        propagate_at_launch = true
  }

  tag {
        key                 = "GITC-PersonalData"
        value               = "${var.gitc_personaldata}"
        propagate_at_launch = true
  }

  tag {
        key                 = "GITC-VulnScanTool"
        value               = "${var.gitc_vulnscantool}"
        propagate_at_launch = true
  }

  tag {
        key                 = "GITC-ProdStage"
        value               = "${lookup(var.gitc_prodstage_mapping, var.environment, "false")}"
        propagate_at_launch = true
  }

  tag {
        key                 = "GITC-OperationsContact"
        value               = "${var.gitc_operationscontact}"
        propagate_at_launch = true
  }

  tag {
        key                 = "GITC-SecurityContact"
        value               = "${var.gitc-securitycontact}"
        propagate_at_launch = true
      }
}
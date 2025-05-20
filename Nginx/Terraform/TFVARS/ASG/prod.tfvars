#larger then default
instance_type = "m5d.xlarge"

#Size of EBS root volume
ebs_volume_size = 30

#prod ci id
gitc_application_id="CI00763998"

#prod ci name
sc_ci_name="GITC GSB PROXY (P-AWS EU-WEST-1)"

# Auto-scaling group
asg_config = {
	max_size = 10
	min_size = "2"
	desired_capacity = "3"
	min_elb_capacity          = "3"
	health_check_grace_period = "300"
	health_check_type         = "ELB"
}

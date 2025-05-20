#Size of EBS root volume
ebs_volume_size = 20

#prod ci id
gitc_application_id="CI00763981"

#prod ci name
sc_ci_name="GITC GSB PROXY (Q-AWS EU-WEST-1)"

# Auto-scaling group
asg_config = {
	max_size = 3
	min_size = "1"
	desired_capacity = "2"
	min_elb_capacity          = "1"
	health_check_grace_period = "300"
	health_check_type         = "ELB"
}

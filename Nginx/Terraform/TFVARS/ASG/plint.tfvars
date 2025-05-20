#smaller then default
instance_type = "t2.micro"

#Size of EBS root volume
ebs_volume_size = 20

# Auto-scaling group
asg_config = {
	max_size = "1"
	min_size = "1"
	desired_capacity = "1"
	min_elb_capacity          = "1"
	health_check_grace_period = "300"
	health_check_type         = "ELB"
}

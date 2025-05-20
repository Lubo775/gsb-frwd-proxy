variable "func_scope" {
  type    = string
  default = "${env("FUNC_SCOPE")}"
}

variable "org_scope" {
  type    = string
  default = "${env("ORG_SCOPE")}"
}

variable "environment" {
  type    = string
  default = "${env("ENVIRONMENT")}"
}

variable "module_name" {
  type = string
  default = "${env("MODULE_NAME")}"
}

variable "op_username" {
  type = string
  default = "${env("OP_USERNAME")}"
}

variable "op_password" {
  type = string
  default = "${env("OP_PASSWORD")}"
}

variable "apmaas_vpc_endpoint" {
  type = string
  default = "apmaas-endpoint.plint.shs.eu.pti.odp.cloud.vwgroup.com"
}

variable "dynatrace_tui_cluster_id" {
  type = string
  default = "9ad3b457-4663-4725-955b-75c73d7f234b"
}

#########################################################################
packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.6"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "golden_ami" {
  ami_name  = "gsbproxy-activegate-ami-${local.timestamp}"
  ami_users = ["335913599016", "378090867873", "541203038865"]

  source_ami_filter {
    filters = {
      name                = "*IF20-UBUNTU-24.04-GROUP-PROD-*-AMI" #latest ubuntu 24.04 ami
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["879919243408"] #Image Factory 2.0 owner account id
  }


  instance_type = "t2.small"
  region = "eu-west-1"
  ssh_username = "ubuntu"
  associate_public_ip_address = "false"
  iam_instance_profile= "rle.${var.org_scope}.${var.func_scope}.${var.module_name}-runtime.${var.environment}"

  run_tags = {
    Application             = "GSB-FORWARD-PROXY"
    Base_AMI_ID             = "{{ .SourceAMI }}"
    Base_AMI_Name           = "{{ .SourceAMIName }}"
    GITC-ApplicationID      = "CI00763981"
    GITC-DataClassification = "Internal"
    GITC-OperationsContact  = "vwgs_gitc_operations_gsbproxy@volkswagen-groupservices.com"
    GITC-PersonalData       = "False"
    GITC-ProdStage	        = "True"
    OwnerEmail              = "martin.wuschke@volkswagen.de"
    AMIFor                  = "ActiveGate"
  }

  subnet_filter {
    filters = {
      "tag:Tier" = "application"
    }
    most_free = true
  }

  vpc_filter {
    filters = {
      "tag:Name" = "vpc.${var.org_scope}.${var.func_scope}.${var.environment}"
    }
  }
}

build {
    sources = [
        "source.amazon-ebs.golden_ami"
    ]

    #setup our custom AMI image
    provisioner "shell" {

      environment_vars = [
        "http_proxy=socks5h://${var.op_username}:${var.op_password}@proxy.saas.vwapps.cloud:8000",
        "https_proxy=socks5h://${var.op_username}:${var.op_password}@proxy.saas.vwapps.cloud:8000",
        "no_proxy=169.254.169.254,.vwgroup.com,.vwg,.internal,.amazonaws.com",
        "environment=${var.environment}",
        "apmaas_vpc_endpoint=${var.apmaas_vpc_endpoint}",
        "dynatrace_tui_cluster_id=${var.dynatrace_tui_cluster_id}",
        "METRICBEAT=1",
        "HEARTBEAT=1"
      ]

      scripts = [
        "../scriptsForPacker/Tools.sh",
        "../scriptsForPacker/Patching.sh",
        "../scriptsForPacker/ActiveGate.sh",
        "../scriptsForPacker/Beats.sh"
        ]

      execute_command = "{{.Vars}} bash '{{.Path}}'"
    }
}

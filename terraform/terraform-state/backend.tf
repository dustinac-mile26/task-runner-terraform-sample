## aws setup.
provider "aws" {
  region = var.region
}

## explicit definitions for replication
provider "aws" {
  alias  = "region-primary"
  region = var.region_primary
}

provider "aws" {
  alias  = "region-replication"
  region = var.region_replication
}

# used to fetch account id and other information
# from the current account context
data "aws_caller_identity" "current" {}

terraform {

  # run this first to set up a new environment
  backend "local" {}

  # migrate to this once the environment has been set up
  # backend "s3" {
  #   key = "myorganization/terraform-state/terraform.tfstate"
  #   region       = "us-west-2"
  #   encrypt      = true
  #   use_lockfile = true
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.3.0, < 7.0.0"
    }
  }

  required_version = ">= 1.14.0"
}

# Terraform State

This Terraform project provides resources to manage [Terraform remote state](https://developer.hashicorp.com/terraform/language/state/remote).

## Table of Contents

1. [Initial Usage](#initial-usage)
1. [Migrating to remote state](#migrating-to-remote-state)

## Initial Usage

1. Source the settings file:

    * `source env/terraform-state/$(DEPLOY_ENV)/settings.sh`

1. Initialize the project:

    * `NO_BUCKET=1 make tf-init`

1. Run the plan and ensure output is as expected:

    * `NO_BUCKET=1 make tf-plan`

1. Run the apply and ensure resources are created as expected:

    * `NO_BUCKET=1 make tf-apply`

## Migrating to remote state

Once the initial run has completed and resources are available, you may migrate this project to use remote state:

1. Edit the [`backend.tf`](backend.tf) file:

    * Comment out the following line:
        
        ```
        backend "local" {}
        ```

    * Uncomment the following lines:

        ```
        backend "s3" {
          key            = "terraform/terraform-state/terraform.tfstate"
          region         = "us-west-2"
          encrypt        = true
        }
        ```

1. Run terraform `init` with the migration parameter:

    * `MIGRATE=1 make tf-init`

1. Check the results:

    * `make tf-plan`

> **_Note:_** once migration is completed, you no longer need the `NO_BUCKET` parameter. You may run all terraform `make` commands directly.
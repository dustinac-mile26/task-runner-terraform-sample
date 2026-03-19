# Terraform State with Bash

This Bash project uses a small CLI wrapper instead of Make-style task names. The main entrypoint is [`./bin/tf`](bin/tf).

## Initial Usage

1. Inspect the resolved context:

   * `./bin/tf context`

1. Initialize the project before the remote backend exists:

   * `./bin/tf init --no-bucket`

1. Run the plan:

   * `./bin/tf plan --no-bucket`

1. Apply the plan:

   * `./bin/tf apply --no-bucket`

The CLI auto-loads `env/<env>/<project>/settings.sh` when it can resolve the environment and project, so you no longer need to `source` the settings file first.

## Migrating To Remote State

Once the initial run has completed and resources are available, you may migrate this project to use remote state:

1. Edit the [`terraform/terraform-state/backend.tf`](terraform/terraform-state/backend.tf) file:

   * Comment out the following line:

     ```hcl
     backend "local" {}
     ```

   * Uncomment the following lines:

     ```hcl
     backend "s3" {
       key            = "myorganization/terraform-state/terraform.tfstate"
       region         = "us-west-2"
       encrypt        = true
       use_lockfile   = true
     }
     ```

1. Run terraform init with the migration flag:

   * `./bin/tf init --migrate`

1. Check the results:

   * `./bin/tf plan`

Once migration is complete, you no longer need `--no-bucket`.

## Native Usage

Run `./bin/tf help` for the full command surface.

Common examples:

* `./bin/tf plan`
* `./bin/tf plan --env production --project terraform-state`
* `./bin/tf plan --target module.example`
* `./bin/tf import aws_s3_bucket.example my-bucket`
* `./bin/tf state list`
* `./bin/tf exec providers schema -json`
# Terraform State with Just

This directory contains two Just variants:

* [`justfile`](justfile): recipe-first Just with a small shell implementation library in [`lib/terraform.sh`](lib/terraform.sh)
* [`justfile.inline`](justfile.inline): a more Make-like Just layout, with most of the workflow written inline in Just recipes and split across Just files with [`import`](https://just.systems/man/en/introduction.html)

## Initial Usage

1. Inspect the active context:

   * `just context`

1. Initialize the project before the remote backend exists:

   * `just bootstrap-init`

1. Run the plan:

   * `just bootstrap-plan`

1. Apply the plan:

   * `just bootstrap-apply`

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

1. Run terraform init with the migration recipe:

   * `just migrate-init`

1. Check the results:

   * `just plan`

Once migration is complete, you no longer need the bootstrap recipes.

## Native Usage

Run `just` or `just help` to see the recipe list for the default, library-backed variant.

To pass flags through to Terraform for recipes like `init`, `plan`, `apply`, `state`, or `exec`, use `--`:

* `just plan -- --target module.example`
* `just init -- --upgrade`
* `just exec -- providers schema -json`

## Inline Justfile Variant

This variant keeps more of the workflow inline in Just recipes and splits the file similarly to the Make example:

* [`justfile.inline`](justfile.inline): general workflow recipes and shared variables
* [`terraform.inline.just`](terraform.inline.just): Terraform recipes written inline

* `just --justfile justfile.inline --list`
* `just --justfile justfile.inline tf-plan`
* `DEPLOY_ENV=production just --justfile justfile.inline tf-apply`
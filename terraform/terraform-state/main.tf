module "metadata" {
  source = "../../../terraform/modules/aws/metadata"

  deploy_env            = var.deploy_env
  maintainer            = "myorg"
  project               = "myorg-terraform-state"
  region                = var.region
  scheduled_destruction = var.scheduled_destruction
}

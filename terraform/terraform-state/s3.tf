module "terraform-state-logging-bucket" {
  source = "../../../terraform/modules/aws/s3_bucket_cross_region"

  tags = module.metadata.tags

  bucket_name = "${module.metadata.tags["Project"]}-${module.metadata.tags["DeployEnv"]}-logging"
  enable_replication = true
  public_block_enabled = true
  sse_algorithm = "AES256"

  # logging a log bucket creates an infinite loop of logs
  # https://aws.amazon.com/premiumsupport/knowledge-center/s3-server-access-logs-same-bucket/
  # TODO: send these to a centralized org account/bucket
  enable_source_bucket_logging = false

  providers = {
    aws             = aws.region-primary
    aws.replication = aws.region-replication
  }

}

module "terraform-state-bucket" {
  source = "../../../terraform/modules/aws/s3_bucket_cross_region"

  tags = module.metadata.tags

  bucket_name          = "${module.metadata.tags["Project"]}-${module.metadata.tags["DeployEnv"]}"
  enable_replication   = var.deploy_env == "production" ? true : false
  public_block_enabled = true
  sse_algorithm        = "AES256"
  bucket_key_enabled   = false

  # enable logging and send them to the logging bucket defined above.
  enable_source_bucket_logging = false
  source_bucket_logging_destination = module.terraform-state-logging-bucket.bucket_name

  providers = {
    aws             = aws.region-primary
    aws.replication = aws.region-replication
  }

  depends_on = [ module.terraform-state-logging-bucket ]

}

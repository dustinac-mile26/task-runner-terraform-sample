PWD=$(shell pwd)

BUCKET := $${TF_REMOTE_STATE_BUCKET_PREFIX}-$(DEPLOY_ENV)

ifdef NO_BUCKET
  BUCKET_STRING :=
else
  BUCKET_STRING := -backend-config="bucket=$(BUCKET)"
endif

ifdef UPGRADE
  UPGRADE := -upgrade
endif

ifdef UPDATE
  UPDATE := -update
endif

ifdef MIGRATE
  MIGRATE := -migrate-state
endif

ifdef TARGET
  TARGET := -target $(TARGET)
endif

tf-check:
	if [ -z ${TF_PROJECT} ]; then echo "Requires TF_PROJECT!"; exit 1; fi

tf-workspace-create: ## Create new terraform workspace
tf-workspace-create: tf-clean
	cd ../terraform/$(TF_PROJECT); \
	  terraform init $(BUCKET_STRING) && \
	  terraform workspace new $(DEPLOY_ENV)

tf-init: ## Initialize terraform
tf-init: tf-check
	cd ../terraform/$(TF_PROJECT); \
	  terraform init $(BUCKET_STRING) $(UPGRADE) $(MIGRATE) && \
	  terraform workspace select -or-create $(DEPLOY_ENV)

tf-plan: ## Run terraform plan
tf-plan: tf-init
	cd ../terraform/$(TF_PROJECT); \
	    terraform plan -out=planfile \
		  -var cli_terraform_remote_state_bucket_prefix=$${TF_REMOTE_STATE_BUCKET_PREFIX} \
		  -var-file="../../env/$(DEPLOY_ENV)/$(TF_PROJECT)/variables.tfvars" $(TARGET) && \
		rm planfile

tf-deplan: ## Run terraform destroy plan
tf-deplan: tf-init
	cd ../terraform/$(TF_PROJECT); \
	  terraform plan -destroy \
		-var cli_terraform_remote_state_bucket_prefix=$${TF_REMOTE_STATE_BUCKET_PREFIX} \
		-var-file="../../env/$(DEPLOY_ENV)/$(TF_PROJECT)/variables.tfvars"

tf-apply: ## Run terraform init, plan and then apply planfile
tf-apply: tf-init
	cd ../terraform/$(TF_PROJECT); \
	  terraform plan -out=planfile \
		-var cli_terraform_remote_state_bucket_prefix=$${TF_REMOTE_STATE_BUCKET_PREFIX} \
		-var-file="../../env/$(DEPLOY_ENV)/$(TF_PROJECT)/variables.tfvars" $(TARGET) && \
	  terraform apply planfile && \
	  rm planfile

tf-import: ## Import terraform resource='' resourceid=''
tf-import: tf-init
	cd ../terraform/$(TF_PROJECT); \
		terraform import \
		  -var cli_terraform_remote_state_bucket_prefix=$${TF_REMOTE_STATE_BUCKET_PREFIX} \
		  -var-file="../../env/$(DEPLOY_ENV)/$(TF_PROJECT)/variables.tfvars" $(resource) $(resourceid)

tf-state: ## Show terraform state
tf-state: tf-init
	cd ../terraform/$(TF_PROJECT); \
		terraform state $(command)

tf-command: ## Run terraform command=''
tf-command: tf-init
	cd ../terraform/$(TF_PROJECT); \
		terraform workspace select $(DEPLOY_ENV) && \
		terraform $(command) $(UPDATE)

tf-destroy: ## Destroy terraform
tf-destroy: tf-init
	@echo "This may DESTROY resources if they already exist! Are you sure? Type 'DESTROY' to confirm:" && read ans && [[ $${ans:-n} != DESTROY ]] && exit 1; \
		cd ../terraform/$(TF_PROJECT); \
		terraform destroy \
		  -var cli_terraform_remote_state_bucket_prefix=$${TF_REMOTE_STATE_BUCKET_PREFIX} \
		  -var-file="../../env/$(DEPLOY_ENV)/$(TF_PROJECT)/variables.tfvars"

tf-clean: ## Clean .terraform directory
	cd ../terraform/$(TF_PROJECT); \
		rm -rf .terraform terraform.tfstate.d
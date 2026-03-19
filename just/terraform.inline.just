# Terraform recipes written inline in Just, closer to the Make example.

tf-check:
  @test -d {{terraform_directory}} || { echo "Terraform project not found: {{terraform_directory}}" >&2; exit 1; }
  @test -f {{variables_file}} || { echo "Variables file not found: {{variables_file}}" >&2; exit 1; }

tf-clean:
  cd {{terraform_directory}} && rm -rf .terraform terraform.tfstate.d

tf-workspace-create: tf-clean tf-check
  cd {{terraform_directory}} && terraform init {{bucket_arg}} && terraform workspace new "{{deploy_env}}"

tf-init: tf-check
  cd {{terraform_directory}} && terraform init {{bucket_arg}} {{upgrade_arg}} {{migrate_arg}} && terraform workspace select -or-create "{{deploy_env}}"

tf-bootstrap-init: tf-check
  cd {{terraform_directory}} && terraform init && terraform workspace select -or-create "{{deploy_env}}"

tf-migrate-init: tf-check
  cd {{terraform_directory}} && terraform init -backend-config="bucket={{bucket_name}}" -migrate-state && terraform workspace select -or-create "{{deploy_env}}"

tf-plan: tf-init
  cd {{terraform_directory}} && terraform plan -out=planfile -var "cli_terraform_remote_state_bucket_prefix={{bucket_prefix}}" -var-file="{{variables_file}}" {{target_arg}} && rm -f planfile

tf-bootstrap-plan: tf-bootstrap-init
  cd {{terraform_directory}} && terraform plan -out=planfile -var "cli_terraform_remote_state_bucket_prefix={{bucket_prefix}}" -var-file="{{variables_file}}" {{target_arg}} && rm -f planfile

tf-deplan: tf-init
  cd {{terraform_directory}} && terraform plan -destroy -var "cli_terraform_remote_state_bucket_prefix={{bucket_prefix}}" -var-file="{{variables_file}}"

tf-apply: tf-init
  cd {{terraform_directory}} && terraform plan -out=planfile -var "cli_terraform_remote_state_bucket_prefix={{bucket_prefix}}" -var-file="{{variables_file}}" {{target_arg}} && terraform apply planfile && rm -f planfile

tf-bootstrap-apply: tf-bootstrap-init
  cd {{terraform_directory}} && terraform plan -out=planfile -var "cli_terraform_remote_state_bucket_prefix={{bucket_prefix}}" -var-file="{{variables_file}}" {{target_arg}} && terraform apply planfile && rm -f planfile

tf-import resource resourceid: tf-init
  cd {{terraform_directory}} && terraform import -var "cli_terraform_remote_state_bucket_prefix={{bucket_prefix}}" -var-file="{{variables_file}}" "{{resource}}" "{{resourceid}}"

tf-state *args: tf-init
  @if [[ $# -eq 0 ]]; then echo "state requires terraform state arguments" >&2; exit 1; fi
  cd {{terraform_directory}} && terraform state "$@"

tf-command *args: tf-init
  @if [[ $# -eq 0 ]]; then echo "command requires terraform arguments" >&2; exit 1; fi
  cd {{terraform_directory}} && terraform workspace select "{{deploy_env}}" && terraform "$@" {{update_arg}}

tf-destroy: tf-init
  @echo "This may DESTROY resources if they already exist! Type 'DESTROY' to confirm:"; read -r answer; if [[ "$${answer:-}" != "DESTROY" ]]; then exit 1; fi; cd {{terraform_directory}} && terraform destroy -var "cli_terraform_remote_state_bucket_prefix={{bucket_prefix}}" -var-file="{{variables_file}}"

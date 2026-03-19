#!/usr/bin/env bash

tf_die() {
  echo "Error: $*" >&2
  exit 1
}

tf_use_context() {
  local requested_env="$1"
  local requested_project="$2"

  TF_ROOT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
  TF_SETTINGS_FILE="${TF_ROOT_PATH}/env/${requested_env}/${requested_project}/settings.sh"

  if [[ -f "${TF_SETTINGS_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${TF_SETTINGS_FILE}"
  fi

  DEPLOY_ENV="${requested_env}"
  TF_PROJECT="${requested_project}"
  TF_BUCKET_PREFIX="${TF_REMOTE_STATE_BUCKET_PREFIX:-}"
  TF_VAR_FILE="${TF_ROOT_PATH}/env/${DEPLOY_ENV}/${TF_PROJECT}/variables.tfvars"
  TF_WORKDIR="${TF_ROOT_PATH}/terraform/${TF_PROJECT}"

  [[ -d "${TF_WORKDIR}" ]] || tf_die "Terraform project not found: ${TF_WORKDIR}"
  [[ -f "${TF_VAR_FILE}" ]] || tf_die "Variables file not found: ${TF_VAR_FILE}"
}

tf_require_terraform() {
  command -v terraform >/dev/null 2>&1 || tf_die "terraform not found in PATH"
}

tf_print_context() {
  cat <<EOF
env:          ${DEPLOY_ENV}
project:      ${TF_PROJECT}
root:         ${TF_ROOT_PATH}
terraform:    ${TF_WORKDIR}
variables:    ${TF_VAR_FILE}
settings:     ${TF_SETTINGS_FILE}
bucket-prefix:${TF_BUCKET_PREFIX:-<empty>}
EOF
}

tf_build_backend_args() {
  local init_mode="$1"

  TF_BACKEND_ARGS=()

  case "${init_mode}" in
    standard)
      TF_BACKEND_ARGS+=("-backend-config=bucket=${TF_BUCKET_PREFIX}-${DEPLOY_ENV}")
      ;;
    bootstrap)
      ;;
    migrate)
      TF_BACKEND_ARGS+=("-backend-config=bucket=${TF_BUCKET_PREFIX}-${DEPLOY_ENV}")
      TF_BACKEND_ARGS+=("-migrate-state")
      ;;
    *)
      tf_die "Unknown terraform init mode: ${init_mode}"
      ;;
  esac
}

tf_build_var_args() {
  TF_VAR_ARGS=(
    "-var"
    "cli_terraform_remote_state_bucket_prefix=${TF_BUCKET_PREFIX}"
    "-var-file=${TF_VAR_FILE}"
  )
}

tf_run_init() {
  local init_mode="$1"

  if [[ $# -gt 0 ]]; then
    shift
  fi

  tf_require_terraform
  tf_build_backend_args "${init_mode}"

  (
    cd "${TF_WORKDIR}" || exit
    terraform init "${TF_BACKEND_ARGS[@]}" "$@"
    terraform workspace select -or-create "${DEPLOY_ENV}"
  )
}

tf_init() {
  tf_run_init standard "$@"
}

tf_bootstrap_init() {
  tf_run_init bootstrap "$@"
}

tf_migrate_init() {
  tf_run_init migrate "$@"
}

tf_workspace_create() {
  tf_require_terraform
  tf_build_backend_args standard

  (
    cd "${TF_WORKDIR}" || exit
    rm -rf .terraform terraform.tfstate.d
    terraform init "${TF_BACKEND_ARGS[@]}" "$@"
    terraform workspace new "${DEPLOY_ENV}"
  )
}

tf_run_plan() {
  local init_mode="$1"

  if [[ $# -gt 0 ]]; then
    shift
  fi

  tf_run_init "${init_mode}"
  tf_build_var_args

  (
    cd "${TF_WORKDIR}" || exit
    trap 'rm -f planfile' EXIT
    terraform plan -out=planfile "${TF_VAR_ARGS[@]}" "$@"
  )
}

tf_plan() {
  tf_run_plan standard "$@"
}

tf_bootstrap_plan() {
  tf_run_plan bootstrap "$@"
}

tf_deplan() {
  tf_run_init standard
  tf_build_var_args

  (
    cd "${TF_WORKDIR}" || exit
    terraform plan -destroy "${TF_VAR_ARGS[@]}" "$@"
  )
}

tf_run_apply() {
  local init_mode="$1"

  if [[ $# -gt 0 ]]; then
    shift
  fi

  tf_run_init "${init_mode}"
  tf_build_var_args

  (
    cd "${TF_WORKDIR}" || exit
    trap 'rm -f planfile' EXIT
    terraform plan -out=planfile "${TF_VAR_ARGS[@]}" "$@"
    terraform apply planfile
  )
}

tf_apply() {
  tf_run_apply standard "$@"
}

tf_bootstrap_apply() {
  tf_run_apply bootstrap "$@"
}

tf_import() {
  local resource="$1"
  local resource_id="$2"

  [[ -n "${resource}" ]] || tf_die "import requires <resource> <resource-id>"
  [[ -n "${resource_id}" ]] || tf_die "import requires <resource> <resource-id>"

  tf_run_init standard
  tf_build_var_args

  (
    cd "${TF_WORKDIR}" || exit
    terraform import "${TF_VAR_ARGS[@]}" "${resource}" "${resource_id}"
  )
}

tf_state() {
  [[ "$#" -gt 0 ]] || tf_die "state requires terraform state arguments"

  tf_run_init standard

  (
    cd "${TF_WORKDIR}" || exit
    terraform state "$@"
  )
}

tf_exec() {
  [[ "$#" -gt 0 ]] || tf_die "exec requires terraform arguments"

  tf_run_init standard

  (
    cd "${TF_WORKDIR}" || exit
    terraform workspace select "${DEPLOY_ENV}"
    terraform "$@"
  )
}

tf_destroy() {
  local answer

  tf_run_init standard
  tf_build_var_args

  echo "This may DESTROY resources if they already exist! Type 'DESTROY' to confirm:"
  read -r answer
  [[ "${answer:-}" == "DESTROY" ]] || exit 1

  (
    cd "${TF_WORKDIR}" || exit
    terraform destroy "${TF_VAR_ARGS[@]}" "$@"
  )
}

tf_clean() {
  (
    cd "${TF_WORKDIR}" || exit
    rm -rf .terraform terraform.tfstate.d
  )
}

#!/usr/bin/env bash

tf_init_runtime() {
  TF_ROOT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
  TF_DEFAULT_ENV="${DEPLOY_ENV:-development}"
  TF_DEFAULT_PROJECT="${TF_PROJECT:-}"
  TF_EXPLICIT_ENV=""
  TF_EXPLICIT_PROJECT=""
  TF_EXPLICIT_SETTINGS=""
  TF_EXPLICIT_VAR_FILE=""
  TF_BUCKET_PREFIX="${TF_REMOTE_STATE_BUCKET_PREFIX:-}"
  TF_NO_BUCKET="false"
  TF_UPGRADE="false"
  TF_MIGRATE="false"
  TF_UPDATE="false"
  TF_COMMAND="help"
  TF_CONTEXT_READY="false"
  TF_FORWARD_ARGS=()
  TF_TARGETS=()
  TF_SETTINGS_FILE=""
  TF_VAR_FILE=""
  TF_WORKDIR=""
}

tf_die() {
  echo "Error: $*" >&2
  exit 1
}

tf_require_value() {
  local flag="$1"
  local value="${2:-}"

  [[ -n "${value}" ]] || tf_die "${flag} requires a value"
  printf '%s\n' "${value}"
}

tf_scan_context_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --)
        break
        ;;
      --env)
        TF_EXPLICIT_ENV="$(tf_require_value "$1" "${2:-}")"
        shift 2
        ;;
      --project)
        TF_EXPLICIT_PROJECT="$(tf_require_value "$1" "${2:-}")"
        shift 2
        ;;
      --settings)
        TF_EXPLICIT_SETTINGS="$(tf_require_value "$1" "${2:-}")"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
}

tf_parse_args() {
  TF_COMMAND="${1:-help}"

  if [[ "${TF_COMMAND}" == "-h" || "${TF_COMMAND}" == "--help" ]]; then
    TF_COMMAND="help"
    return 0
  fi

  if [[ $# -gt 0 ]]; then
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env)
        TF_EXPLICIT_ENV="$(tf_require_value "$1" "${2:-}")"
        shift 2
        ;;
      --project)
        TF_EXPLICIT_PROJECT="$(tf_require_value "$1" "${2:-}")"
        shift 2
        ;;
      --settings)
        TF_EXPLICIT_SETTINGS="$(tf_require_value "$1" "${2:-}")"
        shift 2
        ;;
      --var-file)
        TF_EXPLICIT_VAR_FILE="$(tf_require_value "$1" "${2:-}")"
        shift 2
        ;;
      --prefix)
        TF_BUCKET_PREFIX="$(tf_require_value "$1" "${2:-}")"
        shift 2
        ;;
      --target)
        TF_TARGETS+=("$(tf_require_value "$1" "${2:-}")")
        shift 2
        ;;
      --no-bucket)
        TF_NO_BUCKET="true"
        shift
        ;;
      --upgrade)
        TF_UPGRADE="true"
        shift
        ;;
      --migrate)
        TF_MIGRATE="true"
        shift
        ;;
      --update)
        TF_UPDATE="true"
        shift
        ;;
      --help|-h)
        TF_COMMAND="help"
        shift
        ;;
      --)
        shift
        TF_FORWARD_ARGS+=("$@")
        break
        ;;
      *)
        TF_FORWARD_ARGS+=("$1")
        shift
        ;;
    esac
  done
}

tf_discover_project() {
  local env_name="$1"
  local env_dir="${TF_ROOT_PATH}/env/${env_name}"
  local -a projects=()
  local path

  [[ -d "${env_dir}" ]] || return 0

  while IFS= read -r path; do
    projects+=("$(basename "${path}")")
  done < <(find "${env_dir}" -mindepth 1 -maxdepth 1 -type d | sort)

  if [[ "${#projects[@]}" -eq 1 ]]; then
    printf '%s\n' "${projects[0]}"
    return 0
  fi

  if [[ "${#projects[@]}" -gt 1 ]]; then
    tf_die "Multiple projects found under ${env_dir}; pass --project"
  fi
}

tf_source_settings() {
  local settings_file="$1"

  if [[ -n "${settings_file}" && -f "${settings_file}" ]]; then
    # shellcheck disable=SC1090
    source "${settings_file}"
  fi
}

tf_resolve_context() {
  local env_hint project_hint settings_hint

  if [[ "${TF_CONTEXT_READY}" == "true" ]]; then
    return 0
  fi

  env_hint="${TF_EXPLICIT_ENV:-${TF_DEFAULT_ENV}}"
  project_hint="${TF_EXPLICIT_PROJECT:-${TF_DEFAULT_PROJECT}}"

  if [[ -z "${project_hint}" ]]; then
    project_hint="$(tf_discover_project "${env_hint}")"
  fi

  if [[ -n "${TF_EXPLICIT_SETTINGS}" ]]; then
    settings_hint="${TF_EXPLICIT_SETTINGS}"
  elif [[ -n "${project_hint}" ]]; then
    settings_hint="${TF_ROOT_PATH}/env/${env_hint}/${project_hint}/settings.sh"
  else
    settings_hint=""
  fi

  tf_source_settings "${settings_hint}"

  DEPLOY_ENV="${TF_EXPLICIT_ENV:-${DEPLOY_ENV:-${env_hint}}}"
  TF_PROJECT="${TF_EXPLICIT_PROJECT:-${TF_PROJECT:-${project_hint}}}"

  [[ -n "${DEPLOY_ENV}" ]] || tf_die "DEPLOY_ENV not set"
  [[ -n "${TF_PROJECT}" ]] || tf_die "TF_PROJECT not set; pass --project or add a settings file"

  TF_SETTINGS_FILE="${TF_EXPLICIT_SETTINGS:-${TF_ROOT_PATH}/env/${DEPLOY_ENV}/${TF_PROJECT}/settings.sh}"
  TF_VAR_FILE="${TF_EXPLICIT_VAR_FILE:-${TF_ROOT_PATH}/env/${DEPLOY_ENV}/${TF_PROJECT}/variables.tfvars}"
  TF_WORKDIR="${TF_ROOT_PATH}/terraform/${TF_PROJECT}"
  TF_CONTEXT_READY="true"
}

tf_require_context() {
  tf_resolve_context

  [[ -d "${TF_WORKDIR}" ]] || tf_die "Terraform project not found: ${TF_WORKDIR}"
  [[ -f "${TF_VAR_FILE}" ]] || tf_die "Variables file not found: ${TF_VAR_FILE}"
}

tf_require_terraform() {
  command -v terraform >/dev/null 2>&1 || tf_die "terraform not found in PATH"
}

tf_build_backend_args() {
  TF_BACKEND_ARGS=()

  if [[ "${TF_NO_BUCKET}" != "true" ]]; then
    TF_BACKEND_ARGS+=("-backend-config=bucket=${TF_BUCKET_PREFIX}-${DEPLOY_ENV}")
  fi

  if [[ "${TF_UPGRADE}" == "true" ]]; then
    TF_BACKEND_ARGS+=("-upgrade")
  fi

  if [[ "${TF_MIGRATE}" == "true" ]]; then
    TF_BACKEND_ARGS+=("-migrate-state")
  fi
}

tf_build_var_args() {
  TF_VAR_ARGS=(
    "-var"
    "cli_terraform_remote_state_bucket_prefix=${TF_BUCKET_PREFIX}"
    "-var-file=${TF_VAR_FILE}"
  )
}

tf_build_target_args() {
  TF_TARGET_ARGS=()

  if [[ "${#TF_TARGETS[@]}" -gt 0 ]]; then
    local target
    for target in "${TF_TARGETS[@]}"; do
      TF_TARGET_ARGS+=("-target" "${target}")
    done
  fi
}

tf_build_update_args() {
  TF_UPDATE_ARGS=()

  if [[ "${TF_UPDATE}" == "true" ]]; then
    TF_UPDATE_ARGS+=("-update")
  fi
}

tf_print_help() {
  cat <<'EOF'
Usage:
  ./bin/tf <command> [options] [args...]

Commands:
  context           Show the resolved terraform context
  workspace-create  Create a workspace after init
  init              Initialize terraform and select the workspace
  plan              Run terraform plan
  deplan            Run terraform plan -destroy
  apply             Run terraform plan and apply the saved plan
  destroy           Run terraform destroy after confirmation
  import            Import a resource into state
  state             Run terraform state <args...>
  exec              Run terraform <args...> in the selected workspace
  clean             Remove .terraform and terraform.tfstate.d
  help              Print this help

Common options:
  --env <name>        Deployment environment. Defaults to DEPLOY_ENV or development.
  --project <name>    Terraform project directory under terraform/.
  --settings <path>   Settings file to source before resolving context.
  --var-file <path>   Override the tfvars file path.
  --prefix <value>    Override TF_REMOTE_STATE_BUCKET_PREFIX.

Terraform options:
  --no-bucket         Skip remote backend bucket config during init.
  --upgrade           Pass -upgrade to terraform init.
  --migrate           Pass -migrate-state to terraform init.
  --target <addr>     Add a terraform -target argument. Repeatable.
  --update            Pass -update to `exec`.

Examples:
  ./bin/tf init --no-bucket
  ./bin/tf plan --target module.example
  ./bin/tf apply --env development --project terraform-state --no-bucket
  ./bin/tf import aws_s3_bucket.example my-bucket
  ./bin/tf state list
  ./bin/tf exec providers schema -json
EOF
}

tf_context() {
  tf_resolve_context

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

tf_workspace_create() {
  tf_require_context
  tf_require_terraform
  tf_build_backend_args

  (
    cd "${TF_WORKDIR}" || exit
    rm -rf .terraform terraform.tfstate.d
    terraform init "${TF_BACKEND_ARGS[@]}"
    terraform workspace new "${DEPLOY_ENV}"
  )
}

tf_init() {
  tf_require_context
  tf_require_terraform
  tf_build_backend_args

  (
    cd "${TF_WORKDIR}" || exit
    terraform init "${TF_BACKEND_ARGS[@]}"
    terraform workspace select -or-create "${DEPLOY_ENV}"
  )
}

tf_plan() {
  tf_init
  tf_build_var_args
  tf_build_target_args

  (
    cd "${TF_WORKDIR}" || exit
    trap 'rm -f planfile' EXIT
    terraform plan -out=planfile "${TF_VAR_ARGS[@]}" "${TF_TARGET_ARGS[@]}" "${TF_FORWARD_ARGS[@]}"
  )
}

tf_deplan() {
  tf_init
  tf_build_var_args

  (
    cd "${TF_WORKDIR}" || exit
    terraform plan -destroy "${TF_VAR_ARGS[@]}" "${TF_FORWARD_ARGS[@]}"
  )
}

tf_apply() {
  tf_init
  tf_build_var_args
  tf_build_target_args

  (
    cd "${TF_WORKDIR}" || exit
    trap 'rm -f planfile' EXIT
    terraform plan -out=planfile "${TF_VAR_ARGS[@]}" "${TF_TARGET_ARGS[@]}" "${TF_FORWARD_ARGS[@]}"
    terraform apply planfile
  )
}

tf_import() {
  local resource="${TF_FORWARD_ARGS[0]:-}"
  local resource_id="${TF_FORWARD_ARGS[1]:-}"

  [[ -n "${resource}" ]] || tf_die "import requires <resource> <resource-id>"
  [[ -n "${resource_id}" ]] || tf_die "import requires <resource> <resource-id>"

  tf_init
  tf_build_var_args

  (
    cd "${TF_WORKDIR}" || exit
    terraform import "${TF_VAR_ARGS[@]}" "${resource}" "${resource_id}"
  )
}

tf_state() {
  [[ "${#TF_FORWARD_ARGS[@]}" -gt 0 ]] || tf_die "state requires terraform state arguments"

  tf_init

  (
    cd "${TF_WORKDIR}" || exit
    terraform state "${TF_FORWARD_ARGS[@]}"
  )
}

tf_exec() {
  [[ "${#TF_FORWARD_ARGS[@]}" -gt 0 ]] || tf_die "exec requires terraform arguments"

  tf_init
  tf_build_update_args

  (
    cd "${TF_WORKDIR}" || exit
    terraform workspace select "${DEPLOY_ENV}"
    terraform "${TF_FORWARD_ARGS[@]}" "${TF_UPDATE_ARGS[@]}"
  )
}

tf_destroy() {
  local answer

  tf_init
  tf_build_var_args

  echo "This may DESTROY resources if they already exist! Type 'DESTROY' to confirm:"
  read -r answer
  [[ "${answer:-}" == "DESTROY" ]] || exit 1

  (
    cd "${TF_WORKDIR}" || exit
    terraform destroy "${TF_VAR_ARGS[@]}" "${TF_FORWARD_ARGS[@]}"
  )
}

tf_clean() {
  tf_require_context

  (
    cd "${TF_WORKDIR}" || exit
    rm -rf .terraform terraform.tfstate.d
  )
}

tf_main() {
  tf_init_runtime
  tf_scan_context_args "$@"
  tf_parse_args "$@"

  case "${TF_COMMAND}" in
    context) tf_context ;;
    workspace-create) tf_workspace_create ;;
    init) tf_init ;;
    plan) tf_plan ;;
    deplan) tf_deplan ;;
    apply) tf_apply ;;
    import) tf_import ;;
    state) tf_state ;;
    exec) tf_exec ;;
    destroy) tf_destroy ;;
    clean) tf_clean ;;
    help) tf_print_help ;;
    *) tf_die "Unknown command: ${TF_COMMAND}" ;;
  esac
}

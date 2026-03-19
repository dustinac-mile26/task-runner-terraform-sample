#!/usr/bin/env bash
set -euo pipefail

PROJECT="myorganization"
ROOT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TF_BIN="${ROOT_PATH}/bin/tf"

die() {
  echo "Error: $*" >&2
  exit 1
}

build_directory() {
  printf '/tmp/%s.%s.build\n' "${PROJECT}" "${DEPLOY_ENV:-development}"
}

temp_root_file() {
  printf '%s/temp_root\n' "$(build_directory)"
}

terraform_var_file() {
  printf '%s/env/%s/%s/variables.tfvars\n' "${ROOT_PATH}" "${DEPLOY_ENV}" "${TF_PROJECT}"
}

split_words() {
  local raw="$1"
  SPLIT_WORDS=()

  if [[ -z "${raw}" ]]; then
    return 0
  fi

  read -r -a SPLIT_WORDS <<< "${raw}"
}

build_context_args() {
  CONTEXT_ARGS=()
  local var_file=""

  if [[ -n "${DEPLOY_ENV:-}" ]]; then
    CONTEXT_ARGS+=(--env "${DEPLOY_ENV}")
  fi

  if [[ -n "${TF_PROJECT:-}" ]]; then
    CONTEXT_ARGS+=(--project "${TF_PROJECT}")
  fi

  if [[ -n "${TF_REMOTE_STATE_BUCKET_PREFIX:-}" ]]; then
    CONTEXT_ARGS+=(--prefix "${TF_REMOTE_STATE_BUCKET_PREFIX}")
  fi

  if [[ -n "${DEPLOY_ENV:-}" && -n "${TF_PROJECT:-}" ]]; then
    var_file="$(terraform_var_file)"

    if [[ -f "${var_file}" ]]; then
      CONTEXT_ARGS+=(--var-file "${var_file}")
    fi
  fi
}

build_flow_args() {
  FLOW_ARGS=()

  if [[ -n "${NO_BUCKET:-}" ]]; then
    FLOW_ARGS+=(--no-bucket)
  fi

  if [[ -n "${UPGRADE:-}" ]]; then
    FLOW_ARGS+=(--upgrade)
  fi

  if [[ -n "${MIGRATE:-}" ]]; then
    FLOW_ARGS+=(--migrate)
  fi

  if [[ -n "${UPDATE:-}" ]]; then
    FLOW_ARGS+=(--update)
  fi

  if [[ -n "${TARGET:-}" ]]; then
    FLOW_ARGS+=(--target "${TARGET}")
  fi
}

legacy_help() {
  cat <<'EOF'
Legacy wrapper for the newer Bash CLI.

Native interface:
  ./bin/tf <command> [options]

Legacy tasks still supported:
  help
  clean
  temp-create
  temp-delete
  check
  env-check
  tf-check
  tf-workspace-create
  tf-init
  tf-plan
  tf-deplan
  tf-apply
  tf-import
  tf-state
  tf-command
  tf-destroy
  tf-clean
EOF
}

legacy_temp_create() {
  local build_dir temp_root

  build_dir="$(build_directory)"
  mkdir -p "${build_dir}"
  temp_root="$(umask 077 && mktemp -d "/tmp/${PROJECT}.${DEPLOY_ENV:-development}.XXXXXXXX")"
  printf '%s\n' "${temp_root}" > "$(temp_root_file)"
  echo "Using temp directory: ${temp_root}"
}

legacy_temp_delete() {
  local recorded_temp_root

  if [[ -f "$(temp_root_file)" ]]; then
    read -r recorded_temp_root < "$(temp_root_file)"
    rm -rfv "${recorded_temp_root}"
    rm -f "$(temp_root_file)"
    return 0
  fi

  if [[ -n "${TEMP_ROOT:-}" ]]; then
    rm -rfv "${TEMP_ROOT}"
    return 0
  fi

  die "No temp directory recorded. Run temp-create first or set TEMP_ROOT."
}

legacy_check() {
  local answer

  if [[ -n "${FORCE:-}" ]]; then
    echo "Forcing..."
    return 0
  fi

  echo "Are you sure? [NO/yes]:"
  read -r answer

  [[ "${answer}" == "yes" ]] || die "Must answer 'yes' to proceed."
}

legacy_env_check() {
  build_context_args
  "${TF_BIN}" context "${CONTEXT_ARGS[@]}"
  echo "Sleeping 2s before continuing... Control-C now to abort!"
  sleep 2
}

run_tf() {
  local command="$1"
  if [[ $# -gt 0 ]]; then
    shift
  fi

  build_context_args
  build_flow_args
  "${TF_BIN}" "${command}" "${CONTEXT_ARGS[@]}" "${FLOW_ARGS[@]}" "$@"
}

main() {
  local task="${1:-help}"

  if [[ $# -gt 0 ]]; then
    shift
  fi

  case "${task}" in
    help) legacy_help ;;
    clean) rm -rf "$(build_directory)" ;;
    temp-create) legacy_temp_create ;;
    temp-delete) legacy_temp_delete ;;
    check) legacy_check ;;
    env-check) legacy_env_check ;;
    tf-check) build_context_args; "${TF_BIN}" context "${CONTEXT_ARGS[@]}" >/dev/null ;;
    tf-workspace-create) run_tf workspace-create "$@" ;;
    tf-init) run_tf init "$@" ;;
    tf-plan) run_tf plan "$@" ;;
    tf-deplan) run_tf deplan "$@" ;;
    tf-apply) run_tf apply "$@" ;;
    tf-import)
      if [[ $# -eq 0 && -n "${resource:-}" ]]; then
        set -- "${resource}" "${resourceid:-}"
      fi
      run_tf import "$@"
      ;;
    tf-state)
      if [[ $# -eq 0 && -n "${command:-}" ]]; then
        split_words "${command}"
        set -- "${SPLIT_WORDS[@]}"
      fi
      run_tf state "$@"
      ;;
    tf-command)
      if [[ $# -eq 0 && -n "${command:-}" ]]; then
        split_words "${command}"
        set -- "${SPLIT_WORDS[@]}"
      fi
      run_tf exec "$@"
      ;;
    tf-destroy) run_tf destroy "$@" ;;
    tf-clean) run_tf clean "$@" ;;
    *) die "Unknown task: ${task}" ;;
  esac
}

main "$@"

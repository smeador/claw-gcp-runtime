#!/bin/bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 ENV ACTION [CONFIG_PATH|JOB_NAME]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/runtime-common.sh"

ENV_NAME="$1"
ACTION="$2"
ARG="${3:-}"

runtime_init_env "${ENV_NAME}"

cron_list() {
  runtime_wait_for_gateway
  runtime_gateway_exec openclaw cron list --all
}

cron_run() {
  local job_name="${1:-newsletter-digest-morning}"
  local job_id

  runtime_wait_for_gateway

  job_id="$(
    runtime_gateway_exec openclaw cron list --all --json \
      | jq -r --arg name "${job_name}" '.jobs[] | select(.name == $name) | .id' \
      | head -n 1
  )"

  if [ -z "${job_id}" ]; then
    echo "${RUNTIME_LABEL} cron job not found: ${job_name}" >&2
    exit 1
  fi

  runtime_gateway_exec openclaw cron run "${job_id}"
}

cron_apply() {
  local config_path="${1:-${RUNTIME_DEFAULT_CRON_FILE}}"
  local current_jobs_file
  local job_count

  if [ ! -f "${config_path}" ]; then
    echo "Cron config not found: ${config_path}" >&2
    exit 1
  fi

  current_jobs_file="$(mktemp)"
  trap 'rm -f "${current_jobs_file:-}"' EXIT

  runtime_wait_for_gateway
  runtime_gateway_exec openclaw cron list --all --json > "${current_jobs_file}"

  job_count="$(jq '.jobs | length' "${config_path}")"

  for ((i = 0; i < job_count; i += 1)); do
    job="$(jq -c ".jobs[${i}]" "${config_path}")"
    name="$(jq -r '.name' <<< "${job}")"
    description="$(jq -r '.description // empty' <<< "${job}")"
    agent="$(jq -r '.agent // empty' <<< "${job}")"
    cron_expr="$(jq -r '.cron // empty' <<< "${job}")"
    tz="$(jq -r '.tz // empty' <<< "${job}")"
    session="$(jq -r '.session // empty' <<< "${job}")"
    message="$(jq -r '.message // empty' <<< "${job}")"
    system_event="$(jq -r '.systemEvent // empty' <<< "${job}")"
    exact="$(jq -r '.exact // false' <<< "${job}")"
    deliver="$(jq -r '.deliver // false' <<< "${job}")"
    disabled="$(jq -r '.disabled // false' <<< "${job}")"
    mapfile -t replaced_names < <(jq -r '.replaces[]? // empty' <<< "${job}")

    mapfile -t matching_ids < <(
      jq -r --arg name "${name}" '
        .. | objects | select(has("id") and has("name") and .name == $name) | .id
      ' "${current_jobs_file}"
    )

    primary_id=""
    if [ "${#matching_ids[@]}" -gt 0 ]; then
      primary_id="${matching_ids[0]}"
    fi

    if [ "${#matching_ids[@]}" -gt 1 ]; then
      for duplicate_id in "${matching_ids[@]:1}"; do
        runtime_gateway_exec openclaw cron rm "${duplicate_id}" >/dev/null
      done
    fi

    for replaced_name in "${replaced_names[@]}"; do
      if [ -z "${replaced_name}" ]; then
        continue
      fi
      mapfile -t replaced_ids < <(
        jq -r --arg name "${replaced_name}" '
          .. | objects | select(has("id") and has("name") and .name == $name) | .id
        ' "${current_jobs_file}"
      )
      for replaced_id in "${replaced_ids[@]}"; do
        runtime_gateway_exec openclaw cron rm "${replaced_id}" >/dev/null
      done
    done

    base_args=()
    if [ -n "${name}" ]; then
      base_args+=(--name "${name}")
    fi
    if [ -n "${description}" ]; then
      base_args+=(--description "${description}")
    fi
    if [ -n "${agent}" ]; then
      base_args+=(--agent "${agent}")
    fi
    if [ -n "${cron_expr}" ]; then
      base_args+=(--cron "${cron_expr}")
    fi
    if [ -n "${tz}" ]; then
      base_args+=(--tz "${tz}")
    fi
    if [ -n "${session}" ]; then
      base_args+=(--session "${session}")
    fi
    if [ -n "${system_event}" ]; then
      base_args+=(--system-event "${system_event}")
    elif [ -n "${message}" ]; then
      base_args+=(--message "${message}")
    fi
    if [ "${exact}" = "true" ]; then
      base_args+=(--exact)
    fi
    if [ "${session}" = "isolated" ]; then
      if [ "${deliver}" = "false" ]; then
        base_args+=(--no-deliver)
      else
        base_args+=(--announce)
      fi
    fi

    if [ -z "${primary_id}" ]; then
      add_args=("${base_args[@]}")
      if [ "${disabled}" = "true" ]; then
        add_args+=(--disabled)
      fi
      runtime_gateway_exec openclaw cron add "${add_args[@]}" >/dev/null
    else
      edit_args=("${base_args[@]}")
      if [ "${disabled}" = "true" ]; then
        edit_args+=(--disable)
      else
        edit_args+=(--enable)
      fi
      if ! runtime_gateway_exec openclaw cron edit "${primary_id}" "${edit_args[@]}" >/dev/null; then
        runtime_gateway_exec openclaw cron rm "${primary_id}" >/dev/null
        add_args=("${base_args[@]}")
        if [ "${disabled}" = "true" ]; then
          add_args+=(--disabled)
        fi
        runtime_gateway_exec openclaw cron add "${add_args[@]}" >/dev/null
      fi
    fi
  done

  cron_list
}

case "${ACTION}" in
  apply)
    cron_apply "${ARG}"
    ;;
  list)
    cron_list
    ;;
  run)
    cron_run "${ARG}"
    ;;
  *)
    echo "Unknown runtime cron action: ${ACTION}" >&2
    exit 1
    ;;
esac

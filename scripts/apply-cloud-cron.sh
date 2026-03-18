#!/bin/bash
set -euo pipefail

CONFIG_PATH="${1:-config/cron.cloud.json}"

if [ ! -f "${CONFIG_PATH}" ]; then
  echo "Cron config not found: ${CONFIG_PATH}" >&2
  exit 1
fi

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    docker compose --env-file config/docker.build.env "$@"
  else
    docker-compose --env-file config/docker.build.env "$@"
  fi
}

APP_ROOT="${OPENCLAW_APP_ROOT:-/opt/openclaw/app}"
cd "${APP_ROOT}"

current_jobs_file="$(mktemp)"
trap 'rm -f "${current_jobs_file}"' EXIT

compose_cmd -f docker/compose.cloud.yml exec -T openclaw-gateway \
  openclaw cron list --all --json > "${current_jobs_file}"

job_count="$(jq '.jobs | length' "${CONFIG_PATH}")"

for ((i = 0; i < job_count; i += 1)); do
  job="$(jq -c ".jobs[${i}]" "${CONFIG_PATH}")"
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
      compose_cmd -f docker/compose.cloud.yml exec -T openclaw-gateway \
        openclaw cron rm "${duplicate_id}" >/dev/null
    done
  fi

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
    compose_cmd -f docker/compose.cloud.yml exec -T openclaw-gateway \
      openclaw cron add "${add_args[@]}" >/dev/null
  else
    edit_args=("${base_args[@]}")
    if [ "${disabled}" = "true" ]; then
      edit_args+=(--disable)
    else
      edit_args+=(--enable)
    fi
    if ! compose_cmd -f docker/compose.cloud.yml exec -T openclaw-gateway \
      openclaw cron edit "${primary_id}" "${edit_args[@]}" >/dev/null; then
      compose_cmd -f docker/compose.cloud.yml exec -T openclaw-gateway \
        openclaw cron rm "${primary_id}" >/dev/null
      add_args=("${base_args[@]}")
      if [ "${disabled}" = "true" ]; then
        add_args+=(--disabled)
      fi
      compose_cmd -f docker/compose.cloud.yml exec -T openclaw-gateway \
        openclaw cron add "${add_args[@]}" >/dev/null
    fi
  fi
done

compose_cmd -f docker/compose.cloud.yml exec -T openclaw-gateway \
  openclaw cron list --all

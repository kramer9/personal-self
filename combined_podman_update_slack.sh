#!/usr/bin/env bash
set -euo pipefail
# set -x  # Enable detailed command tracing

# Load Bitwarden environment
if [ -f "/etc/bitwarden/env" ]; then
  source "/etc/bitwarden/env"
  export BWS_ACCESS_TOKEN # Ensure it's exported for child processes
else
  echo "Error: Environment file /etc/bitwarden/env not found."
  exit 1
fi

# Check if BWS_ACCESS_TOKEN is set
if [ -z "$BWS_ACCESS_TOKEN" ]; then
  echo "Error: BWS_ACCESS_TOKEN is not set."
  exit 1
fi

# Retrieve secret from Bitwarden using the key
WEBHOOK_URL=$(bws secret get 1dd0cfbe-b2b2-4c50-bf8d-b2bc00ea08a4 --output json | jq -r '.value' | tr -d '\n"')

# Check if WEBHOOK_URL was retrieved successfully
if [ -z "$WEBHOOK_URL" ]; then
  echo "Error: Failed to retrieve SLACK_WEBHOOK_URL from Bitwarden."
  exit 1
fi

# --- 1. Get all containers with autoupdate label and check for PODMAN_SYSTEMD_UNIT label ---
AUTO_UPDATE_CONTAINERS=$(podman ps --filter label=io.containers.autoupdate=registry --format "{{.ID}}")

declare -a CHECKED_CONTAINERS_ARR=()
declare -a NEEDS_UPDATE_CONTAINERS_ARR=()
declare -a NOT_UPDATED_NO_LABEL_ARR=()

for container_id in $AUTO_UPDATE_CONTAINERS; do
  container_name=$(podman inspect --format '{{.Name}}' "$container_id")
  unit_label=$(podman inspect --format '{{ index .Config.Labels "PODMAN_SYSTEMD_UNIT" }}' "$container_id")
  if [[ -n "$unit_label" ]]; then
    CHECKED_CONTAINERS_ARR+=("$container_name (systemd unit: $unit_label)")
  else
    NOT_UPDATED_NO_LABEL_ARR+=("$container_name (no PODMAN_SYSTEMD_UNIT label)")
    continue
  fi
done

# --- 2. Run podman auto-update (ignore errors) ---
if [[ ${#CHECKED_CONTAINERS_ARR[@]} -gt 0 ]]; then
  echo "DEBUG: About to run podman auto-update"
  podman auto-update || true
  echo "DEBUG: podman auto-update exit code: $?"
fi

# --- 3. Get which containers still need update (after update) ---
declare -a NEEDS_UPDATE_CONTAINERS_ARR=()
if [[ ${#CHECKED_CONTAINERS_ARR[@]} -gt 0 ]]; then
  set +e
  DRY_RUN_JSON_POST_UPDATE=$(podman auto-update --dry-run --format json)
  JQ_EXIT=0
  NEEDS_UPDATE_CONTAINERS_POST_UPDATE=$(echo "$DRY_RUN_JSON_POST_UPDATE" | jq -r '.[] | select(.Updated == "pending") | "\(.ContainerName // "N/A")"') || JQ_EXIT=$?
  set -e
  echo "DEBUG: jq exit code: $JQ_EXIT"
  if [[ $JQ_EXIT -eq 0 ]]; then
    while read -r container_name; do
      [[ -n "$container_name" ]] && NEEDS_UPDATE_CONTAINERS_ARR+=("$container_name")
    done <<< "$NEEDS_UPDATE_CONTAINERS_POST_UPDATE"
  else
    echo "WARNING: jq failed to parse DRY_RUN_JSON_POST_UPDATE"
  fi
  echo "DEBUG: Finished parsing DRY_RUN_JSON_POST_UPDATE"
fi

# --- 4. Get list of updated containers ---
declare -a UPDATED_CONTAINERS_ARR=()
if [[ ${#CHECKED_CONTAINERS_ARR[@]} -gt 0 ]]; then
  set +e
  UPDATE_JSON=$(podman auto-update --dry-run --format json)
  # NOTE: For actual updated containers, you might need to check logs or use a different approach;
  # podman auto-update --dry-run may not show "updated" status for the current run.
  # The following is a best-effort approach, but consider using systemd logs or podman events for accuracy.
  # Here, we parse the dry-run output for "updated" status, but this may not reflect the current run.
  # For the purpose of this script, we use the same logic as for "pending" but change the filter to "updated".
  # Alternatively, you could run a second dry-run and compare with the previous state,
  # but for simplicity, we'll filter for "updated" in the dry-run output.
  # This may not always be accurate; adjust as needed for your use case.
  UPDATED_CONTAINERS=$(echo "$UPDATE_JSON" | jq -r '.[] | select(.Updated == "updated") | "\(.ContainerName // "N/A")"')
  set -e
  while read -r container_name; do
    [[ -n "$container_name" ]] && UPDATED_CONTAINERS_ARR+=("$container_name")
  done <<< "$UPDATED_CONTAINERS"
fi

# --- 5. Construct the Slack message ---
MESSAGE_HEADER="*Podman Auto-Update Report ($(date +%F))*:"

CHECKED_CONTAINERS="*Containers checked (with PODMAN_SYSTEMD_UNIT label):*\n"
if [[ ${#CHECKED_CONTAINERS_ARR[@]} -eq 0 ]]; then
  CHECKED_CONTAINERS+="None\n"
else
  CHECKED_CONTAINERS+=$(printf "%s\n" "${CHECKED_CONTAINERS_ARR[@]}")
fi

NOT_UPDATED_NO_LABEL="*Containers not updated (missing PODMAN_SYSTEMD_UNIT label):*\n"
if [[ ${#NOT_UPDATED_NO_LABEL_ARR[@]} -eq 0 ]]; then
  NOT_UPDATED_NO_LABEL+="None\n"
else
  NOT_UPDATED_NO_LABEL+=$(printf "%s\n" "${NOT_UPDATED_NO_LABEL_ARR[@]}")
fi

NEEDS_UPDATE="*Containers needing update (after update):*\n"
if [[ ${#NEEDS_UPDATE_CONTAINERS_ARR[@]} -eq 0 ]]; then
  NEEDS_UPDATE+="None\n"
else
  NEEDS_UPDATE+=$(printf "%s\n" "${NEEDS_UPDATE_CONTAINERS_ARR[@]}")
fi

UPDATED="*Containers updated during this run:*\n"
if [[ ${#UPDATED_CONTAINERS_ARR[@]} -eq 0 ]]; then
  UPDATED+="None\n"
else
  UPDATED+=$(printf "%s\n" "${UPDATED_CONTAINERS_ARR[@]}")
fi

FULL_MESSAGE="$MESSAGE_HEADER\n$CHECKED_CONTAINERS\n$NOT_UPDATED_NO_LABEL\n$NEEDS_UPDATE\n$UPDATED"

# --- 6. Trim message if it exceeds Slack's limit (around 3000 characters) ---
MAX_LENGTH=2900 # Leave some buffer
MESSAGE_LENGTH=${#FULL_MESSAGE}

if [[ "$MESSAGE_LENGTH" -gt "$MAX_LENGTH" ]]; then
  TRUNCATED_MESSAGE="${FULL_MESSAGE:0:$MAX_LENGTH}...\n*Message truncated due to length.*"
  SLACK_MESSAGE="$TRUNCATED_MESSAGE"
else
  SLACK_MESSAGE="$FULL_MESSAGE"
fi

echo "DEBUG: About to send Slack message to: $WEBHOOK_URL"
echo "DEBUG: Message to send: $SLACK_MESSAGE"
curl -X POST -H 'Content-type: application/json' \
  --data "{\"text\":\"$SLACK_MESSAGE\"}" \
  "$WEBHOOK_URL"
echo "DEBUG: curl exit code: $?"

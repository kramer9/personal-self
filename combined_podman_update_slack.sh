#!/usr/bin/env bash

set -euo pipefail

# set -x # Enable detailed command tracing

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

if [ -z "$WEBHOOK_URL" ]; then
    echo "Error: Failed to retrieve SLACK_WEBHOOK_URL from Bitwarden."
    exit 1
fi

# --- 1. Get all containers with autoupdate label and check for PODMAN_SYSTEMD_UNIT label ---
AUTO_UPDATE_CONTAINERS=$(podman ps --filter label=io.containers.autoupdate=registry --format "{{.ID}}")

declare -a CHECKED_CONTAINERS_ARR=()
declare -a NEEDS_UPDATE_CONTAINERS_ARR=()
declare -a NOT_UPDATED_NO_LABEL_ARR=()
declare -A CONTAINER_UNIT_MAP

for container_id in $AUTO_UPDATE_CONTAINERS; do
    container_name=$(podman inspect --format '{{.Name}}' "$container_id")
    # Use || echo "" to prevent errors if label is missing
    unit_label=$(podman inspect --format '{{ index .Config.Labels "PODMAN_SYSTEMD_UNIT" }}' "$container_id" 2>/dev/null || echo "")
    if [[ -n "$unit_label" ]]; then
        CHECKED_CONTAINERS_ARR+=("$container_name")
        CONTAINER_UNIT_MAP["$container_name"]="$unit_label"
    else
        NOT_UPDATED_NO_LABEL_ARR+=("$container_name")
    fi
done

# --- 2. Run podman auto-update (ignore known errors) ---
if [[ ${#CHECKED_CONTAINERS_ARR[@]} -gt 0 ]]; then
    echo "DEBUG: About to run podman auto-update"
    # Suppress errors about containers without PODMAN_SYSTEMD_UNIT label
    podman auto-update 2>&1 | grep -v "no PODMAN_SYSTEMD_UNIT label found" || true
    echo "DEBUG: podman auto-update exit code: $?"
fi

# --- 3. Get which containers still need update (after update) ---
NEEDS_UPDATE_CONTAINERS_ARR=()
if [[ ${#CHECKED_CONTAINERS_ARR[@]} -gt 0 ]]; then
    set +e
    DRY_RUN_JSON_POST_UPDATE=$(podman auto-update --dry-run --format json)
    JQ_EXIT=0
    NEEDS_UPDATE_CONTAINERS_POST_UPDATE=$(echo "$DRY_RUN_JSON_POST_UPDATE" | jq -r '.[] | select(.Updated == "pending") | .ContainerName' 2>/dev/null) || JQ_EXIT=$?
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
UPDATED_CONTAINERS_ARR=()
if [[ ${#CHECKED_CONTAINERS_ARR[@]} -gt 0 ]]; then
    set +e
    UPDATE_JSON=$(podman auto-update --dry-run --format json)
    UPDATED_CONTAINERS=$(echo "$UPDATE_JSON" | jq -r '.[] | select(.Updated == "updated") | .ContainerName' 2>/dev/null)
    set -e
    while read -r container_name; do
        [[ -n "$container_name" ]] && UPDATED_CONTAINERS_ARR+=("$container_name")
    done <<< "$UPDATED_CONTAINERS"
fi

# --- 5. Compute containers already up-to-date ---
declare -a ALREADY_UPTODATE_CONTAINERS_ARR=()
for cname in "${CHECKED_CONTAINERS_ARR[@]}"; do
    if [[ ! " ${UPDATED_CONTAINERS_ARR[*]} " =~ " $cname " ]] && [[ ! " ${NEEDS_UPDATE_CONTAINERS_ARR[*]} " =~ " $cname " ]]; then
        ALREADY_UPTODATE_CONTAINERS_ARR+=("$cname")
    fi
done

# --- 6. Format function ---
format_containers() {
    local -n arr_ref=$1
    local with_unit=${2:-no}  # default to no if not provided
    local output=""
    for cname in "${arr_ref[@]}"; do
        if [[ "$with_unit" == "unit" ]]; then
            output+="• $cname (systemd unit: ${CONTAINER_UNIT_MAP[$cname]})\n"
        else
            output+="• $cname\n"
        fi
    done
    [[ -z "$output" ]] && output="None\n"
    echo -e "$output"
}

# --- 7. Construct Slack message ---
MESSAGE_HEADER="*Podman Auto-Update Report ($(date +%F))*"

SUMMARY="
*Summary:*
• Containers checked: ${#CHECKED_CONTAINERS_ARR[@]}
• Containers not updated (missing PODMAN_SYSTEMD_UNIT label): ${#NOT_UPDATED_NO_LABEL_ARR[@]}
• Containers updated during this run: ${#UPDATED_CONTAINERS_ARR[@]}
• Containers already up-to-date: ${#ALREADY_UPTODATE_CONTAINERS_ARR[@]}
"

CHECKED_LIST=$(format_containers CHECKED_CONTAINERS_ARR unit)
NOT_UPDATED_LIST=$(format_containers NOT_UPDATED_NO_LABEL_ARR)
UPDATED_LIST=$(format_containers UPDATED_CONTAINERS_ARR)
UPTODATE_LIST=$(format_containers ALREADY_UPTODATE_CONTAINERS_ARR)

FULL_MESSAGE="$MESSAGE_HEADER

$SUMMARY
---

*Containers checked (with PODMAN_SYSTEMD_UNIT label):*
$CHECKED_LIST
*Containers not updated (missing PODMAN_SYSTEMD_UNIT label):*
$NOT_UPDATED_LIST
*Containers updated during this run:*
$UPDATED_LIST
*Containers already up-to-date:*
$UPTODATE_LIST
"

# --- 8. Trim message if it exceeds Slack limit ---
MAX_LENGTH=2900
if (( ${#FULL_MESSAGE} > MAX_LENGTH )); then
    SLACK_MESSAGE="${FULL_MESSAGE:0:$MAX_LENGTH}...\n*Message truncated due to length.*"
else
    SLACK_MESSAGE="$FULL_MESSAGE"
fi

# --- 9. Send message to Slack ---
payload=$(jq -n --arg text "$SLACK_MESSAGE" '{text: $text}')
echo "DEBUG: About to send Slack message to: $WEBHOOK_URL"
echo "DEBUG: Message to send: $SLACK_MESSAGE"
response=$(curl -s -w "\nHTTP_STATUS:%{http_code}\n" -X POST -H 'Content-type: application/json' --data "$payload" "$WEBHOOK_URL")
echo "DEBUG: Slack response: $response"
HTTP_STATUS=$(echo "$response" | grep HTTP_STATUS | cut -d':' -f2)
echo "DEBUG: Slack HTTP status: $HTTP_STATUS"

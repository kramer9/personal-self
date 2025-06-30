#!/bin/bash
log_dir="/var/log/weekly-scripts"
mkdir -p "$log_dir"

scripts=(
    "/home/argus/Repos/Self/combined_podman_update_slack.sh"
#    "/path/to/script2.sh"
#    "/path/to/script3.sh"
)

for script in "${scripts[@]}"; do
    $script > "$log_dir/$(basename $script).log" 2>&1 || {
        echo "Warning: $script reported a problem (see log at $log_dir/$(basename $script).log)"
    }
done

echo "All scripts executed successfully!"

#!/bin/bash

check_container_isolation() {
    container_id=$1
    echo "Checking container: $container_id"
    
    # Initialize status to success
    status="Success"

    # Scenario 1: Check if the container is running in privileged mode
    privileged=$(docker inspect --format '{{.HostConfig.Privileged}}' "$container_id")
    if [ "$privileged" == "true" ]; then
        echo "Container is running in privileged mode. Potential security risk."
        status="Failure"
    fi

    # Scenario 2: Check for abnormal capabilities
    capabilities=$(docker inspect --format '{{.HostConfig.CapAdd}}' "$container_id")
    if [[ "$capabilities" == *"SYS_ADMIN"* ]]; then
        echo "Container has SYS_ADMIN capability. Potential security risk."
        status="Failure"
    fi

    # Scenario 3: Check for mounted sensitive host directories
    mounts=$(docker inspect --format '{{range .Mounts}}{{.Source}} {{end}}' "$container_id")
    sensitive_mounts=("/etc" "/var/run" "/usr")
    for sensitive_mount in "${sensitive_mounts[@]}"; do
        if [[ "$mounts" == *"$sensitive_mount"* ]]; then
            echo "Container has mounted a sensitive host directory ($sensitive_mount). Potential security risk."
            status="Failure"
        fi
    done

    # Scenario 4: Check for unusual processes in the container
    container_processes=$(docker top "$container_id" -eo pid,args | tail -n +2)
    suspicious_processes=("sh" "bash" "nc" "netcat")
    for process in "${suspicious_processes[@]}"; do
        if echo "$container_processes" | grep -q "$process"; then
            echo "Container has a suspicious process ($process). Potential security risk."
            status="Failure"
        fi
    done

    # # Scenario 5: Check for breakout attempts using common tools
    # # breakout_attempts=("nsenter" "chroot" "docker exec")
    # breakout_attempts=("nsenter" "chroot" "docker exec")
    # for attempt in "${breakout_attempts[@]}"; do
    #     if command -v "$attempt" > /dev/null; then
    #         echo "Common breakout tool '$attempt' is available on the host. Potential security risk."
    #         status="Failure"
    #     fi
    # done

    # Print the overall status
    echo "Scenario status: $status"
}

# Replace 'your_container_id' with the actual container ID you want to inspect

containerID=$(docker ps | awk '{print $1}' | grep -v CONTAINER)
echo $containerID

# Initialize overall status to success
overall_status="Success"

for cid in $containerID; do
    echo "=================================================================================================================="
    check_container_isolation "$cid"
    
    # Update overall status based on individual scenario status
    if [ "$status" == "Failure" ]; then
        overall_status="Failure"
    fi
done

# Print overall status
echo "Overall status: $overall_status"

# Print a message if any scenario failed
if [ "$overall_status" == "Failure" ]; then
    echo "Hi, it failed!"
    exit 1
fi

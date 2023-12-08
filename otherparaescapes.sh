#!/bin/bash

check_container_isolation() {
    container_id=$1
    echo $container_id
    # Scenario 1: Check if the container is running in privileged mode
    privileged=$(docker inspect --format '{{.HostConfig.Privileged}}' "$container_id")
    if [ "$privileged" == "true" ]; then
        echo "Container is running in privileged mode. Potential security risk."
    fi

    # Scenario 2: Check for abnormal capabilities
    capabilities=$(docker inspect --format '{{.HostConfig.CapAdd}}' "$container_id")
    if [[ "$capabilities" == *"SYS_ADMIN"* ]]; then
        echo "Container has SYS_ADMIN capability. Potential security risk."
    fi

    # Scenario 3: Check for mounted sensitive host directories
    mounts=$(docker inspect --format '{{range .Mounts}}{{.Source}} {{end}}' "$container_id")
    sensitive_mounts=("/etc" "/var/run" "/usr")
    for sensitive_mount in "${sensitive_mounts[@]}"; do
        if [[ "$mounts" == *"$sensitive_mount"* ]]; then
            echo "Container has mounted a sensitive host directory ($sensitive_mount). Potential security risk."
        fi
    done

    # Scenario 4: Check for unusual processes in the container
    container_processes=$(docker top "$container_id" -eo pid,args | tail -n +2)
    suspicious_processes=("sh" "bash" "nc" "netcat")
    for process in "${suspicious_processes[@]}"; do
        if echo "$container_processes" | grep -q "$process"; then
            echo "Container has a suspicious process ($process). Potential security risk."
        fi
    done

    # Scenario 5: Check for breakout attempts using common tools
    breakout_attempts=("nsenter" "chroot" "docker exec")
    for attempt in "${breakout_attempts[@]}"; do
        if command -v "$attempt" > /dev/null; then
            echo "Common breakout tool '$attempt' is available on the host. Potential security risk."
        fi
    done

    # Additional checks can be added based on specific use cases and security policies
}

# Replace 'your_container_id' with the actual container ID you want to inspect

containerID=$(docker ps | awk '{print $1}' | grep -v CONTAINER)
echo $containerID
for cid in $containerID; do
        echo "=================================================================================================================="
        check_container_isolation "$cid"
done

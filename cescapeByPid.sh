#!/bin/bash
set +x
set -e

check_pid_namespace() {
    local container_id=$1

    log "============================================================================================================"
    log "1"
    log "Checking Container ID: $container_id"

    ns=$(docker exec "$container_id" bash -c "lsns -t pid" | awk 'NR>1')
    namespace=$(echo "$ns" | awk '{print $1}')
    
    log "Namespace = $namespace"
    
    num_namespaces=$(echo "$ns" | wc -l)
    log "Number of namespaces = $num_namespaces"

    if [ "$num_namespaces" -gt 1 ]; then
        log "Container $container_id may have escaped! More than one namespace found"
    else
        check_child_pids "$container_id" "$namespace"
        check_container_pids_on_host "$container_id" "$namespace"
    fi
}

check_child_pids() {
    local container_id=$1
    local namespace=$2

    list_of_all_child_pids=$(docker exec "$container_id" bash -c "ps -e -o pidns,pid" | awk 'NR>1' | head -n -1 | grep - | awk '{print $2}')
    log "List of all child PIDs: $list_of_all_child_pids"

    if [ -n "$list_of_all_child_pids" ] && [ -n "$(echo "$list_of_all_child_pids" | tr -d '[:space:]')" ]; then
        for cpid in $list_of_all_child_pids; do
            cpid=$(echo "$cpid" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            check_cpid_namespace "$container_id" "$cpid" "$namespace"
        done
    fi
}

check_cpid_namespace() {
    local container_id=$1
    local cpid=$2
    local namespace=$3

    getPpid=$(docker exec "$container_id" bash -c "cat /proc/$cpid/status" | grep PPid | cut -d':' -f2 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    PpidNs=$(docker exec "$container_id" bash -c "ps -p $getPpid -o pidns,pid" | awk 'NR>1' | awk '{print $1}')

    if [ "$namespace" == "$PpidNs" ]; then
        log "Child PID $cpid, belonging to parent PID $getPpid, has the same PID namespace"
    else
        log "Container $container_id: The child PID $cpid and parent PID $getPpid don't have the same namespace. This indicates that the container might have escaped"
        exit 1
    fi
}

check_container_pids_on_host() {
    local container_id=$1
    local namespace=$2

    listofPidsinContainer=$(docker exec "$container_id" bash -c "ps -e -o pidns,pid" | awk 'NR>1' | awk '{print $2}')

    declare -a pid_array

    while read -r pid; do
        pid_array+=("$pid")
    done <<< "$listofPidsinContainer"

    listofpidsOnHostwithContainerPISNS=$(ps -e -o pidns,pid | grep "$namespace" | awk '{print $2}')

    for hpid in $listofpidsOnHostwithContainerPISNS; do
        check_cpid_on_host "$container_id" "$hpid" "${pid_array[@]}"
    done
}

check_cpid_on_host() {
    local container_id=$1
    local hpid=$2
    local pid_array=("${@:3}")

    checkCpidOnHost=$(cat /proc/"$hpid"/status | grep NSpid | awk '{print $3}')
    log "$checkCpidOnHost"
    log "${pid_array[*]} "
    if [[ " ${pid_array[*]} " =~ "$checkCpidOnHost" ]]; then
        log "Process on host $checkCpidOnHost is the same as in container $container_id"
    else
        log "Container $container_id has possibly escaped, as the process on host $checkCpidOnHost does not match with the process in the container"
    fi
}

log() {
    echo "[INFO] $1"
}

# Main script

container_ids=$(docker ps | awk '{print $1}' | grep -v CONTAINER)

for container_id in $container_ids; do
    check_pid_namespace "$container_id"
done

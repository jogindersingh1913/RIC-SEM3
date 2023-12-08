#!/bin/bash
set +x
set -e

containerID=$(docker ps | awk '{print $1}' | grep -v CONTAINER)
echo $containerID
for cid in $containerID; do
        echo "============================================================================================================"
        echo "container id : $cid"
        ns=$(docker exec  $cid  bash -c "lsns -t pid"| awk 'NR>1')
        echo $ns
        # Count the number of namespaces
        namespace=$(echo $ns|awk '{print $1}')
        echo "namespace = $namespace"
        num_namespaces=$(echo "$ns" | wc -l)
        echo "number of namespace = $num_namespaces"
        if [ "$num_namespaces" -gt 1 ]; then
                echo "Container $cid  may have escaped! More than one namespace found"
        else
                #check all the child process are of same ns as parent pid ns
                list_of_all_child_pids=$(docker exec  $cid bash -c "ps -e -o pidns,pid" | awk 'NR>1' | head -n -1 | grep - | awk '{print $2}')
                echo "list of all cpids  == $list_of_all_child_pids"
                if [ -n "$list_of_all_child_pids" ] && [ -n "$(echo "$list_of_all_child_pids" | tr -d '[:space:]')" ]; then
                        for cpid in $list_of_all_child_pids; do
                                cpid=$(echo "$cpid"| sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                                getPpid=$(docker exec  $cid bash -c "cat /proc/$cpid/status"| grep PPid |cut -d':' -f2 |sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                                PpidNs=$(docker exec  $cid bash -c "ps -p $getPpid -o pidns,pid" | awk 'NR>1' | awk '{print $1}')
                                echo "getPPid is $getPpid"
                                if [ "$namespace" == "$PpidNs" ]; then
                                        echo "childPID $cpid which belongs to parentPID $getPpid has the same PIDnamespace"
                                else
                                        echo "container $cid = the childPID and parent PID doesnt have same namespace. This indicates that container might have escaped"
                                        exit 1
                                fi
                        done
                fi
                listofPidsinContainer=$(docker exec  $cid bash -c "ps -e -o pidns,pid"| awk 'NR>1'| awk '{print $2}')
                echo "list of pids in container ::  $listofPidsinContainer"

                # Initialize an array
                declare -a pid_array
                # Populate the array
                while read -r pid; do
                        pid_array+=("$pid")
                done <<< "$listofPidsinContainer"


                listofpidsOnHostwithContainerPISNS=$(ps -e -o pidns,pid|grep $namespace | awk '{print $2}')
                for hpid in $listofpidsOnHostwithContainerPISNS; do
                        checkCpidOnHost=$(cat /proc/$hpid/status | grep NSpid | awk '{print $3}')
                        if [[ " ${pid_array[*]} " =~ "$checkCpidOnHost" ]]; then
                                echo "process on host is same as on container, so container is safe"
                        else
                                echo "container escapes as the process on host dont match with the process in the container"
                                exit 1
                        fi
                        done
        fi
        done

#!/bin/bash

# required: regex to identify the java process uniquely
# the user needs to have permissions to execute jps, jstat

JVM_PROCESS_REGEX=${JVM_PROCESS_REGEX:-$1}

if [ -z "${JVM_PROCESS_REGEX}" ]; then
    printf -- "JVM_PROCESS_REGEX is a required input. Exiting.\n"
    exit 127
fi

pid=$(jps | grep "${JVM_PROCESS_REGEX}" | awk '{print $1}')

#echo "===================================="
#echo "Checking Mem usage for PID ${pid}..."

if [ "${pid}" == "" ]; then
  mem=0
else
  mem=$(jstat -gc ${pid} | tail -n 1 | awk '{split($0,a," "); sum=a[3]+a[4]+a[6]+a[8]; print sum/1024}')
fi

JVM_MEM_USAGE=${mem}
export JVM_MEM_USAGE
echo "${JVM_MEM_USAGE}"

#!/bin/bash

# required: regex to identify the java process uniquely
# aws cli, s3 permissions to dump jvm info
# the user needs to have permissions to execute jcmd, jps, jmap, jstat, jstack

JVM_PROCESS_REGEX=${JVM_PROCESS_REGEX:-$1}
BUCKET=${BUCKET:-$2}

if [ -z "${JVM_PROCESS_REGEX}" ] || [ -z "${BUCKET}" ]; then
    printf -- "JVM_PROCESS_REGEX and storage BUCKET are required inputs exiting.\n"
    exit 127
fi

pid=$(jps | grep "${JVM_PROCESS_REGEX}" | awk '{print $1}')
timestamp=$(date +%Y%m%d%H%M%S)
remote_dir=${BUCKET}/java-dumps-${timestamp}
#killall5
# take heap dump using

copy_to_remote() {
  BUCKET_TYPE=`echo ${BUCKET} | cut -d':' -f1`
  case ${BUCKET_TYPE} in
    s3) aws s3 cp $1 $2 &> /dev/null  ;;
    gs) gsutil cp $1 $2 &> /dev/null  ;;
  esac
  printf -- "$3 upload destination: $2\n"
}

echo "================================"
echo "Dumping traces for PID ${pid}..."
echo "================================"


heap_dump(){
    if command -v jcmd &> /dev/null; then
        printf -- "using jcmd to take heap dump.\n"
        jcmd_dump="/tmp/heap_dump_${pid}_${timestamp}"
        jcmd ${pid} GC.heap_dump ${jcmd_dump} &> /dev/null
        copy_to_remote ${jcmd_dump} ${remote_dir}/heap_dump.hprof "heap dump"
        return
    elif command -v jmap &> /dev/null; then
        printf -- "using jmap to take heap dump.\n"
        jmap_dump="/tmp/heap_dump_${pid}_${timestamp}"
        jmap -dump:live,format=b,file=${jmap_dump} $pid &> /dev/null
        copy_to_remote ${jmap_dump} ${remote_dir}/heap_dump.hprof "heap dump"
        return
    else
        printf -- "jcmd or jmap not found, skipping heap dump.\n"
    fi
}

thread_dump(){
    if command -v jstack &> /dev/null
    then
        printf -- "using jstack to take thread dump.\n"
        thread_dump="/tmp/thread_dump_${pid}_${timestamp}"
        jstack -F ${pid} > ${thread_dump}
        copy_to_remote ${thread_dump} ${remote_dir}/thread_info.txt "thread dump"
        return
    else
        printf -- "jstack not found skipping thread dump.\n"
    fi
}

gc_info(){
    if command -v jstat &> /dev/null
    then
        printf -- "using jstat to get gc info.\n"
        gc_dump="/tmp/gc_info_${pid}_${timestamp}"
        jstat -gc $pid 1000 5 > ${gc_dump}
        copy_to_remote ${gc_dump} ${remote_dir}/gc_info.txt "garbage collector info"
        return

    else
        echo "jstack not found skipping gc info collection.\n"
    fi
}

heap_info(){
    if command -v jstat &> /dev/null
    then
        printf -- "using jmap to get heap stats.\n"
        heap_stats="/tmp/heap_info_${pid}_${timestamp}"
        jmap -heap $pid > ${heap_stats}
        copy_to_remote ${heap_stats} ${remote_dir}/heap_stats.txt "heap stats"
        return
    else
        echo "jmap not found skipping heap info collection.\n"
    fi
}

detect_deadlock() {
    jstack -F -m ${pid} | grep "No deadlocks found" &> /dev/null
    if [ $? -eq 1 ]; then
        printf -- "Deadlocks were detected in jstack output.\n"
    else
        printf -- "No deadlocks detected in jstack output.\n"
    fi
}

heap_dump
heap_info
thread_dump
gc_info
detect_deadlock
printf -- "The remote location for the jvm dumps is ${remote_dir}/.\n"

# Don't kill the pod for now.
#killall5


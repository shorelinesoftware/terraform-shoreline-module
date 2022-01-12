#!/bin/bash

# exit on any errors
set -e

RETURN_CODE=1
# seconds to wait on k8s/alarms/etc
MAX_WAIT=240
# seconds to pause between checking k8s/alarms/etc
PAUSE_TIME=5

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

TEST_ONLY=0

on_exit () {
  set +e
  echo -n -e "${RED}"
  echo "============================================================"
  echo "Test script failed."
  echo "============================================================"
  echo "Attempting cleanup..."
  echo -e "${NC}"
  do_cleanup
  exit 1
}
trap on_exit ERR
#trap on_exit EXIT

PATH=${PATH}:~/work/shoreline/cli/go/bin/
# PATH=${PATH}:~/work/shoreline/cli/go/bin CLI=`command -v oplang_cli`


############################################################
# Utility functions

pre_error() {
  echo -n -e "${RED}"
  echo "============================================================"
  echo "ERROR: $1"
  echo "============================================================"
  echo -e "${NC}"
  exit 1
}


do_timeout() {
  echo -n -e "${RED}"
  echo "============================================================"
  echo "ERROR: Timed out waiting for $1"
  echo "============================================================"
  echo "Attempting cleanup..."
  echo -e "${NC}"
  do_cleanup
  exit 2
}

check_command() {
  command -v $1 > /dev/null || pre_error "missing command $1"
}

check_env() {
  env | grep -e "^$1=" ||  pre_error "missing env variable $1"
}

get_event_counts() {
  echo "events | name =~ 'jvm' | count" | ${CLI} | grep "group_all" || echo 0
}

check_jvm_file() {
  echo "pod | app='jvm-test' | limit=1 | \`ls /tmp/\`" | ${CLI} | grep "EatResources.java"
}

check_jvm_pod() {
  echo "pod | app='jvm-test' | limit=1" | ${CLI} | grep "jvm-test"
}


############################################################
# Pre-flight validation

check_command kubectl
check_command oplang_cli
check_command aws

check_env SHORELINE_URL
check_env SHORELINE_TOKEN
check_env CLUSTER

CLI=`command -v oplang_cli`


############################################################
# setup

do_setup_terraform() {
  echo "Setting up terraform objects"
  terraform init
  terraform apply --auto-approve
}

do_setup_kube() {
  echo "Setting up k8s objects (pods)"
  # XXX should we pre-delete any existing: pods -- just in case

  kubectl apply -f ./jvm_test.yaml
  # dynamically check for pod...
  echo "waiting for jvm-test pod creation ..."
  used=0
  until check_jvm_pod; do
    echo "  waiting..."
    sleep ${PAUSE_TIME}
    # timeout after maximum wait and fail
    used=$(( ${used} + ${PAUSE_TIME} ))
    if [ ${used} -gt ${MAX_WAIT} ]; then
      do_timeout "pod creation"
    fi
  done
  check_jvm_pod
  
  #echo " host | pod | app='pvc-test' | \`apt-get update\` " | ${CLI}
  #echo " host | pod | app='pvc-test' | \`apt-get install -y jq\` " | ${CLI}
  #echo " host | pod | app='pvc-test' | \`curl -LO https://dl.k8s.io/release/v1.20.0/bin/linux/amd64/kubectl\` " | ${CLI}
  #echo " host | pod | app='pvc-test' | \`chmod +x kubectl; mv kubectl /bin/\` " | ${CLI}

  echo "a little quiet time for the pod to stabilize and register ..."
  sleep 20
}

do_setup() {
  do_cleanup_s3
  do_setup_terraform
  do_setup_kube
}

############################################################
# cleanup

do_cleanup_s3() {
  aws s3 rm s3://shore-oppack-test/ --recursive --exclude "*" --include "java-dumps-20*"
}

do_cleanup_terraform() {
  echo "Cleaning up terraform objects"
  terraform destroy --auto-approve
}

do_cleanup_kube() {
  echo "Cleaning up k8s objects (pods)"
  kubectl -n jvm-test-ns delete pod,deployment,role,rolebinding --all
  #kubectl -n jvm-test-ns delete sa jvm-test-sa
}

do_cleanup() {
  if [ ${TEST_ONLY} == 0 ]; then
    do_cleanup_kube
    do_cleanup_terraform
    do_cleanup_s3
  fi
}

############################################################
# actual tests

run_tests() {

  # clean up old java test processes
  echo 'pods | app = "jvm-test" | `rm /tmp/*-mem.txt`' | ${CLI}
  echo 'pods | app = "jvm-test" | `ps afxww | grep java | grep Resource | grep -v grep | grep -v INSTANCE | sed -e "s/^[ ]*//g" | cut -d" " -f1 | xargs kill`' | ${CLI}

  # verify that the jvm-test pod resource was created
  pods=`echo "pod | app='jvm-test' | count" | ${CLI} | grep -A1 'RESOURCE_COUNT' | tail -n1`

  # count alarms before we started
  pre_fired=`get_event_counts | cut -d '|' -f 3`
  pre_cleared=`get_event_counts | cut -d '|' -f 4`
  #pre_total=`get_event_counts | cut -d '|' -f 5`

  # dynamically wait for the java file to propagate
  echo "waiting for java file to propagate ..."
  used=0
  while ! check_jvm_file; do
    echo "  waiting..."
    sleep ${PAUSE_TIME}
    # timeout after maximum wait and fail
    used=$(( ${used} + ${PAUSE_TIME} ))
    if [ ${used} -gt ${MAX_WAIT} ]; then
      do_timeout "java file propagation"
    fi
  done
  echo "java file propagated"

  echo "Starting jvm processes..."
  echo "pod | app='jvm-test' | \`cd /tmp; javac EatResources.java && java EatResources &\`" | ${CLI}
  echo "pod | app='jvm-test' | \`cd /tmp; javac ChewResources.java && java ChewResources &\`" | ${CLI}
  echo "pod | app='jvm-test' | \`cd /tmp; javac GnawResources.java && java GnawResources &\`" | ${CLI}
 
  echo "Asking extra jvm pod to consume memory..."
  echo "pod | app='jvm-test' | \`echo 1000 > /tmp/chew-mem.txt\`" | ${CLI}
  sleep 20
  mid_fired=`get_event_counts | cut -d '|' -f 3`
  get_event_counts
  if [ "${mid_fired}" != "${pre_fired}" ]; then
    echo -n -e "${RED}"
    echo "============================================================"
    echo "ERROR: Alarm fired on wrong process!"
    echo "============================================================"
    echo -e "${NC}"
    do_cleanup
    exit 1
  fi

  echo "Asking jvm pods to consume memory..."
  echo "pod | app='jvm-test' | \`echo 1000 > /tmp/eat-mem.txt\`" | ${CLI}

  echo "waiting for jvm alarm to fire ..."
  # verify that the alarm fired:
  post_fired=`get_event_counts | cut -d '|' -f 3`
  get_event_counts
  used=0
  while [ "${post_fired}" == "${pre_fired}" ]; do
    echo "  waiting..."
    sleep ${PAUSE_TIME}
    post_fired=`get_event_counts | cut -d '|' -f 3`
    # timeout after maximum wait and fail
    used=$(( ${used} + ${PAUSE_TIME} ))
    if [ ${used} -gt ${MAX_WAIT} ]; then
      do_timeout "alarm to fire"
    fi
  done
  get_event_counts

  echo "waiting for jvm alarm to clear ..."
  post_cleared=`get_event_counts | cut -d '|' -f 4`
  used=0
  while [ "${post_cleared}" == "${pre_cleared}" ]; do
    echo "  waiting..."
    sleep ${PAUSE_TIME}
    post_cleared=`get_event_counts | cut -d '|' -f 4`
    # timeout after maximum wait and fail
    used=$(( ${used} + ${PAUSE_TIME} ))
    if [ ${used} -gt ${MAX_WAIT} ]; then
      do_timeout "alarm to clear"
    fi
  done
  get_event_counts

  if  [ "${post_cleared}" == "${pre_cleared}" ]; then
    echo -n -e "${RED}"
    echo "============================================================"
    echo "ERROR: Failed to dump JVM stack!"
    echo "============================================================"
    echo -e "${NC}"
  fi

  echo "Asking third jvm pods to consume memory..."
  echo "pod | app='jvm-test' | \`echo 1000 > /tmp/gnaw-mem.txt\`" | ${CLI}
  echo "waiting for second jvm alarm to fire ..."
  # verify that the alarm fired:
  second_fired=`get_event_counts | cut -d '|' -f 3`
  get_event_counts
  used=0
  while [ "${post_fired}" == "${second_fired}" ]; do
    echo "  waiting..."
    sleep ${PAUSE_TIME}
    post_fired=`get_event_counts | cut -d '|' -f 3`
    # timeout after maximum wait and fail
    used=$(( ${used} + ${PAUSE_TIME} ))
    if [ ${used} -gt ${MAX_WAIT} ]; then
      do_timeout "alarm to fire"
    fi
  done

  if  [ "${post_cleared}" == "${second_cleared}" ]; then
    echo -n -e "${RED}"
    echo "============================================================"
    echo "ERROR: Failed to dump second JVM stack!"
    echo "============================================================"
    echo -e "${NC}"
  fi

  echo "waiting for second jvm alarm to clear ..."
  second_cleared=`get_event_counts | cut -d '|' -f 4`
  used=0
  while [ "${post_cleared}" == "${second_cleared}" ]; do
    echo "  waiting..."
    sleep ${PAUSE_TIME}
    post_cleared=`get_event_counts | cut -d '|' -f 4`
    # timeout after maximum wait and fail
    used=$(( ${used} + ${PAUSE_TIME} ))
    if [ ${used} -gt ${MAX_WAIT} ]; then
      do_timeout "alarm to clear"
    fi
  done


  # check S3 for data...
  dump_dir_count=`aws s3 ls s3://shore-oppack-test/ | grep java-dumps | wc -l`
  if [ "${dump_dir_count}" == "0" ]; then
    echo -n -e "${RED}"
    echo "============================================================"
    echo "ERROR: Failed to push JVM stacks to AWS S3!"
    echo "============================================================"
    echo -e "${NC}"
  else
    echo -n -e "${GREEN}"
    echo "============================================================"
    echo "Successfully dumped JVM stack!"
    echo "============================================================"
    echo -e "${NC}"
    RETURN_CODE=0
  fi
}

do_all() {
  do_setup
  run_tests
  do_cleanup
  exit ${RETURN_CODE}
}

case $1 in
       setup) do_setup ;;
     cleanup) do_cleanup ;;
  debug-only) TEST_ONLY=1; set -x; run_tests ;;
   test-only) TEST_ONLY=1; run_tests ;;
          *) do_all ;;
esac


############################################################
# useful op commands

# testpvc_resize_pvc(PVC_REGEX="tofill", PVC_INCREMENT=1, PVC_MAX_SIZE=5, ALARM_NAMESPACE="jvm-test-ns", ALARM_POD_NAME="jvm-test-76cd5866b4-nq9tk")
# testjvm_jvm_dump_stack(JVM_RE'EatResources', 'shore-oppack-test')
# pods | app =~ "jvm" | `yum install -y tar`
# pods | app =~ "jvm" | `cd /tmp; javac EatResources.java`
# pods | app =~ "jvm" | `cd /tmp; java EatResources &`
# pods | app =~ "jvm" | `cd /tmp; javac EatResources.java && java EatResources &`
# pods | app='jvm-test' | `top -b -n1 | grep 'java\|pid'`
# pods | app='jvm-test' | `echo 1000 >/tmp/eat-mem.txt`
# events | alarm_name =~ "jvm"
# aws s3 ls s3://shore-oppack-test
# aws s3 rm s3://shore-oppack-test/ --recursive --exclude "*" --include "java-dumps-20*"
# kubectl -n jvm-test-ns exec -it `kubectl -n jvm-test-ns get pods | grep jvm | cut -d' ' -f1 | head -n 1` bash


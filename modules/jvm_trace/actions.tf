
# Action to report the JVM heap usage on the selected resources and process.
# Returns MB memory used.
resource "shoreline_action" "jvm_trace_mem_usage" {
  name = "${var.op_prefix}_jvm_mem_usage"
  description = "Calculate heap utilization by process regex."
  # Parameters passed in: the regular expression to select process name.
  params = [ "JVM_PROCESS_REGEX" ]
  # Extract the heap used for the matching process and return 1 if above threshold.
  command = "`cd ${var.script_path} && chmod +x jvm*.sh && ./jvm_mem_usage.sh $${JVM_PROCESS_REGEX}`"
  # Select the shell to run 'command' with.
  #shell = "/bin/sh"
  res_env_var = "JVM_MEM_USAGE"

  # UI / CLI annotation informational messages:
  start_short_template    = "Calculating JVM heap usage."
  error_short_template    = "Error calculating JVM heap usage."
  complete_short_template = "Finished calculating JVM heap usage."
  start_long_template     = "Calculating JVM process ${var.jvm_process_regex} heap usage."
  error_long_template     = "Error calculating JVM process ${var.jvm_process_regex} heap usage."
  complete_long_template  = "Finished calculating JVM process ${var.jvm_process_regex} heap usage."

  enabled = true
}

# Action to check the JVM heap usage on the selected resources and process.
# Prints a message and returns 1, if threshold is exceeded.
resource "shoreline_action" "jvm_trace_check_heap" {
  name = "${var.op_prefix}_jvm_check_heap"
  description = "Check heap utilization by process regex."
  # Parameters passed in: the regular expression to select process name.
  params = [ "JVM_PROCESS_REGEX" ]
  # Extract the heap used for the matching process and return 1 if above threshold.
  command = "`cd ${var.script_path} && chmod +x jvm*.sh && hm=$(./jvm_mem_usage.sh $${JVM_PROCESS_REGEX} ); hm=$${hm%.*}; if [ $hm -gt ${var.mem_threshold} ]; then echo \"heap memory $hm MB > threshold ${var.mem_threshold} MB\"; exit 1; fi`"
  # Select the shell to run 'command' with.
  #shell = "/bin/sh"

  # UI / CLI annotation informational messages:
  start_short_template    = "Checking JVM heap usage."
  error_short_template    = "Error checking JVM heap usage."
  complete_short_template = "Finished checking JVM heap usage."
  start_long_template     = "Checking JVM process ${var.jvm_process_regex} heap usage."
  error_long_template     = "Error checking JVM process ${var.jvm_process_regex} heap usage."
  complete_long_template  = "Finished checking JVM process ${var.jvm_process_regex} heap usage."

  enabled = true
}

# Action to dump the JVM stack-trace on the selected resources and process.
resource "shoreline_action" "jvm_trace_jvm_debug" {
  name = "${var.op_prefix}_jvm_dump_stack"
  description = "Dump JVM process (by regex) heap, thread and GC info to s3, then kill the pod."
  # Parameters passed in: the regular expression to select process name, and destination AWS S3 bucket.
  params = [ "JVM_PROCESS_REGEX" , "BUCKET"]
  # Extract process info, and kill the pod.
  command = "`cd ${var.script_path} && chmod +x jvm_*.sh && ./jvm_dumps.sh $${JVM_PROCESS_REGEX} $${BUCKET} >>/tmp/dumps.log`"
  # Select the shell to run 'command' with.
  #shell = "/bin/sh"

  # UI / CLI annotation informational messages:
  start_short_template    = "Dumping JVM info."
  error_short_template    = "Error dumping JVM info."
  complete_short_template = "Finished dumping JVM info."
  start_long_template     = "Dumping JVM process ${var.jvm_process_regex} info."
  error_long_template     = "Error dumping JVM process ${var.jvm_process_regex} info."
  complete_long_template  = "Finished dumping JVM process ${var.jvm_process_regex} info."

  enabled = true
}


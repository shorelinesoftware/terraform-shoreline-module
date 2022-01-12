# Push the script that calculates JVM process memory.
resource "shoreline_file" "jvm_trace_mem_script" {
  name = "${var.op_prefix}_mem_script"
  description = "Script to calculate JVM process memory usage."
  input_file = "${path.module}/data/jvm_mem_usage.sh"       # source file (relative to this module)
  destination_path = "${var.script_path}/jvm_mem_usage.sh"  # where it is copied to on the selected resources
  resource_query = "${var.resource_query}"                  # which resources to copy to
  enabled = true
}

# Push the script that actually performs the JVM stack dump to the selected nodes.
resource "shoreline_file" "jvm_trace_dump_script" {
  name = "${var.op_prefix}_dump_script"
  description = "Script to dump JVM stack traces."
  input_file = "${path.module}/data/jvm_dumps.sh"       # source file (relative to this module)
  destination_path = "${var.script_path}/jvm_dumps.sh"  # where it is copied to on the selected resources
  resource_query = "${var.resource_query}"              # which resources to copy to
  enabled = true
}


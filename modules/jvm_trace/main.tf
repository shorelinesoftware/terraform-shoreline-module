################################################################################
# Module: jvm_stacktrace
# 
# Monitor JVM processes that match a reges, and if they exceed a memory limit,
# automatically collect a stack-trace from the selected process.
#
# Example usage:
#
#   module "jvm_trace" {
#     # Location of the module:
#     source             = "./"
#   
#     # Namespacing to allow multiple instances of the module, with different params:
#     op_prefix          = "jvm_trace"
#   
#     # Resource query to select the affected resources:
#     resource_query     = "jvm_pods"
#   
#     # Regular expresssion to select the monitored JVM processes:
#     pvc_regex          = "tomcat"
#   
#     # Maximum memory usage, in Mb, before the JVM process is traced:
#     mem_threshold     = 1000
#   
#     # Destination of the memory-check, and trace scripts on the selected resources:
#     script_path = "/agent/scripts"
#
#     # S3 or GCS storage bucket for heap dumps and stack traces
#     bucket = "s3://my_jvm_traces"
#
#     # Frequency to evaluate alarm conditions in seconds.
#     check_interval = 60
#
#   }

################################################################################


terraform {
  # Setting 0.13.1 as the minimum version. Older versions are missing significant features.
  required_version = ">= 0.13.1"
}

#provider "shoreline" {
#  # provider configuration here
#  retries = 2
#  debug = true
#}



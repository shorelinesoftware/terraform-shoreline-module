# JVM Trace Op Pack Example

This document contains configuration and usage examples of the [JVM Trace Op Pack](https://github.com/shorelinesoftware/terraform-shoreline-modules/tree/main/modules/jvm-trace).

## Requirements

The following tools are required on the monitored resources, with appropriate permissions:

1. Java tools: jcmd, jps, jmap, jstat, jstack.
1. The [AWS CLI](https://aws.amazon.com/cli/) (for AWS S3) or the [gsutil CLI](https://cloud.google.com/storage/docs/gsutil) (for GCS).

## Example

The following example monitors all pod resources with an app label of `jvm-test`. Whenever a targeted pod's `tomcat` process exceeds the `mem_threshold` of `1000` MB, the debug data is dumped and pushed to the `jvm_trace_example_bucket` AWS S3 bucket.

```hcl
terraform {
  required_providers {
    shoreline = {
      source  = "shorelinesoftware/shoreline"
      version = ">= 1.1.3"
    }
  }
}

provider "shoreline" {
  # provider configuration here
  debug   = true
  retries = 2
  url     = "<SHORELINE_CLUSTER_API_ENDPOINT>"
}

module "jvm_trace" {
  # Location of the module
  source             = "shorelinesoftware/modules/shoreline//modules/jvm_trace"

  # S3 or GCS storage bucket for heap dumps and stack traces
  bucket             = "s3://jvm_trace_example_bucket"

  # Frequency to evaluate alarm conditions in seconds
  check_interval     = 60

  # Regular expression to select the monitored JVM processes
  jvm_process_regex  = "tomcat"

  # Maximum memory usage, in Mb, before the JVM process is traced
  mem_threshold      = 1000

  # Namespace to allow multiple instances of the module, with different params
  op_prefix          = "jvm_example"

  # Resource query to select the affected resources
  resource_query     = "pods | app='jvm-test'"

  # Destination of the memory-check, and trace scripts on the selected resources
  script_path        = "/tmp"
}
```

## Manual command examples

These commands use Shoreline's expressive [Op language](https://docs.shoreline.io/op) to retrieve fleet-wide data using the generated actions from the JVM trace module.

-> These commands can be executed within the [Shoreline CLI](https://docs.shoreline.io/installation#cli) or [Shoreline Notebooks](https://docs.shoreline.io/ui/notebooks).

### Force data collection for a given set of processes

```
op> pods | app = "tomcat" | jvm_trace_jvm_dump_stack("tomcat", "s3://jvm_trace_example_bucket")
```

-> See the [shoreline_action resource](https://registry.terraform.io/providers/shorelinesoftware/shoreline/latest/docs/resources/action) and the [Shoreline Actions](https://docs.shoreline.io/actions) documentation for details.

### Force data collection for a given set of processes, on a single (arbitrary) pod

```
op> pods | app = "tomcat" | limit=1 | jvm_trace_jvm_dump_stack("tomcat", "s3://jvm_trace_example_bucket")
```

### Manually check memory usage on a set of pods

```
op> pods | name =~ 'jvm' | jvm_trace_jvm_check_heap('ChewResources')

 ID | TYPE      | NAME                                        | REGION    | AZ         | STATUS | STDOUT
 70 | CONTAINER | jvm-test-bcc5cf748-xd54m.jvm-test-container | us-west-2 | us-west-2b |   1    | heap memory 1165 MB > threshold 30 MB
    |           |                                             |           |            |        |
```

### List triggered JVM Alarms

```
op> events | alarm_name =~ 'jvm'

 RESOURCE_NAME  | RESOURCE_TYPE | ALARM_NAME               | STATUS   | STEP_TYPE   | TIMESTAMP                 | DESCRIPTION
 jvm-test-xd54m | POD           | jvm_trace_jvm_heap_alarm | resolved |             |                           | Alarm on JVM heap usage growing larger than a threshold.
                |               |                          |          | ALARM_FIRE  | 2022-01-10T17:16:58-08:00 | JVM heap usage exceeded memory threshold.
                |               |                          |          | ALARM_CLEAR | 2022-01-10T18:20:02-08:00 | JVM heap usage below memory threshold.
```

-> See the [Shoreline Events documentation](https://docs.shoreline.io/op/events) for details.

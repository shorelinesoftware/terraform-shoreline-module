# Shoreline JVM-Trace OpPack

This folder shows config and usage examples for the [jvm-trace OpPack](https://github.com/shorelinesoftware/terraform-shoreline-modules/tree/main/modules/ijvm-trace).  For more detailed documentation, see the [shoreline docs](https://docs.shoreline.io/).

This OpPack monitors JVM resources (nodes/pods/containers).
If the monitored java processes exceed the defined memory limit, 
data is automatically collected and pushed to remote storage for more thorough investigation.

Collected data includes:

1. Stack traces.
1. Heap dumps.
1. Garbage collection statistics.
1. Any detected deadlocks.


## Requirements

The following tools are required on the monitored resources, with appropriate permissions:

1. Java tools: jcmd, jps, jmap, jstat, jstack.
1. The Amazon `aws` CLI (for S3), or Google `gsutil` CLI (for GCS).


## Quick Start


### Module configuration

Module config example:
```hcl
  module "jvm_trace" {

    # Location of the module:
    source             = "hashicorp/shoreline/modules/jvm_trace"
  
    # Namespacing to allow multiple instances of the module, with different params:
    op_prefix          = "jvm_trace"
  
    # Resource query to select the affected resources:
    resource_query     = "jvm_pods"
  
    # Regular expresssion to select the monitored JVM processes:
    pvc_regex          = "tomcat"
  
    # Maximum memory usage, in Mb, before the JVM process is traced:
    mem_threshold      = 1000
  
    # Destination of the memory-check, and trace scripts on the selected resources:
    script_path        = "/tmp"

    # S3 or GCS storage bucket for heap dumps and stack traces
    bucket             = "s3://my_jvm_traces"

    # Frequency to evaluate alarm conditions in seconds.
    check_interval     = 60

  }

```


### Manual Command Examples

Note: These commands are for the Shoreline CLI, or Shoreline UI Notebooks.



#### Force data collection for a given set of processes:
```
op> pods | app = "tomcat" | jvm_trace_jvm_dump_stack("tomcat", "s3://my_jvm_traces")
```


#### Force data collection for a given set of processes, on a single (arbitrary) pod:
```
op> pods | app = "tomcat" | limit=1 | jvm_trace_jvm_dump_stack("tomcat", "s3://my_jvm_traces")
```


#### Manually check memory usage on a set of pods
```
op> pods | name =~ 'jvm' | jvm_trace_jvm_check_heap('ChewResources')

 ID | TYPE      | NAME                                        | REGION    | AZ         | STATUS | STDOUT                                
 70 | CONTAINER | jvm-test-bcc5cf748-xd54m.jvm-test-container | us-west-2 | us-west-2b |   1    | heap memory 1165 MB > threshold 30 MB 
    |           |                                             |           |            |        |                                       
```


#### List jvm alarms that have triggered:
```
op> events | alarm_name =~ 'jvm'

 RESOURCE_NAME  | RESOURCE_TYPE | ALARM_NAME               | STATUS   | STEP_TYPE   | TIMESTAMP                 | DESCRIPTION                                              
 jvm-test-xd54m | POD           | jvm_trace_jvm_heap_alarm | resolved |             |                           | Alarm on JVM heap usage growing larger than a threshold. 
                |               |                          |          | ALARM_FIRE  | 2022-01-10T17:16:58-08:00 | JVM heap usage exceeded memory threshold.                
                |               |                          |          | ALARM_CLEAR | 2022-01-10T18:20:02-08:00 | JVM heap usage below memory threshold.                   
```




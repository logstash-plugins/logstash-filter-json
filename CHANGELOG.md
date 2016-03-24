# 2.0.6
  - Depend on logstash-core-plugin-api instead of logstash-core, removing the need to mass update plugins on major releases of logstash
# 2.0.5
  - New dependency requirements for logstash-core for the 5.0 release
## 2.0.4
 - Added an option to configure the tags set when a `JSON` parsing error occur #20

## 2.0.3
 - Refactored field references, better timestamp handling, code & specs cleanups

## 2.0.0
 - Plugins were updated to follow the new shutdown semantic, this mainly allows Logstash to instruct input plugins to terminate gracefully,
   instead of using Thread.raise on the plugins' threads. Ref: https://github.com/elastic/logstash/pull/3895
 - Dependency on logstash-core update to 2.0


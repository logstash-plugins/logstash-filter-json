## 3.2.1
  - Fix tag on failure test [#52](https://github.com/logstash-plugins/logstash-filter-json/pull/52)

## 3.2.0
 - Feat: check target is set in ECS mode [#49](https://github.com/logstash-plugins/logstash-filter-json/pull/49)
 - Refactor: logging improvements to print event details in debug mode

## 3.1.0
 - Added better error handling, preventing some classes of malformed inputs from crashing the pipeline.

## 3.0.6
  - Updated documentation with some clarifications and fixes

## 3.0.5
  - Update gemspec summary

## 3.0.4
  - Fix some documentation issues

## 3.0.2
  - Relax constraint on logstash-core-plugin-api to >= 1.60 <= 2.99

## 3.0.1
 - internal: Republish all the gems under jruby.

## 3.0.0
 - internal,deps: Update the plugin to the version 2.0 of the plugin api, this change is required for Logstash 5.0 compatibility. See https://github.com/elastic/logstash/issues/5141

## 2.0.6
 - internal,deps: Depend on logstash-core-plugin-api instead of logstash-core, removing the need to mass update plugins on major releases of logstash

## 2.0.5
 - internal,deps: New dependency requirements for logstash-core for the 5.0 release

## 2.0.4
 - feature: Added an option to configure the tags set when a `JSON` parsing error occur #20

## 2.0.3
 - internal,cleanup: Refactored field references, better timestamp handling, code & specs cleanups

## 2.0.0
 - internal: Plugins were updated to follow the new shutdown semantic, this mainly allows Logstash to instruct input plugins to terminate gracefully,
   instead of using Thread.raise on the plugins' threads. Ref: https://github.com/elastic/logstash/pull/3895
 - internal,deps: Dependency on logstash-core update to 2.0


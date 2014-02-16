Shepherd
========

Shepherd is an anomaly detection system for any kind of time series metrics that can be accessed via API in an hourly, daily, weekly and/or monthly basis. Today, it only supports pulling metrics from Librato (metrics.librato.com), but other APIs will be supported in the future.

The results of the analysis are displayed in the form of queryable heatmaps, where every square represents a metric. Each square is colored in white if the metric is within the expected bounds, in red if it is below the expected and in green if it is above the expected.

Shepherd consists of a MySQL database that stores all observed anomalies; Two daemon scripts: the Manager and the Worker (the latter executing multiple threads), that schedule all the metric checks, execute them and store the results in the DB; A Redis instance, which acts as a queue service to permit communication between Manager and Worker scripts; And finally a web application in Rails that shows the heatmaps to the end user.

The system is designed to be scalable, so that many Worker scripts can be executed in different machines; And concurrent safe, so any failure in the Manager or Worker scripts or the Redis mediator will not corrupt the other elements and lead to false positives or negatives.

The metric analysis is done using the statistical bootstrapping technique. It also takes into account various other aspects like metric seasonality and giving more weight to recent data.

Shepherd
========

Shepherd is an **anomaly detection system** for any kind of **time series metrics** that can be accessed via API in an hourly, daily, weekly and/or monthly basis. Today, it only supports **pulling metrics from Librato** (metrics.librato.com), but **other APIs will be supported in the future**.

The results of the analysis are displayed in the form of **queryable heatmaps**, where every square represents a metric. Each square is colored in white if the metric is within the expected bounds, in red if it is below the expected and in green if it is above the expected.

Shepherd consists of a **MySQL database** that stores all observed anomalies; Two **daemon scripts**: the Manager and the Worker (the latter executing multiple threads), that schedule all the metric checks, execute them and store the results in the DB; A **Redis** instance, which acts as a queue service to permit communication between Manager and Worker scripts; And finally a **web application in Rails** that shows the heatmaps to the end user.

The system is designed to be **scalable**, so that many Worker scripts can be executed in different machines; And **concurrent safe**, so any failure in the Manager or Worker scripts or the Redis mediator will not corrupt the other elements and lead to false positives or negatives.

The metric analysis is done using the **statistical bootstrapping** technique. It also takes into account various other aspects like metric **seasonality** and giving more weight to recent data.

Usage
-----

**1. Watch metrics**

To make Shepherd start watching a list of metrics, use:

> rake shepherd:watch[librato-api-username,librato-api-password,librato-metric-wildcard]

The username and password are specified in the Librato account page, and the metric wildcard is the same that you can use in the metric selector in the same Librato system. If you want to watch a single metric, use its whole name, and the wildcard will just match it.

**2. Unwatch metrics**

To make Shepherd stop watching a list of metrics, use:

> rake shepherd:unwatch[regular-expression]

This time, as only Shepherd is evaluating the expression, you can use a regular expression to pick the metrics you want to stop watching.

**3. Start/stop Shepherd**

This task will start the Manager and Worker daemons in the current machine. Be shure you have Redis installed and running.

> rake shepherd:start

After that, Shepherd will start checking the metrics that are being watched and storing the results in the DB, so that they can be accessed by the web application. To stop the daemons, use:

> rake shepherd:stop

**4. Clear state**

This will clear all the anlysis results in MySQL and the queues in Redis, reseting the system. The watched metrics are not cleared.

> rake shepherd:clear

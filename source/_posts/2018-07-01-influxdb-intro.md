---
layout: post
title: InfluxDB 简介
tags: [influxdb, metrics]
---

基于 InfluxDB v1.5

本文更新时间

 - 2018-07-01: 初版

What
---

InfluxDB 是时间序列数据库的一种，TSDB 来自维基的定义

> A time series database (TSDB) is a software system that is optimized for handling time series data, arrays of numbers indexed by time (a datetime or a datetime range).

它适合用于保存大量的与时间相关的数据，例如温度变化，股票指数，如

```
temperature,sensor=a,zone=city val=39.0 1422568543702900257
temperature,sensor=b,zone=city val=39.1 1422568543702900258
temperature,sensor=a,zone=city val=39.0 1422568543702900259
temperature,sensor=b,zone=city val=38.9 1422568543702900260
temperature,sensor=a,zone=city val=39.0 1422568543702900261
temperature,sensor=b,zone=city val=39.0 1422568543702900262
```

目前常用于作为监控系统的数据源，与之类似的还有 [Prometheus](https://prometheus.io/)。

### Concepts

下面是 InfluxDB 的相关概念

Fields

 - 数据域，每一行数据至少需要带一个 Field，数值，布尔或者字符串类型
 - 对数据域的过滤（大于，小于或者在某个范围内）是不经过索引，所有的操作都是全表扫描

Tags

 - 可选项，存储时都是字符串类型
 - 索引项，用于数据的分类

Measurements

 - 包含 fields, tags 和其对应的 timestamp
 - 含有相同的 tag 的在同一个 measurement 的数据称为 serie

Point

 - 一条记录，即包含 measurement, tags, fields
 - 使用 API 使用 Line Protocol 格式提交数据，可以包含 5000 到 10000 的 points

与 RDBS 相比，database 概念是类似的，InfluxDB 下的 Measurement 则是对应 table, Tags 则是类似于 multiple-column indexes，Field 则是普通的 Column。

### Line Protocol

外部与 InfluxDB 交互的格式，其语法如下：

```
# <measurement>[,<tag_key>=<tag_value>[,<tag_key>=<tag_value>]] <field_key>=<field_value>[,<field_key>=<field_value>] [<timestamp>]
http,ver=2.6,modules=content,action=sync,type=consume val=10
```

How
---

### Schema Design

最主要需要记住

> tags are indexed, and field are not indexed

*For Tag*

 - tag 应该是有限的数据集（http status code, region, or version）
 - tag 的数据应该是只包含一种信息，而不是复合的信息

复合的信息如 `name=us.android.4-0-4`，使用这类数据在后期的查询中只能通过正则进行区分，这里应该使用 `country=us,os=android,ver=4-0-4`。

在前文提过，不同的 tag 的值 field 以一个 serie 来存储，假如你有 2 个 tag，每个 tag 有 N 种不同的值，则最终会有 N ^ 2 个 serie。

因为 InfluxDB 是基于 serie 来做索引，如果在 tag 中插入 UUID 或者随机数一类不确定范围的数据，则会导致 series 数量膨胀导致内存中维护的索引增多，造成系统负载升高。

所以在设计 Schema 的时候需要认真考虑 Tag 的数量和总体的数量。

*For Measurement*

 - 同 Tag 一样，不应该包含复合的信息

*For Field*

 - field 的数据没有 index，并且可以在其之上用 function（sum, avg or max），则 field 更应存能表示变化的数据

### Hardware

在单个实例和集群的选择上，官网的 [文档](https://docs.influxdata.com/influxdb/v1.5/guides/hardware_sizing/#general-hardware-guidelines-for-a-single-node) 说明了集群和单实例的硬件要求。

单个实例的处理上限为

 - 每秒最多 250K 个 Field 的写入
 - 每秒查询小于 25 次
 - series 数量不超过 100W

上述的硬件推荐配置 4-6 核 CPU，8-32 GB 内存，磁盘性能在 500-1000 IOPS（作为参考，7200 转的机械硬盘的 IOPS 在 200 左右）。根据文档所说，InfluxDB 是设计在 SSD 上使用，他们 *没有* 在机械硬盘上进行过测试。

开源版的集群方案停留在 `0.11`，之后 InfluxDB 将集群作为企业版的特性，为其加入高可用的支持。

### Downsampling and data-retention

data-retention （RP）是数据保存的策略。

默认情况下，数据保存是不过期。可以通过自己设置相应的 RP 去覆盖默认的数据来达到定期删除的功能。

```
> CREATE RETENTION POLICY "two_hours" ON "db" DURATION 2h REPLICATION 1 DEFAULT
```

Continuous Query (CQ) 则是定期跑的 SQL-like 的命令，用于 downsample 数据（如实时采集，30 分钟做一次求平均到另一个表）。

```
> CREATE CONTINUOUS QUERY "cq_30m" ON "db" BEGIN
  SELECT mean("website") AS "mean_website",mean("phone") AS "mean_phone"
  INTO "a_year"."downsampled_orders"
  FROM "orders"
  GROUP BY time(30m)
END
```

通过设置 RP 来设置原始数据的过期时间，再通过 CQ 设置按不同维度定时聚合到

### API

```
curl -i -XPOST 'http://localhost:8086/write?db=mydb' --data-binary 'm,a=1,b=2 c=3,d=4'
```

InfluxDB 提供 HTTP 的 API，可以通过 POST 进行数据的更新，需要指定 database，schema 是没有限制的。你需要的是先创建相应的 database。

```
curl -i -XPOST http://localhost:8086/query --data-urlencode "q=CREATE DATABASE mydb"
```

多行的数据以换行进行分隔，最好是每个数据加上 timestamp，否则 InfluxDB 收到数据时会以服务器上的时间来记录。

Conclusion
---

适合于

 - 数据与时间相关，并且数据按时间顺序添加，对数据批量添加也很友好
 - 更新 / 删除操作少，着重于最近一段时间的读取
 - 数据的重点在于趋势，而不是某个具体的点的数值

不擅长

 - UUID 或者随机数标记某一个操作的存储
 - 联合其它的 database 或者 measurement 进行查询

### Grafana

InfluxDB 本身作为数据源，配合 [Grafana](https://grafana.com/) 就可以做出一个可配置的监控平台，也可以根据某些值进行报警（基于 Webhook）。

References
---

 1. http://liubin.org/blog/2016/02/18/tsdb-intro/
 2. https://db-engines.com/en/ranking/time+series+dbms
 3. https://grafana.com/blog/2016/01/05/logs-and-metrics-and-graphs-oh-my/
 4. https://docs.influxdata.com/influxdb/v1.5/concepts/storage_engine/#storage-engine
 5. [实现细节](https://github.com/influxdata/influxdb/blob/master/tsdb/engine/tsm1/DESIGN.md)

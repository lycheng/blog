---
layout: post
title: MySQL 分区实践
tags: [mysql, partitions]
---

在项目中有需要优化之前有涉及分区的表，这里记录下不同的分区方法的相关测试。

基础
---

在未来，native 的分区功能会被移除，只有在 InnoDB 和 NDB 才会继续保存该功能，本文是以 InnoDB 为例进行说明。简单来说，分区是指在根据表的某种用户自定义的规则，将数据分到不同的物理存储的文件中。在外部看来，这个表还是一样的，只是在 query 的时候，会根据具体的分区规则查询具体的分区。

hash
---

```sql
CREATE TABLE IF NOT EXISTS `origin` (
    a bigint(20) NOT NULL DEFAULT '0',
    b bigint(20) UNSIGNED NOT NULL,
    c int(10) UNSIGNED NOT NULL,
    d int(10) UNSIGNED NOT NULL,
    e tinyint(4) UNSIGNED NOT NULL,
    f bigint(20) UNSIGNED NOT NULL,
    g char(2) NOT NULL,
    h date NOT NULL,
    PRIMARY KEY (`a`,`b`,`c`,`d`,`e`,`f`,`g`,`h`) USING BTREE,
    KEY `aid-country` (`a`,`g`) USING BTREE,
    KEY `ctid-country` (`b`,`g`) USING BTREE,
    KEY `product-country` (`c`,`g`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8
PARTITION BY LINEAR HASH (YEAR(`h`) * 10000 + MONTH(`h`) * 100 + DAY(`h`))
PARTITIONS 8;
```

旨在优化的原始表的大体结构如上。里面的字段与实际表相比，只是少了部分的数据字段，索引和分区策略是一样的。当前的问题是，在这样子的分区策略下，查询的效率低下（特别是对 h 字段的跨日 \ 跨月查询），常见的是会去通过 h 做范围查询。

```
mysql> explain select * from origin where c = 1 and g = 'AD' and h = '2017-01-02' limit 1 \G;
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: origin
   partitions: p6
         type: ref
possible_keys: product-country
          key: product-country
      key_len: 10
          ref: const,const
         rows: 5
     filtered: 10.00
        Extra: Using where; Using index
1 row in set, 1 warning (0.00 sec)
```

```
mysql> explain select * from origin where c = 1 and g = 'AD' and h > '2017-01-02' limit 1 \G;
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: origin
   partitions: p0,p1,p2,p3,p4,p5,p6,p7
         type: ref
possible_keys: product-country
          key: product-country
      key_len: 10
          ref: const,const
         rows: 45
     filtered: 33.33
        Extra: Using where; Using index
1 row in set, 1 warning (0.00 sec)
```

origin 表的测试数据为 99999 条，上面的结果可以看到，两个语句都能使用到索引，但是不同的是，后者需要扫所有的分区，以至于其所扫的 rows 比前者多。这里我们可以得出结论

 1. hash 分区的字段不适合范围或者比较查询，如果在 where 条件中涉及到 hash；
 2. 所涉及的字段，应该使用相等判断（不等于也不行）索引是在分区之后的数据范围内查询。

上述的测试结果与我们日常的使用经验相吻合，我们希望找到方法可以做范围查询。
 
range 分区
---

```sql
CREATE TABLE IF NOT EXISTS `month_field` (
    a bigint(20) NOT NULL DEFAULT '0',
    b bigint(20) UNSIGNED NOT NULL,
    c int(10) UNSIGNED NOT NULL,
    d int(10) UNSIGNED NOT NULL,
    e tinyint(4) UNSIGNED NOT NULL,
    f bigint(20) UNSIGNED NOT NULL,
    g char(2) NOT NULL,
    h date NOT NULL,
    m int(10) NOT NULL,
    PRIMARY KEY (`a`,`b`,`c`,`d`,`e`,`f`,`g`,`h`, `m`) USING BTREE,
    KEY `aid-country` (`a`,`g`) USING BTREE,
    KEY `ctid-country` (`b`,`g`) USING BTREE,
    KEY `product-country` (`c`,`g`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8
PARTITION BY RANGE(m) (
    PARTITION p0 VALUES LESS THAN (201701),
    PARTITION p1 VALUES LESS THAN (201702),
    PARTITION p2 VALUES LESS THAN (201703),
    PARTITION p3 VALUES LESS THAN (201704),
    PARTITION p4 VALUES LESS THAN (201705),
    PARTITION p5 VALUES LESS THAN (201706),
    PARTITION p6 VALUES LESS THAN (201707),
    PARTITION p7 VALUES LESS THAN MAXVALUE
);
```

上述 SQL 是另一种分区模式，通过 range 分区，与 hash 不同的是，其需要指定某些字段具体的范围确定到某个分区。month_field 这个表与之前的相比，只是加多了一个 m 字段来存相应的月份的信息，如 201701。

这里需要注意的是这个新增的 m 字段也加到了主键中，原因是 MySQL  本身有约束，用于分区的字段，[必须在所有的唯一索引列](https://dev.mysql.com/doc/refman/5.7/en/partitioning-limitations-partitioning-keys-unique-keys.html)。
 
> every unique key on the table must use every column in the table's partitioning expression.

下面测试范围查找和精确查找

```
mysql> explain select * from month_field where c = 1 and g = 'AD' and m <= 201703 limit 1 \G;
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: month_field
   partitions: p0,p1,p2,p3
         type: ref
possible_keys: product-country
          key: product-country
      key_len: 10
          ref: const,const
         rows: 2
     filtered: 33.33
        Extra: Using where; Using index
1 row in set, 1 warning (0.00 sec)
```

```
mysql> explain select * from month_field where c = 1 and g = 'AD' and m = 201703 limit 1 \G;
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: month_field
   partitions: p3
         type: ref
possible_keys: product-country
          key: product-country
      key_len: 10
          ref: const,const
         rows: 1
     filtered: 10.00
        Extra: Using where; Using index
1 row in set, 1 warning (0.00 sec)
```

第一个查询可以看出来，对其是用范围查询，也能根据分区策略只查对应的分区而不用像 hash 那样去扫全部的分区。同样的精确查找能去到指定的分区。与 hash 相比，这种分区策略适合有范围并且分布均衡的数据。后期也可以根据需要定期扩展分区。

range 中二次计算
---

```sql
CREATE TABLE IF NOT EXISTS `origin` (
    a bigint(20) NOT NULL DEFAULT '0',
    b bigint(20) UNSIGNED NOT NULL,
    c int(10) UNSIGNED NOT NULL,
    d int(10) UNSIGNED NOT NULL,
    e tinyint(4) UNSIGNED NOT NULL,
    f bigint(20) UNSIGNED NOT NULL,
    g char(2) NOT NULL,
    h date NOT NULL,
    PRIMARY KEY (`a`,`b`,`c`,`d`,`e`,`f`,`g`,`h`) USING BTREE,
    KEY `aid-country` (`a`,`g`) USING BTREE,
    KEY `ctid-country` (`b`,`g`) USING BTREE,
    KEY `product-country` (`c`,`g`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8
PARTITION BY RANGE(YEAR(`h`)*100 + MONTH(`h`)) (
    PARTITION p0 VALUES LESS THAN (201701),
    PARTITION p1 VALUES LESS THAN (201702),
    PARTITION p2 VALUES LESS THAN (201703),
    PARTITION p3 VALUES LESS THAN (201704),
    PARTITION p4 VALUES LESS THAN (201705),
    PARTITION p5 VALUES LESS THAN (201706),
    PARTITION p6 VALUES LESS THAN (201707),
    PARTITION p7 VALUES LESS THAN MAXVALUE
);
```

这里有一种特殊情况，在 range 中的值如果是是通过某些字段的值二次运算算出来的话，范围查询时也是会扫所有的分区。

```
mysql> explain select * from origin where c = 1 and g = 'AD' and h >= '2017-06-24' limit 1 \G;
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: origin
   partitions: p0,p1,p2,p3,p4,p5,p6,p7
         type: ref
possible_keys: product-country
          key: product-country
      key_len: 10
          ref: const,const
         rows: 43
     filtered: 33.33
        Extra: Using where; Using index
1 row in set, 1 warning (0.00 sec)
```

list 分区
---

```sql
CREATE TABLE IF NOT EXISTS `list` (
    a bigint(20) NOT NULL DEFAULT '0',
    b bigint(20) UNSIGNED NOT NULL,
    c int(10) UNSIGNED NOT NULL,
    d int(10) UNSIGNED NOT NULL,
    e tinyint(4) UNSIGNED NOT NULL,
    f bigint(20) UNSIGNED NOT NULL,
    g char(2) NOT NULL,
    h date NOT NULL,
    m int(10) NOT NULL,
    PRIMARY KEY (`a`,`b`,`c`,`d`,`e`,`f`,`g`,`h`, `m`) USING BTREE,
    KEY `aid-country` (`a`,`g`) USING BTREE,
    KEY `ctid-country` (`b`,`g`) USING BTREE,
    KEY `product-country` (`c`,`g`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8
PARTITION BY LIST COLUMNS(m) (
    PARTITION p0 VALUES IN (201701, 201702, 201703, 201704, 201705, 201706, 201707, 201708, 201709, 201710, 201711, 201712),
    PARTITION p1 VALUES IN (201801, 201802, 201803, 201804, 201805, 201806, 201807, 201808, 201809, 201810, 201811, 201812),
    PARTITION p2 VALUES IN (201901, 201902, 201903, 201904, 201905, 201906, 201907, 201908, 201909, 201910, 201911, 201912),
    PARTITION p3 VALUES IN (202001, 202002, 202003, 202004, 202005, 202006, 202007, 202008, 202009, 202010, 202011, 202012),
    PARTITION p4 VALUES IN (202101, 202102, 202103, 202104, 202105, 202106, 202107, 202108, 202109, 202110, 202111, 202112),
    PARTITION p5 VALUES IN (202201, 202202, 202203, 202204, 202205, 202206, 202207, 202208, 202209, 202210, 202211, 202212)
);
```

list 的分区精确查询和范围查询都能使用其分区策略

```
mysql> explain select * from list where c = 1 and g = 'AD' and m between 201701 and 201803 limit 1 \G;
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: list
   partitions: p0,p1
         type: ref
possible_keys: product-country
          key: product-country
      key_len: 10
          ref: const,const
         rows: 12
     filtered: 11.11
        Extra: Using where; Using index
1 row in set, 1 warning (0.01 sec)
```

从建表语句可以看到，分区的字段的值是明确的，如果插入的数据不在指定的数据内，会报错。与 range 相比，你的数据分区可以由你自己指定，但是不能选择 MAXVALUE 类似的值，所以你必须提前规划好所有可能的值，包括是否分配均匀也是由自己确定。

```
mysql> insert into list values (1, 2 ,3 ,4, 5, 6, 'CN', '2050-06-06', 205006);
ERROR 1526 (HY000): Table has no partition for value from column_list
```

写在后面
---

在分区之后，也可以通过相应的语句查询分区是否平均

```

mysql> select PARTITION_NAME, TABLE_ROWS FROM INFORMATION_SCHEMA.PARTITIONS where table_name = 'origin';
+----------------+------------+
| PARTITION_NAME | TABLE_ROWS |
+----------------+------------+
| p0             |      11520 |
| p1             |      13152 |
| p2             |      13152 |
| p3             |      12640 |
| p4             |      11472 |
| p5             |      12911 |
| p6             |      12864 |
| p7             |      12288 |
+----------------+------------+
```

这里主要讲了三种分区策略，其实 hash 还包括另一种简单的 hash ，我测试中用的是 liner hash，可以理解为更为平均的 hash，文档可见 这里。三种分区的策略简单如下

 - hash：适用于数据范围较分散或者说暂不明确上下限，最后的查询也不涉及范围查询的情况；
 - range：适合于数据需要范围查询的，并且需要数据的分布也分区的字段有关；
 - list：适用于数据范围明确的，数据范围需要自己去控制。

与 hash 相比，range 和 list 也都是后期通过增加相应的分区而不移动数据的，如果是 hash 修改分区策略的话就会涉及到数据的移动

```
mysql> alter table `origin` partition by linear hash(YEAR(`h`)) partitions 2;
Query OK, 99999 rows affected (15.25 sec)

mysql> alter table `list` ADD partition (partition p6 values IN (202301, 202302));
Query OK, 0 rows affected (0.94 sec)
Records: 0  Duplicates: 0  Warnings: 0
```

还有需要注意的是，如果在 range 中使用了 MAXVALUE 的话，该分区必须是最后一个分区的定义，并且你也不能往这个表加分区了

```
mysql> alter table `month_field` ADD partition (partition p61 values less than(201708));
ERROR 1481 (HY000): MAXVALUE can only be used in last partition definition
```


参考
---

 1. [MySQL 5.7 分区模块文档](https://dev.mysql.com/doc/refman/5.7/en/partitioning.html)
 2. [分区，分表，分库的应用场景](http://haitian299.github.io/2016/05/26/mysql-partitioning/)
 3. [修改 MySQL 表分区](https://dev.mysql.com/doc/refman/5.7/en/alter-table-partition-operations.html)

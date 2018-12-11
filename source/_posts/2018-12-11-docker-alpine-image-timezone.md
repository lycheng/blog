---
layout: post
title: Docker 容器时区设置
tags: [docker, java, timezone]
---

使用 Docker 部署 Java 程序时发现时区有问题，这里记录下这期间折腾的记录。

背景
---

基础镜像为 `openjdk:8-jre-alpine`，复制打包后生成的 jar 文件进去运行程序。

这个镜像默认的配置如下

```
$ docker run -it --rm openjdk:8-jre-alpine /bin/sh
/ # date
Tue Dec 11 01:41:09 UTC 2018
/ # cat /etc/localtime
TZif2UTCTZif2UTC
UTC0
```

测试
---

以下是用来测试的 Dockerfile

```
FROM openjdk:8-jre-alpine

# RUN apk add --no-cache tzdata && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "Asia/Shanghai" > /etc/timezone

# ENV TZ Asia/Shanghai

COPY ./target/tz-1.0-SNAPSHOT.jar main.jar
CMD /usr/bin/java -jar main.jar
```

测试用的 Java 程序

```java
package com.lycheng.tz;

import java.time.Instant;
import java.util.Date;
import java.util.TimeZone;

public class Main {

    public static void main(String[] args) {
        Instant instant = Instant.now();
        System.out.println(instant);

        TimeZone tz = TimeZone.getDefault();
        System.out.println(tz.getDisplayName());
        Date date = new Date();
        System.out.println(date);
    }
}
```

上述两行注释都是可用的

```
> docker run --rm -it $(docker build -q .)

2018-12-11T03:39:17.927Z
China Standard Time
Tue Dec 11 11:39:18 CST 2018
```

以上就是 [alpine issue][1] 中提及的方法，原因是 alpine 这个基础镜像是很精简的，原镜像不包含时区信息，需要额外安装。

此外，你也可以在代码中设置时区

```java
TimeZone.setDefault(TimeZone.getTimeZone("Asia/Shanghai"));
```

在搜索的时候也发现另外的好玩的方法，就是使用宿主机本身的 /etc/localtime

```
docker run -v /etc/localtime:/etc/localtime:ro -v /etc/timezone:/etc/timezone:ro -it --rm openjdk:8-jre-alpine /bin/sh
```

这样子能减少 image 的大小，又不需要另外设置时区信息。而 ubuntu 的镜像除了设置环境变量 TZ 外还需要别的配置才行，详见 [这里][2]

参考
---

  - [alpine issue][1]
  - [docker-timezone-in-ubuntu-16-04-image][2]


  [1]: https://github.com/gliderlabs/docker-alpine/issues/136
  [2]: https://stackoverflow.com/questions/40234847/docker-timezone-in-ubuntu-16-04-image

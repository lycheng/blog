---
layout: post
title:  Docker 简要记录
tags: [docker]
---

## 安装

docker 目前在 ubuntu apt 上面的版本官方并不维护，需要手动添加它的源才比较好。详细的官方文档可见 [这里](https://docs.docker.com/engine/installation/linux/ubuntulinux/)。

因为国外的 docker registry 太慢，所以可以选择国内的服务 [daocloud](https://get.daocloud.io/) 来进行加速。常用的镜像都能很快的下载。当然有能力的可以选择自己搭建私有的 registry。

安装之后可以看 docker 是否已经启动

```sh
sudo systemctl status docker
```

### 安装镜像

```
sudo docker pull hello-world
# OR
dao pull hello-world
```

上面两者是等效的，默认的 tag 都是 latest。安装之后可以列出 images 来查看

```
sudo docker images
```

## 使用

### 镜像操作

```
# 删除镜像
# 前提是没有正在运行的相关容器
sudo docker rmi <image>:<tag>
```

在镜像安装的时候可以看到这样的东西

```
Pulling repository library/redis:2.8

128182e1e85d: Download complete
7f1aa6a73799: Download complete
1a9852d2edd3: Download complete
a3ed95caeb02: Download complete
fbe8a4f1aa87: Download complete
b94de088b6d8: Download complete
6c8ccd839b1d: Download complete
0fded1c9651d: Download complete
51f5c6a04d83: Download complete
```

上面的的每一行代表镜像的每一层（layer），仅可读，表示镜像那时候的文件系统的不同。在创建新的容器的时候，则在最新的层上面创建一层可读可写的容器层。如果把做了的修改保存下来，则就是新的层，这个 image 就更新了。

### 容器操作

```shell
# 加载镜像到容器中
# 每执行以此就有一个新的容器
# 有一大堆参数指定各种例如网络，存储的信息
sudo docker run <image>:<tag>

# daemon 的形式来跑服务
sudo docker run -d <image>:<tag>

# 列出容器信息
# -a 表示所有的容器，如果去掉则仅仅是正在运行的容器
sudo docker ps -a

# 删除容器
sudo docker rm <id>

# 删除已经退出的容器
sudo docker rm `sudo docker ps -aq -f status=exited`
```

### docker-compose

docker-compose 是 docker 用来管理多个容器的工具。通过配置文件定义容器的参数，相应容器的依赖，对外的端口等等。

它的配置文件大概会长这样

```yml
redash:
  image: redash/redash:latest
  ports:
    - "5000:5000"
  links:
    - redis
    - postgres
  environment:
    REDASH_STATIC_ASSETS_PATH: "../rd_ui/dist/"
    REDASH_LOG_LEVEL: "INFO"
    REDASH_REDIS_URL: "redis://redis:6379/0"
    REDASH_DATABASE_URL: "postgresql://postgres@postgres/postgres"
    REDASH_COOKIE_SECRET: veryverysecret
redis:
  image: redis:2.8
postgres:
  image: postgres:9.3
  volumes:
    - /opt/postgres-data:/var/lib/postgresql/data
redash-nginx:
  image: redash/nginx:latest
  ports:
    - "80:80"
  links:
    - redash
```

之后保存配置文件 `docker-compose.yml` 然后在当前的目录

```sh
sudo docker-compose up

# 单独启用其中某个服务
sudo docker-compose up postgres
```

## root

容器内部的用户是 root，跟宿主的 root 是不同的。默认的情况下，run 参数 `--privileged=false`，同是 root 用户，但却不是所有的权限。可以基本不用担心安全问题。

到如果设置为 true 的话，问题就大了

> 由于 Docker 容器与宿主机处于共享同一个内核操作系统的状态，因此，Docker 容器将完全拥有内核的管理权限

## 参考

1. [官方文档](https://docs.docker.com/engine/understanding-docker/)
2. [docker 的存储的相关概念](https://docs.docker.com/engine/userguide/storagedriver/imagesandcontainers/)
3. [docker compose](https://docs.docker.com/compose/overview/)
4. [docker root 安全问题](http://docs.daocloud.io/allen-docker/docker-root)

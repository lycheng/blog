---
layout: post
title: Nginx stream debug
tags: [nginx, tcp, proxy, traefik]
---

由于客户需要做 IP 白名单，所以我们在 AWS 建了两个 EC2 然后做了个 Nginx TCP Proxy，对应的 upstream 是 AWS 的 API Gateway。Nginx 最开始的版本类似于

```
user  nginx;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

stream {
    listen 80;
    proxy_pass www.example.com:8080;
}
```

这种白名单的流量的走向大概是

domain -> CNAME to AWS ELB -> ELB forward to EC2 -> EC2 Nginx upstream to AWS API Gateway

而没有白名单的流量走向

domain -> AWS API Gateway

逻辑上是没有问题的，然后问题就出现了

## SSL issues

> hostname 'xxx' doesn't match either of '*.yyy.net', 'yyy.net'

初看之下是证书不匹配的问题，xxx 对应我们自己的做了静态 IP 的域名，而 yyy.net 对应的是一些别的公司的域名。

这里我的看法是，因为 Nginx 的 upstream 对应的是 AWS API Gateway，如果域名后面的 IP 变了，而你还连着原来的 IP 就会有类似的问题，我自己也测试过，只要你改了域名的指向，Nginx 还是会连着旧的 IP，除非你手动 reload 或者 restart Nginx。

## Resolver

搜索了一圈，这个 [回答](https://serverfault.com/questions/240476/how-to-force-nginx-to-resolve-dns-of-a-dynamic-hostname-everytime-when-doing-p/593003#593003) 比较接近正确答案了。那时候去试了下这个配置，发现 set 是不能用在 stream 的 module 里面的，而有些回答也提出了在 upstream 处设置 resolver，但 stream 的 upstream 是不能设置 resolver 的。

这时的配置类似于

```
user  nginx;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

stream {
    resolver 8.8.8.8 valid=60s;
    listen 80;
    proxy_pass www.example.com:8080;
}
```

结果是运行起来没问题，但是一段时间 DNS 记录变了之后，还是会出现 SSL 证书问题。

[这篇文章](https://medium.com/driven-by-code/dynamic-dns-resolution-in-nginx-22133c22e3ab) 也提到类似的方式，还提了一点

> Nginx evaluates the value of the variable per-request, instead of just once at startup. By setting the address as a variable and using the variable in the `proxy_pass` directive, we force Nginx to resolve the correct load balancer address on every request.

这一点在我看来是十分诡异的，通过设置变量而不是直接配置的形式就能让 Nginx 每次请求再单独解析 DNS 记录。

## Traefik

当时试了几种方法无果，想着要不换个软件试下好了，就试了下 Traefik，配置如下

```yaml
version: '3'

services:
  traefik:
    image: traefik:v2.2
    ports:
     - "8080:80"
    volumes:
    - ./traefik.toml:/etc/traefik/traefik.toml
    - ./tcp-proxy.toml:/etc/traefik/tcp-proxy.toml
```

```toml
# traefik.toml
[entryPoints]
  [entryPoints.api]
    address = ":80"

[providers.file]
  filename = "/etc/traefik/tcp-proxy.toml"
```

```toml
# tcp-proxy.toml
[tcp.routers]
  [tcp.routers.api]
    entryPoints = ["api"]
    rule = "HostSNI(`*`)"
    service = "api"

[tcp.services]
  [tcp.services.api.loadBalancer]
    [[tcp.services.api.loadBalancer.servers]]
      address = "www.example.com:8080"
```

不幸的是，本地测试能复现 Nginx 上的问题，如 [issues/5675](https://github.com/containous/traefik/issues/5675)。其实这里也可以看到，与 DNS cache 或者缓存没有什么关系，而是在建立连接时用了这个 IP，后续并没有去更新。

> Expected behavior: When the remote end dies or is rebuilt, the proxy gets timed out and a new one gets brought up.
>
> Actual behavior: all connections to this load balancer fail for eternity (we left it for an hour and it was still broken) until traefik is restarted and a new connection is instantiated with the correct IP.

## Solution

最后的解决方法来源于 [这里](https://www.dosarrest.com/ddos-blog/nginx-with-stream-module-dynamic-upstream-cname/)。因为在 stream 中无法使用 set，那么我们就用 map 来代替吧

```
user  nginx;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

stream {

    map $server_port $tcp_cname {
        80 "www.example.com:8080";
    }

    server {
        resolver 8.8.8.8 valid=60s;
        listen 80;
        proxy_pass $tcp_cname;
    }
}
```

这种解决方法真是一点都高兴不起来。这应该是一种能 work 的方案，好像是解决了问题。但在这一系列的 debug 中，最大的问题是 Nginx 在 stream 和 http 两种 module 中有配置不一致的情况，两种看似等效的方式也能得出不同的结果。

除此以外，当时想着要换成 traefik 的原因是这篇 [文章](https://tenzer.dk/nginx-with-dynamic-upstreams/)，里面有提到

> One way to solve this problem is to pay for Nginx Plus which adds the resolve flag to the server directive in an upstream group. That will make Nginx honour the TTL of the DNS record and occasionally re-resolve the record in order to get an updated list of servers to use.

## References

* http://nginx.org/en/docs/stream/ngx_stream_core_module.html#resolver
* http://nginx.org/en/docs/http/ngx_http_core_module.html
* https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/how-elastic-load-balancing-works.html#request-routing

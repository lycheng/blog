---
layout: post
title: About SSL And TLS
tags: [nginx, security, ssl, tls, https]
---

本文旨在简要介绍关于 SSL / TLS 的知识

## Base

TLS 是 SSL 的迭代版本，SSL 自从 3.0 之后便不再开发，TLS 1.0 为其继任者，目前最新版本为 TLS 1.3，而 TLS 1.0 也在 2020 年被废弃。下文统一使用 TLS 来进行说明，不进行区分 SSL / TLS。

### Handshake

TLS 连接在建立了 TCP 连接之后，首先是 TLS 握手步骤。TLS 安全性是基于非对称加密，而非对称加密对计算资源消耗十分巨大，并不适合在这种非常频繁的连接 / 数据传输操作上使用，而 TLS 的做法是先使用非对称加密进行握手，得到一个双方可信的对称加密用的秘钥，然后在此后的数据传输中都使用该秘钥来进行加密。

握手的步骤大致如下（摘自 [TLS 握手究竟做了什么？](https://zinglix.xyz/2019/05/07/tls-handshake/)）

1. 客户端发起连接，客户端带上自己产生的随机数 A 和支持的加密套件向服务器发出 `Client Hello` 请求
2. 服务器收到请求后带上自己的随机数 B 以及选择的 Cypher Suite 返回 `Server Hello` 信息。在之后服务器发送自己的证书。**此时服务器也可要求客户端出示证书**。发送完成后发送 `Server Hello Done` 信息
3. 客户端通过验证服务器证书是否可靠以决定是否继续通信，若不可信则关闭连接
4. 若认为可信客户端则会生成一个新随机数 C，称为预主密钥（Pre Master Key），用于之后生成会话密钥，通过来自于证书的公钥进行加密提供给服务器
5. 客户端会再传递一个 `Change Cipher Spec`表示之后信息会使用新的会话密钥（session keys）加密信息和哈希。然后客户端发送 `Client finished` 握手结束
6. 服务器收到数据后解密得到预主密钥，计算得出会话密钥，然后同样向客户端发送 `Change Cipher Spec`  和 `Server finished`

这里可以看到，TLS 握手阶段需要 2 个 RTT。这里面还不包括 TCP 建立连接的三次握手的时间。除此以外，步骤 3 还可能进行一次 OCSP（The Online Certificate Status Protocol） 或者 CRL（Certificate revocation list，证书吊销列表） 的请求，这些请求结果会被缓存，我们更关心的是剩下的这 2 个 RTT。

除此以外，如果断开了 TLS 连接，本身还支持连接复用机制，这样就可以减少 TLS 握手的时间损耗。

通信双方握手结束后，双方都有了用于进行对称加密的会话密钥，之后通信都使用该密钥来加密 / 解密。上述流程是基于 RSA 算法的秘钥交换，此外还有一种 DH 的算法，可参考文后的链接。

### Certificate

在上文中提到，握手阶段客户端会验证证书是否可信。在服务器发送自己的证书给到客户端时，客户端需要进行校验该证书是否合法。

一个证书包括

* **The domain name that the certificate was issued for**
* Which person, organization, or device it was issued to
* **Which certificate authority issued it**
* **The certificate authority's digital signature**
* **Associated subdomains**
* **Issue date of the certificate**
* Expiration date of the certificate
* **The public key (the private key is kept secret)**

Certificate Authority（CA）是独立的第三方，负责签发和维护 TLS 证书。证书本身带有数字签名，该数字签名使用的是其父级证书的私钥来签发，通过查询其父级证书通过其公钥即可查询出签名是否一致。而证书校验这个过程是一直递归到根证书，根证书是自签名的，这样就可以验证证书是否合法，这个链路称之为证书链（Chain of trust）。

而被信任的根证书是随着操作系统，浏览器等分发，只要客户端验证一直到根证书都没问题，则认为该证书是合法的。伪造证书的关键在于 CA 签发证书是否严谨，此外如果没有得到根证书的验证也无法得到信任。

常用的像 Fiddler 这类抓包工具，需要添加一个它自己的根证书这样才能解析 HTTPS 的流量，它自己本身就是类似于中间人攻击的角色。

### Nginx-Examples

基本的配置为

```nginx
server {
    listen              443 ssl;
    server_name         www.example.com;
    ssl_certificate     www.example.com.crt;
    ssl_certificate_key www.example.com.key;
    ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_client_certificate xxx.pem;
}
```

其中最重要的是，`ssl_certificate` 为证书地址，`ssl_certificate_key` 为私钥地址，其余则为相应的 TLS 的配置，如 TLS 的版本，使用的算法等等。除此以外还有更多的配置可用，具体可查阅 Nginx 的 http ssl module。

之前的握手阶段也提到过，服务端在返回自己的证书的时候，也可以要求客户端提供证书。客户端证书是用来校验是否是可信用户。上面有个 `ssl_client_certificate` 配置项，需要制定一个 PEM 格式的 CA 证书来验证客户端。配置了客户端证书就必须在请求是明确指定证书来请求服务端，否则就是 403 错误，常见的 HTTP Library 都支持配置证书。

## Advanced

### False-Start

之前也提到过，一次 TLS 握手至少需要 2 个 RTT。但其实，在客户端算出随机数 C 时，已经可以得出用于非对称加密用的秘钥。启用 False Start 的特性之后，可以随着 `Client finished` 返回服务端时，把实际的请求信息也带到服务端。这样算下来，TLS 握手的时间可以减少到 1 个 RTT。

### Keyless

上述的 Nginx 样例，更多是在自己源站服务端使用 TLS，而现在更多是托管于 CDN 后面，这里就需要一些另外的设置。看了下常见的公有云的文档，都是需要将自己相关域名证书私钥上传才能在 CDN 节点启用 TLS。

这样子在私钥的管理上会有问题。后来就有了 Cloudflare 提供的 Keyless 服务。其原理就是整个 TLS 握手需要解析一次客户端使用公钥加密的数据，那么只需要额外提供一个 Key Server 去帮忙解析这个加密过的数据就行。而后，我们只需要保证 CDN 节点到 Key Server 的链路是安全的，就可以保证 TLS 的安全性。

Conclusion

TLS 本身还是挺有意思的

* 对称加密的安全性有问题，于是我们使用非对称加密来加密数据
* 非对称加密不能加密太多内容，并且速度比不上对称加密，那么我们就通过非对称加密协商一个用于安全沟通的对称加密秘钥
* 握手时考虑了双方的随机数不可信的问题
* 有第三方 CA 来保证证书的安全性
* 现在有了很多硬件可以加速非对称加密 / 解密的速度

未来浏览器会逐步停止支持 HTTP 协议的网站，一点点的损耗换来安全，何乐而不为呢？参考阅读中重点推荐最后一个，比较完整的展示了 TLS 的特性。

## References

* https://zinglix.xyz/2019/05/07/tls-handshake
* https://razeencheng.com/post/ssl-handshake-detail
* https://developer.baidu.com/resources/online/doc/security/https-pratice-1.html
* https://www.cloudflare.com/learning/ssl/what-is-an-ssl-certificate/
* https://nginx.org/en/docs/http/ngx_http_ssl_module.html
* https://blog.cloudflare.com/keyless-ssl-the-nitty-gritty-technical-details/

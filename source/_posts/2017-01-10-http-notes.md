---
layout: post
title: HTTP 协议笔记
tags: [http]
---

前言
---

在这里简单讲下 HTTP 协议相关的东西，包括方法，header，API 的设计等等。

协议
---

以当前主流版本 `HTTP/1.1` 来稍微讲下一些比较重要的地方。

### URI 和 URL

- URI: Uniform Resource Identifier，统一资源标识符
- URL: Uniform Resource Locator，统一资源定位符
- URN: Uniform Resource Name，统一资源标识

URL 是一种 URI，它标识一个互联网资源，并指定对其进行操作或获取该资源的方法。可能通过对主要访问手段的描述，也可能通过网络“位置”进行标识。

URN 是基于某命名空间通过名称指定资源的 URI。人们可以通过 URN 来指出某个资源，而无需指出其位置和获得方式。

> URL 类似于住址，告诉你一种寻址方式。同样的，这也是一个 URI。URN 可以理解为某个人的名字（没有重名）。

它们的关系

![URI, URL, URN][1]

在日常开发中，很少需要区别 URL 和 URI。我们这里只讨论作为 `http` 或者 `https` 开头的各式各样的链接。每一条 URI，都是指向一个特定的资源。

### 方法

 - HEAD：与 GET 方法一样，都是向服务器发出指定资源的请求。只不过服务器将不传回资源的本文部分。它的好处在于，使用这个方法可以在不必传输全部内容的情况下，就可以获取其中“关于该资源的信息”（元信息或称元数据）。
 - GET：向指定的资源发出“显示”请求。使用 GET 方法应该只用在读取数据，而不应当被用于产生“副作用”的操作中，例如在 Web Application 中。其中一个原因是 GET 可能会被网络蜘蛛等随意访问。参见安全方法
 - POST：向指定资源提交数据，请求服务器进行处理（例如提交表单或者上传文件）。数据被包含在请求本文中。这个请求可能会创建新的资源或修改现有资源，或二者皆有。
 - PUT：向指定资源位置上传其最新内容。
 - DELETE：请求服务器删除 Request-URI 所标识的资源。

更多方法可见 [这里][2]。

最常见的就是 `GET`，`HEAD` 和 `POST` 方法。其中，就 `GET` 和 `HEAD` 方法而言，他们是安全方法，即他们的操作不应该会修改，删除指定的资源。任何的修改应该以 `GET`，`POST`，`DELETE` 来实现。

### 状态码

通过指定的方法，对某个资源进行请求，服务器就会返回对应的状态码和数据。常见的状态码如下

 - 1xx 请求已经接受，接续处理
 - 2xx 请求已经成功处理
 - 3xx 重定向，需要在继续跟进返回的数据中指定的 URI
 - 4xx 请求错误
   - 400 请求无法被服务器理解
   - 401 权限错误
   - 403 服务器理解该请求，但拒绝执行
   - 404 找不到对应的资源
   - 405 请求方法不对
 - 5xx 该请求正确，但服务器处理的时候出现问题
   - 500 未知错误
   - 501 该功能未实现
   - 502 网关或代理从上游服务器接到无效请求
   - 503 服务器当前无法处理该请求
   - 504 网关或者代理在指定时间内无法接收到上游请求，超时异常

上述的状态码和前面提到的方法，都是 HTTP 协议中定义的，但实际上服务器的行为是要通过代码实现，也就是说通过 `GET` 方法去更新，删除资源在逻辑上是没有问题的，但却是一种不推荐的行为。

### Header

以下来讲下一些比较关键的 `header` 字段

#### Content-Type

用于指定类型，如果未指定，则默认 `text/html`。API 返回的结果以 json 格式编码，则对应的 `Content-Type` 为 `application/json`。就表单而言，对应的则是 `multipart/form-data`。

#### Content-Length

返回的请求的 `body` 的大小，单位为 `bytes`。

在非持久连接中，客户端以连接关闭来界定边界。但持久连接中，必须通过指定长度来表示内容的边界。

```python
from BaseHTTPServer import BaseHTTPRequestHandler,HTTPServer

PORT_NUMBER = 8080

class myHandler(BaseHTTPRequestHandler):

    #  protocol_version = "HTTP/1.1"
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type','text/html')
        # self.send_header('Content-Length', '5')
        self.end_headers()
        self.wfile.write("Hello World !")
        return

try:
    server = HTTPServer(('', PORT_NUMBER), myHandler)
    server.serve_forever()
except KeyboardInterrupt:
    server.socket.close()
```

上述 Python 实现的简单的简单服务器，默认是 HTTP/1.0 的协议。所以不需要指定 `Content-Length`，因为它的连接是非持久的。如果指定了 HTTP/1.1 的版本，则需要指定 `Content-Length` 不然客户端不知道连接什么时候结束，一直处于 `pengdingg` 状态。

> HTTP/1.1 则规定所有连接都必须是持久的，除非显式地在请求头部加上 `Connection: close`

#### Transfer-Encoding

指的是 body 的编码形式。在 HTTP/1.1 中新增的 `Transfer-Encoding: chunked` 用于正文的分块传输。很多时候，如果每次请求都需要额外计算 body 的长度就会很耗资源，特别是动态的生成的消息。对于这种情况，可以用这种分块的形式进行传输，每个块以 CRLF 标记结束。

同时，可以结合 `Content-Encoding: gzip` 对压缩后的正文进行分块传输。

> 注意，这里的分块传输是指单次的响应消息的 body。

#### cookies

cookies 主要用于三个方面

 - 用户状态
 - 个性化设置
 - 行为追踪

在首次请求的时候，客户端是不会携带任何信息的，如果有需要，服务端需要明确自己需要保留什么信息，并在响应信息里面通过 `Set-Cookie` 返回给客户端。一个响应信息可设置多个 cookie。

`Set-Cookie` 可以通过 `Domain` 和 `Path` 的指令进行设置它的作用域，通过 `Expires` 和 `Max-Age` 来设置具体的过期时间。

如果不设置 `Domain`，该 cookie 可作用于当前的域名，但并不包括子域名。通过前置的 `.` 来包括所有的子域名。例如，`.baidu.com` 可作用域 `www.baidu.com` 和 `api.baidu.com`。而 `www.baidu.com` 的 `Domain` 设置则仅可以作用于自身。

`HttpOnly` 的选项则说明该 cookie 不能通过 JavaScript 来传输，可以一定限度的防止 `XSS`。`Secure` 的选项则说明该 cookie 只能通过 SSL 或者 HTTPS 来进行传输。

##### cookies 的使用

首先需要注意一点，任何来自用户的输入都是不可信的。因为当前用户标识是用 cookies 去做的，所以 cookies 的安全很重要。

需要注意以下几点

1. cookies 的过期时间设置尽量短，不要设置过长的时间
2. 用户修改密码之后，必须让其对应的 cookies 对应的 session 失效。
3. `HttpOnly` 和 `Secure` 的选项尽量用上
4. 如果可以的话，对 cookies 加入刷新机制
5. 不要使用 user side session

#### cache

缓存控制包括几个常见的 headers 字段

 - ETag 校验值，某个资源的版本标识（指纹），由服务器端自定义生成方式
 - If-None-Match 包含在客户端的请求中

两者的用法是，对于某个请求，服务端返回该资源的 `ETag` 信息。客户端如果需要再次请求，则需要带上该 `ETag` 并且包含另一个 `If-None-Math: <ETag>` header。如果服务器端未修改该资源，则返回 304 即可。

 - Last-Modified 当前资源的最后修改时间，包含在响应信息中
 - If-Modified-Since 客户端请求时将上次收到的 `Last-Modified` 发送到服务器进行校验

`Last-Modified` 只能精确到秒级别，如果和 `ETag` 一起使用，服务器优先校验 `ETag`，一致的情况下就会才会比对 `Last-Modified`。

 - Expires 服务端响应信息中返回，告诉客户端该资源的有效期
 - Cache-Control
   - no-cache
   - no-store
   - max-age 允许使用的最大时间，单位为秒
   - public 无条件缓存，与其他缓存限制组合使用
   - private 只允许用户浏览器等缓存，即该缓存只是私有，CDN 等中介不可缓存

`no-cache` 表示需要与服务器校验该资源是否已经更新，即可配合 `ETag` 进行使用。相反 `no-store` 则不进行任何考虑，所有的资源必须重新下载。

`Cache-Control` 和 `Expires` 字段都用在服务器的响应信息中。

> POST 请求无法被缓存

缓存的最佳实践

![URI, URL, URN][3]

#### 自定义字段

HTTP 的 `header` 是允许自定义字段的，这些字段通常用于自定义的开发来标示特定的内容，如 Facebook 的 API 的返回数据中，有包含特定的版本信息的字段

```
{'facebook-api-version': 'v2.8'}
```

RESTful API
---

RESTful 的设计其实就是最大限度的使用 HTTP 协议本身已经定义好东西，包括各种方法作为动词，URI 做为操作的对象，不同的响应信息的返回值，状态码去表示操作的结果。

### 以 Facebook Marketing API 为例

Facebook Marketing API 用于去创建在 Facebook 上投放的广告。它由四个主要部分组成。

 - Ad Account 管理不同的广告账户
 - Campaign 广告单元，从属于 Ad Account
 - Adset 广告单元，从属于 Campaign，一个 Campaign 包含多个 Adset
 - Ad 最小的广告单元，从属于 Adset，一个 Adset 可包含多个 Ad

一些的 API URI 如下

```
https://graph.facebook.com/v2.8/<ad_unit_id>
https://graph.facebook.com/v2.8/act_<ad_account_id>
```

在这里，我们可以看到，在 API 中有指定对应的版本 `v2.8`。因为 Facebook 的每一个广告单元都有独立的 id，所以上述第一条链接可以直接用于 Campaign 或者 Adset 的读取或者更新。这里，我们称 `/<ad_unit_id>` 或者 `/act_<ad_account_id>` 为 endpoint，即表示除了共同前缀的独立部分。

下面以 Adset 的一系列操作为例

 - 创建，POST 方法，endpoint 为 `/act_<ad_account_id>/adsets`
 - 读取，GET 方法，endpoint 为 `/<id>`
   - 获取实时的运营数据，GET 方法，endpoint 为 `/<id>/insights`
   - 获取 Adset 其下的 Ad，GET 方法，endpoint 为 `/<id>/ads`
 - 更新，POST 方法，endpoint 为 `/<id>`
 - 删除，POST 方法，endpoint 为 `/<id>`，在参数中指定 `status=DELETED`

大概总结下

 - 在 URI 中指定版本号
 - 操作对象本身以 id 指定，通过 URI 去访问
 - 对象的层级关系以 URI 中的 `/` 进行分隔
 - 读操作用 `GET`，写操作用 `POST`

这里跟别的 RESTful 的定义有区别，就是简化了方法，只用 `GET` 和 `POST` 来定义读写操作。

API 的返回信息很简单，通过状态码标示该次操作是否成功，不同的状态码表示不同的错误。例如 400 表示参数错误，401 表示验证错误，404 表示该资源不存在。

不管成功与否，API 调用的返回结果都会在 body 中以 json 的格式返回。如果是错误，则返回该次错误的原因。

协议演变
---

### HTTP/0.9

HTTP 最初的版本，仅支持 `GET` 方法，没有 headers，也仅能是 HTML 的内容。

### HTTP/1.0

加入了更多的方法，支持 headers 信息，支持状态码，支持更多的内容类型。

主要的问题是 HTTP/1.0 没有支持连接复用，即每次请求之后连接就会关闭，这样子下一次请求必须重新连接，即重新进行 TCP 三次握手。

后期的一些实现是通过 `Connection: keep-alive` 来复用连接，但并不是广泛地支持。

### HTTP/1.1

当前最主流的版本，连接默认是不会关闭的。需要在请求中加入 `Connection: close` 才会关闭连接。

`Host` 信息变成强制性，如果没有 `Host` 则会 400 错误。通过 `Host` 字段，我们可以在同一个服务器上部署不同的域名的网站。

`Pipelining` 的支持，在 HTTP/1.0 中，发送请求必须等待确认才行，在 HTTP/1.1 中，支持在同一个连接中发送多个请求而无需确认。这这种情况下，需要 `Content-Length` 或者分块消息 的支持来判断不同的响应消息是否结束。但即便是管道的支持，也没办法解决 [Head-of-line blocking 问题](https://zh.wikipedia.org/wiki/%E9%98%9F%E5%A4%B4%E9%98%BB%E5%A1%9E)。

支持 `Range` 对于同一个资源，可下载指定的 range bytes。

### HTTP/2

在 HTTP/2 出现之前，Google 的 `SPDY` 协议也用于解决 HTTP/1.1 的问题。现在基本上已经整合到 HTTP/2 中了。

HTTP/2 包括以下的特性

1. 二进制协议，HTTP/2 将由帧（Frames）和流（Streams）种数据组成。例如之前的 headers 和 body 将变成 `HEADERS` 和 `DATA` 帧。
2. 每一个帧都携带唯一的 stream ID 来标示，帧也有自己的 header 和 payload。
3. 多路复用，相对于 HTTP/1.1 的 pipelining，请求的发送不用依赖于顺序，可以做到异步处理，这些有赖于 stream ID 来标记不同的帧。同时，也可以支持优先级和流量控制。
4. HPACK 头信息的压缩。
5. 服务器推送。
6. 安全性的提升。


总结
---

我们可以看到，在 HTTP 的协议中，主要分 headers 和 body 两个部分。对于一次传输而言，前者定义了该请求的一些元信息，包括数据的长度，编码和类型等等，我们通过这些信息去解析对应的实际内容。

但我们能限制实现的只能是服务端，客户端的是我们无法控制的，例如不同浏览器对不同的缓存的字段的实现不同，我们能做的就是认真考虑支持各种选项，并加强对客户端请求的校验。

参考
---

 - [Journey to HTTP/2](http://kamranahmed.info/blog/2016/08/13/http-in-depth/)
 - [HTTP/2 资料汇总](https://imququ.com/post/http2-resource.html)
 - [Key differences between HTTP/1.0 and HTTP/1.1](http://www.ra.ethz.ch/cdstore/www8/data/2136/pdf/pd1.pdf)
 - [HTTP headers 字段信息](https://zh.wikipedia.org/wiki/HTTP%E5%A4%B4%E5%AD%97%E6%AE%B5%E5%88%97%E8%A1%A8)
 - [HTTP 协议中的 Transfer-Encoding](https://imququ.com/post/transfer-encoding-header-in-http.html)
 - [cookies 详解](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Cookies)
 - [Set-Cookie 详解](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Headers/Set-Cookie)
 - [关于静态资源使用不同的域名的讨论](https://www.v2ex.com/t/170974#reply49)
 - [Web 缓存机制](http://www.alloyteam.com/2012/03/web-cache-2-browser-cache/)
 - [HTTP 缓存的实践](https://developers.google.cn/web/fundamentals/performance/optimizing-content-efficiency/http-caching?hl=zh-cn)
 - [RESTful API 的参考](https://github.com/aisuhua/restful-api-design-references)
 - [Facebook Marketing API](https://developers.facebook.com/docs/marketing-api/reference)


  [1]: https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/URI_Euler_Diagram_no_lone_URIs.svg/800px-URI_Euler_Diagram_no_lone_URIs.svg.png
  [2]: https://zh.wikipedia.org/wiki/%E8%B6%85%E6%96%87%E6%9C%AC%E4%BC%A0%E8%BE%93%E5%8D%8F%E8%AE%AE#.E8.AF.B7.E6.B1.82.E6.96.B9.E6.B3.95
  [3]: https://developers.google.cn/web/fundamentals/performance/optimizing-content-efficiency/images/http-cache-decision-tree.png

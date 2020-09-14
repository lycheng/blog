---
title: Cloud Design Patterns
layout: post
tags: [engineering, architecture, nginx]
---

Link: https://docs.microsoft.com/en-us/azure/architecture/patterns/

## Ambassador

代理人模式

> Resilient cloud-based applications require features such as circuit breaking, routing, metering and monitoring, and the ability to make network-related configuration updates. It may be difficult or impossible to update legacy applications or existing code libraries to add these features, because the code is no longer maintained or can't be easily modified by the development team.

统一代理网络请求，兼容多个语言的服务，统一配置服务地址，重试，Rate limits，验证需要的配置等等。类似于 sidecar 模式，集中处理请求。也可以担任一个注册中心的角色，统一对外的请求地址，别的进程只需要配置一个地址即可。

增加了 latency，如果是同一个语言的客户端，那么一个 package 也是一个更好的选择



## Anti-Corruption Layer

防腐层设计

> Most applications rely on other systems for some data or functionality. For example, when a legacy application is migrated to a modern system, it may still need existing legacy resources. New features must be able to call the legacy system. This is especially true of gradual migrations, where different features of a larger application are moved to a modern system over time.
> Often these legacy systems suffer from quality issues such as convoluted data schemas or obsolete APIs. The features and technologies used in legacy systems can vary widely from more modern systems. To interoperate with the legacy system, the new application may need to support outdated infrastructure, protocols, data models, APIs, or other features that you wouldn't otherwise put into a modern application.

用于新老系统间的交互，防止旧系统的一些设计污染到新系统，两者中间沟通做了一个翻译层



## Asynchronous Request-Reply

异步请求 / 响应模式

> Decouple backend processing from a frontend host, where backend processing needs to be asynchronous, but the frontend still needs a clear response.

后端处理是异步的，但是前端需要及时的响应。

> One solution to this problem is to use HTTP polling. Polling is useful to client-side code, as it can be hard to provide call-back endpoints or use long running connections. Even when callbacks are possible, the extra libraries and services that are required can sometimes add too much extra complexity.

HTTP 轮询来解决问题，需要额外添加一个查询接口，用来查询任务是否已经完成，然后再调用资源接口来获取资源。
更规范的做法也可以通过一个 HTTP 302 的状态码指向真正的资源 URL。HTTP 202 状态码中也有如 Retry-After
来告知客户端请求频率



## Backends for Frontends

> Create one backend per user interface. Fine-tune the behavior and performance of each backend to best match the needs of the frontend environment, without worrying about affecting other frontend experiences.

考虑到兼容浏览器和移动设备，为两边考虑不同的接口去实现功能



## Bulkhead

类似于船舱的分隔，将问题限制在局部而不是扩散到所有的服务。

> Partition service instances into different groups, based on consumer load and availability requirements. This design helps to isolate failures, and allows you to sustain service functionality for some consumers, even during a failure.

可以根据系统的负载来进行分隔，不同类型的服务也可以放到不同的组。实际应用上如 k8s 限制内存和 CPU。

> Define partitions around the business and technical requirements of the application.



## Cache-Aside

> Applications use a cache to improve repeated access to information held in a data store. However, it's impractical to expect that cached data will always be completely consistent with the data in the data store. Applications should implement a strategy that helps to ensure that the data in the cache is as up-to-date as possible, but can also detect and handle situations that arise when the data in the cache has become stale.

Cache-Aside 的模式是

* 直接读缓存，如果缓存没有数据则去数据库查，查出来就更新到缓存中
* 涉及到更新则直接更新数据库，然后让缓存失效

那么，是不是 Cache Aside 这个就不会有并发问题了？不是的，比如，一个是读操作，但是没有命中缓存，然后就到数据库中取数据，此时来了一个写操作，写完数据库后，让缓存失效，然后，之前的那个读操作再把老的数据放进去，所以，会造成脏数据。

但，这个 case 理论上会出现，不过，实际上出现的概率可能非常低，因为这个条件需要发生在读缓存时缓存失效，而且并发着有一个写操作。而实际上数据库的写操作会比读操作慢得多，而且还要锁表，而读操作必需在写操作前进入数据库操作，而又要晚于写操作更新缓存，所有的这些条件都具备的概率基本并不大。

Read-Through && Write-Through

* 和 Cache-Aside 的模式不同，Read-Through 和 Write-Through 将缓存隐藏到了自己的服务 / 内库中，调用方对缓存无感知
* Read-Through 套路就是在查询操作中更新缓存，当缓存失效的时候（过期或 LRU 换出）自己加载到缓存中
* Write-Through 则是更新数据时发生。当有数据更新的时候，如果没有命中缓存，直接更新数据库，然后返回。如果命中了缓存，则更新缓存，然后再由 Cache 自己更新数据库

Write-Behind

* 在更新数据的时候，只更新缓存，不更新数据库，而我们的缓存会异步地批量更新数据库



## Choreography

> The services communicate with each other by using well-defined APIs. Even a single business operation can result in multiple point-to-point calls among all services. A common pattern for communication is to use a centralized service that acts as the orchestrator. It acknowledges all incoming requests and delegates operations to the respective services. In doing so, it also manages the workflow of the entire business transaction. Each service just completes an operation and is not aware of the overall workflow.

如果是通过 HTTP / RPC 来请求后面的服务，则会造成服务间的耦合。这里可用队列服务进行解耦。前端服务发送消息到后端，后端处理。后端的服务也可能不仅仅充当消费者的角色，也可能是二次加工的生产者角色。

> Each service isn't only responsible for the resiliency of its operation but also the workflow. This responsibility can be burdensome for the service and hard to implement. Each service must retry transient, nontransient, and time-out failures, so that the request terminates gracefully, if needed. Also, the service must be diligent about communicating the success or failure of the operation so that other services can act accordingly.

但如果数据链路过长，还是容易造成问题，如消费能力不一致，消息的处理难度不一致，会导致整个 workflow 出现消息处理的延迟



## Circuit Breaker

> However, there can also be situations where faults are due to unanticipated events, and that might take much longer to fix. These faults can range in severity from a partial loss of connectivity to the complete failure of a service. In these situations it might be pointless for an application to continually retry an operation that is unlikely to succeed, and instead the application should quickly accept that the operation has failed and handle this failure accordingly.

错误可能一时半会恢复不过来，一直重试只会导致请求者的资源浪费（发起请求的线程持有的数据库连接，内存等等）

> Note that setting a shorter timeout might help to resolve this problem, but the timeout shouldn't be so short that the operation fails most of the time, even if the request to the service would eventually succeed.
>
> The Circuit Breaker pattern, popularized by Michael Nygard in his book, Release It!, can prevent an application from repeatedly trying to execute an operation that's likely to fail. Allowing it to continue without waiting for the fault to be fixed or wasting CPU cycles while it determines that the fault is long lasting. The Circuit Breaker pattern also enables an application to detect whether the fault has been resolved. If the problem appears to have been fixed, the application can try to invoke the operation.

和重试不同，重试更多是针对一个接口的行为，但 Circuit Breaker 是由客户端（或者全局）维护的一个状态，保存着最近几次的请求成功与否的结果，用来预测当前是否处于失败的状态，如果是则直接返回失败而不去请求。Circuit Breaker 则是负责维护这些状态的转换

* Open - 服务正常
* Half-Open - 服务有部分异常，可以限制 Rate Limit
* Closed - 直接拒绝客户端请求



## Claim-Check Pattern

> Split a large message into a claim check and a payload. Send the claim check to the messaging platform and store the payload to an external service. This pattern allows large messages to be processed, while protecting the message bus and the client from being overwhelmed or slowed down. This pattern also helps to reduce costs, as storage is usually cheaper than resource units used by the messaging platform.

将体积较大的消息体存到如 S3，数据库中。队列中发送的则是该数据的 meta 信息，给消费者去定位实际的消息体



## CQRS

> The Command and Query Responsibility Segregation (CQRS) pattern separates read and update operations for a data store.

传统的基于 ORM 的设计并没有区分数据库的读写操作，那么意味着对于复杂的读写操作需要处理的 mapping 会比较多。此外，读写两边的资源消耗是不一致的，扩容的操作也不好弄。

最基本的就是分离读写的 model，即数据库层的设计是根据具体的业务流程而不是对应某个 table。需要注意的是，如果是太简单的逻辑，硬是要使用 CQRS 模式，那么读写的数据库操作的代码的重复性会偏高，还不如简单的 ORM 操作。

> If separate read and write databases are used, they must be kept in sync. Typically this is accomplished by having the write model publish an event whenever it updates the database. Updating the database and publishing the event must occur in a single transaction.

除了分离读写的 model 外，更极致点的做法是分离数据库，甚至对可以关系型数据库和文档型数据库混用。但分离数据库之后，提出了同步写数据库到读数据库这一步。

考虑到这里的读写数据库的分离，在数据一致性上只能是最终一致性，如果对这点很敏感的需要考虑是否合适



## Compensating Transaction*

> Applications running in the cloud frequently modify data. This data might be spread across various data sources held in different geographic locations. To avoid contention and improve performance in a distributed environment, an application shouldn't try to provide strong transactional consistency. Rather, the application should implement eventual consistency

强一致性的对资源的要求很高，如果可以应该追求最终一致性。一个业务逻辑如果分成多步来执行的话，如果中间出现问题，那么可能需要选择回滚已执行的步骤或者重试后续的步骤。而前者可能跨越多个数据库，服务等等，不一定都具备回滚操作的能力。

如对于订机票和订酒店的联合请求，如果后续流程有问题，则需要取消之前订的机票或者酒店，或者将选择权交给用户



## Competing Consumers

> Enable multiple concurrent consumers to process messages received on the same messaging channel. This enables a system to process multiple messages concurrently to optimize throughput, to improve scalability and availability, and to balance the workload.

Producer 和 Consunmer 的模式，通过消息队列和 worker 去处理信息



## Compute Resource Consolidation

> Each computational unit consumes chargeable resources, even when it's idle or lightly used. Therefore, this isn't always the most cost-effective solution.

计算单元如果单独管理，容易导致资源浪费（服务闲置等等）。那么改成服务分组，将一些业务相关度很强的放到一起进行 auto scaling。

服务间相互依赖就有可能出现一个服务负载高的相关服务的调用也会变高的情况，如果将其左右一个单元来进行 scaling 的话更好管理。云服务商会有一些别的解决方案，也有一些成本更低廉的如 AWS Lambda 类似的服务，到了这里可能需要考虑具体任务的运行时长和这些服务的启动速度等的权衡



## Deployment stamps

> The deployment stamp pattern involves deploying multiple independent copies of application components, including data stores. Each individual copy is called a stamp, or sometimes a service unit or scale unit. This approach can improve the scalability of your solution, allow you to deploy instances across multiple regions, and separate your customer data.

考虑到跨地域 / 租户的问题，可能服务需要一整套单独部署，做到数据层面的隔离。或者每个 stamp 的更新频率不一致，功能不一致，所以单独部署会是更好的选择。需要注意的是，单独部署后数据并不互通，这就涉及到一个迁移的过程



## Event Sourcing*

> Instead of storing just the current state of the data in a domain, use an append-only store to record the full series of actions taken on that data. The store acts as the system of record and can be used to materialize the domain objects. This can simplify tasks in complex domains, by avoiding the need to synchronize the data model and the business domain, while improving performance, scalability, and responsiveness. It can also provide consistency for transactional data, and maintain full audit trails and history that can enable compensating actions.

传统的 CRUD 在更新时候涉及到数据的，而处理数据的过程中会造成 Lock 等拖慢处理的速度。与 CQRS 一起食用更佳。如果系统对实时性要求高的，这个模式就不太适用了。



## External Configuration Store

> Move configuration information out of the application deployment package to a centralized location. This can provide opportunities for easier management and control of configuration data, and for sharing configuration data across applications and application instances.

配置的统一管理，现在很多框架 / 服务可以提供该功能了



## Federated Identity

> Delegate authentication to an external identity provider. This can simplify development, minimize the requirement for user administration, and improve the user experience of the application.

将权限认证托管到一个统一的认证服务，服务自己就不需要维护权限的信息。关键字 STS（Security Token Services） ，IdP（Identity providers）。不是简单的单点登录，而是包含权限模块的认证服务



## Gatekeeper

> Protect applications and services by using a dedicated host instance that acts as a broker between clients and the application or service, validates and sanitizes requests, and passes requests and data between them. This can provide an additional layer of security, and limit the attack surface of the system.   

挡在公网服务和内网服务之间，转发请求，隔离环境，进行安全的通信。这种网关类的服务本身不进行业务的请求，而是仅仅作为一个手递手的作用



## Gateway Aggregation

> Use a gateway to aggregate multiple individual requests into a single request. This pattern is useful when a client must make multiple calls to different backend systems to perform an operation.

客户端可能需要请求多次某个服务，或者请求多个服务才能完成一次业务，那么可以在 Gateway 层进行聚合（如在 Nginx 处解析 JSON 请求，然后将请求体解析发送到后端具体服务）。需要主义的是，尽量不要和后端服务耦合。



## Gateway Offloading

> Properly handling security issues (token validation, encryption, SSL certificate management) and other complex tasks can require team members to have highly specialized skills. For example, a certificate needed by an application must be configured and deployed on all application instances. With each new deployment, the certificate must be managed to ensure that it does not expire. Any common certificate that is due to expire must be updated, tested, and verified on every application deployment.

常见的就是 Nginx 或者 AWS 的 Loadbalancer 处理了外部传进来的 HTTPS 请求，然后解析之后转成 HTTP 请求到后端，后端服务就不需要自己维护 SSL 证书相关了



## Gateway Routing

> Route requests to multiple services using a single endpoint. This pattern is useful when you wish to expose multiple services on a single endpoint and route to the appropriate service based on the request.

Gateway 担任一个 HTTP 负载均衡的角色，根据 path 转发到后端的服务。此外还可以外部的 path 不变，内部服务的 path 变动，或者根据权重测试后端两个版本的接口



## Geodes

> **ge**ographical n**ode**s

意味在多个区域部署多个节点（集群），和之前提到的 stamp 不同，这里的不同的节点并不进行数据隔离，而是为了减少网络连接的延迟。

这些节点也可以处理一部分数据然后再推到中心去



## Health Endpoint Monitoring

> Implement functional checks in an application that external tools can access through exposed endpoints at regular intervals. This can help to verify that applications and services are performing correctly.

一个健康检查的 endpoint 可以包含数据库的，相关服务的检查。检查项包括

* 状态码是否 200，是否页面错误或者被篡改
* 网络延迟如何
* DNS 的返回记录是否正确，SSL 证书的过期时间

上述的检查是基于公网的，如果是一个非业务端口需要暴露出去的话，需要考虑一些安全性问题



## Index Table

> Create indexes over the fields in data stores that are frequently referenced by queries. This pattern can improve query performance by allowing applications to more quickly locate the data to retrieve from a data store.

另外维护一个索引表，用于查询某些子集或者某个字段和对应主键的记录。不过这个是在数据库不支持次级索引的时候用的



## Leader Election*

> Coordinate the actions performed by a collection of collaborating instances in a distributed application by electing one instance as the leader that assumes responsibility for managing the others. This can help to ensure that instances don't conflict with each other, cause contention for shared resources, or inadvertently interfere with the work that other instances are performing.

目前接触的比较少，实际情况是框架或者服务都有类似的功能了，很少需要实现一个集群选主的功能。如果需要协调多个实例的任务，才需要考虑该模式。实际使用时，也可以借助外部的分布式锁来防止出现冲突。而集群的 leader 更多应该是协调的作用，如果分配实际的任务给 leader 则可能出现 leader 因为负载挂掉的情况。

## Materialized View

来自维基的解释

> In [computing](https://en.wikipedia.org/wiki/Computing), a **materialized view** is a [database](https://en.wikipedia.org/wiki/Database) object that contains the results of a [query](https://en.wikipedia.org/wiki/Query_(databases)). For example, it may be a local copy of data located remotely, or may be a subset of the rows and/or columns of a table or [join](https://en.wikipedia.org/wiki/Join_(SQL)) result, or may be a summary using an [aggregate function](https://en.wikipedia.org/wiki/Aggregate_function).



> When storing data, the priority for developers and data administrators is often focused on how the data is stored, as opposed to how it's read. The chosen storage format is usually closely related to the format of the data, requirements for managing data size and data integrity, and the kind of store in use. For example, when using NoSQL document store, the data is often represented as a series of aggregates, each containing all of the information for that entity.

数据库 schema 设计很多时候不是为了方便 query，而是数据存储和方便管理。数据库本身就支持 view 这种用法，现代情况可能更复杂了，可能包含异构数据，或者存储在 Redis 或者 NoSQL 中，这种情况下结合 Event Sourcing 模式来使用更好。实际使用时需要考虑 view 的生成的速度和可能出现的数据不一致



## Pipes And Filters

> Decompose a task that performs complex processing into a series of separate elements that can be reused. This can improve performance, scalability, and reusability by allowing task elements that perform the processing to be deployed and scaled independently.

把一个很庞大的程序拆分成一个流水线，每个任务只负责一个简单的功能，不同的任务根据需要来进行扩容和缩容。但这种模式不适合处理那种有上下文关联的任务



## Priority Queue

> Prioritize requests sent to services so that requests with a higher priority are received and processed more quickly than those with a lower priority. This pattern is useful in applications that offer different service level guarantees to individual clients.

一般可以通过设置多个队列来实现优先队列，但是需要注意消费者的数量或者消费者选择队列的策略，有可能导致一直消费高优先级的队列导致低优先级的队列没有消费。也可以选择支持优先队列实现的服务，如 RabbitMQ



## Publisher-Subscriber

> A *message* is a packet of data. An *event* is a message that notifies other components about a change or an action that has taken place.

消息和事件的区别是，前者是传递数据，后者则是一个事件变动的通知。



## Queue-Based Load Leveling

> Use a queue that acts as a buffer between a task and a service it invokes in order to smooth intermittent heavy loads that can cause the service to fail or the task to time out. This can help to minimize the impact of peaks in demand on availability and responsiveness for both the task and the service.

请求的速率是会变化的，队列作为缓冲区。和前面的订阅者模式不同，这里注重的对大量消息处理时导致的问题，前者则是注重事件的状态的变化时的通知。此外，如果需要返回值或者对返回值有时延要求的场景不适合这种模式。



## Retry

> Enable an application to handle transient failures when it tries to connect to a service or network resource, by transparently retrying a failed operation. This can improve the stability of the application.

重试是一个很常见的功能，需要注意要区分能重试的请求和不应该重试的请求。如 HTTP 状态码 504 Gateway Timeout 可能由于负载均衡背后的服务正在重启导致的临时错误应该进行重试，但因为请求的资源或者请求体本身的问题引发的 40X 的状态码重试就要考虑下是否有必要了。此外接口的是否幂等也影响重试策略，对一些会出现冲突的请求应该谨慎。

而重试的时间间隔也最好考虑在里面，如果选择固定的时间或者立即重试，那么会导致重试的请求不断的累计来攻击自己的服务。重拾的间隔可以增量或者按指数变化，这样新来的请求和旧的请求重试的时间就不会叠加在一起，平滑了服务的负载。

多次重试之后还是不行应该放弃该请求，实际使用时也可以结合之前说的 Circuit Breaker Pattern



## Saga Distributed Transactions*

> The *saga* design pattern is a way to manage data consistency across microservices in distributed transaction scenarios. A saga is a sequence of transactions that updates each service and publishes a message or event to trigger the next transaction step. If a step fails, the saga executes compensating transactions that counteract the preceding transactions.

现在的微服务架构下，每个服务可以根据自己的业务管理数据库，数据库的选型也可以多种多样，但这样对需要做一致性要求的业务来讲就出现问题了。可能依赖链前面做完了，但当前的服务出现了问题，或者数据不合法导致前面的服务做的改动需要回滚。

可以用队列分发消息或者一个中心的调度器去调用服务来进行一个业务中的不同步骤。需要注意的是，由于改动已经提交，那么回滚是不可能的，需要的时候一个相反的操作去撤销这些改动。

此外，在一个事务处理的过程中，由于数据库是分开管理，前面的服务已经写入数据库了，再去读该服务的数据，从全局的数据来讲，这些就是脏数据。为此，可能需要实现类似于数据库



## Scheduler Agent Supervisor

> The Scheduler maintains information about the progress of the task and the state of each step in a durable data store, called the state store. The Supervisor can use this information to help determine whether a step has failed. 

> When the application is ready to run a task, it submits a request to the Scheduler. The Scheduler records initial state information about the task and its steps (for example, step not yet started) in the state store and then starts performing the operations defined by the workflow. As the Scheduler starts each step, it updates the information about the state of that step in the state store (for example, step running).
>
> If a step references a remote service or resource, the Scheduler sends a message to the appropriate Agent. The message contains the information that the Agent needs to pass to the service or access the resource, in addition to the complete-by time for the operation. If the Agent completes its operation successfully, it returns a response to the Scheduler. The Scheduler can then update the state information in the state store (for example, step completed) and perform the next step. This process continues until the entire task is complete.

这种模式和 k8s scheduler 的模式一样，提交一个包含多个资源变动的请求，管理者将这些请求发送到相应的 Agent，然后监视 state 是否完成。如果出现失败就是相应的重试的策略的选择。



## Sequential Convoy

> Process a set of related messages in a defined order, without blocking processing of other groups of messages.

对数据进行分组，组内数据有序处理。分组也可以作为一个 auto scaling 的依据，某些组别的数据量较少，某些组别的数据量较大。Kafka 的分区 key 可以用作类似的需求，如将同一个 user id 的用户的数据映射到某个分区，保证而 Kafka 保证分区内的数据有序，这样就可以保证速度和顺序的要求



## Sharding

> Divide a data store into a set of horizontal partitions or shards. This can improve scalability when storing and accessing large volumes of data.

数据分区管理。分区的策略有几种：

* Lookup - 基于一个 shard key 来进行分配，可以直接 key - partition 的转换，也可以添加一个 virtual partition，在后面 physical partition 的分配不平衡时可以进行一个 rebalance 的操作
* Range - shard key 是线性的，例如按照月份进行分区
* Hash - 基于一个 hash function 来进行分区，好处是不用像 Lookup 维护一个状态表，问题就是分区间的负载不平衡，后续也难以 rebalance

上述的分区是技术上的实现，此外还可以根据数据的重要程度，热度，还有安全隔离等业务上的逻辑来进行分区。



## Sidecar

> Applications and services often require related functionality, such as monitoring, logging, configuration, and networking services. These peripheral tasks can be implemented as separate components or services.

将业务无关的东西解耦出来，如日志，配置，网络等等，服务本身只负责业务，而技术架构上的东西交给 sidecar 进行处理。



## Static Content Hosting

> Deploy static content to a cloud-based storage service that can deliver them directly to the client. This can reduce the need for potentially expensive compute instances.

资源静态化，减少计算，利用更多如 CDN，S3 等服务进行加速网站的请求



## Strangler

> Incrementally migrate a legacy system by gradually replacing specific pieces of functionality with new applications and services. As features from the legacy system are replaced, the new system eventually replaces all of the old system's features, strangling the old system and allowing you to decommission it.

旧服务的迁移到新服务，中间的过程不能一次性完成的话，存在新旧服务同时运行的情况，那么需要在前面加一个如代理或者负载均衡来处理新旧的交替。



## Throttling

> Control the consumption of resources used by an instance of an application, an individual tenant, or an entire service. This can allow the system to continue to function and meet service level agreements, even when an increase in demand places an extreme load on resources.

限流，和之前的 Circuit Breaker 有点不同，这次是主动保护服务，防止过载。对一些请求过于频繁的用户主动进行丢弃，或者对服务内某些功能进行裁剪，只保留核心功能。

这里最好还是和客户端进行配合，通过特定的返回值告诉客户端下次请求的时间，或者客户端也屏蔽掉一些非核心功能。



## Valet Key

> Use a token that provides clients with restricted direct access to a specific resource, in order to offload data transfer from the application. This is particularly useful in applications that use cloud-hosted storage systems or queues, and can minimize cost and maximize scalability and performance.

服务端不直接维护文件，流的资源，想法，通过 token 授予有限的权限给到客户端，客户端直接操作如 S3 等资源。减轻了服务端的负载，带宽等资源的占用，需要注意的就是数据的安全问题

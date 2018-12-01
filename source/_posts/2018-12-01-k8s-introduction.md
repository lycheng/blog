---
layout: post
title: k8s 简介
tags: [k8s, container, microservice]
---

本文简单介绍下 k8s 的常用组件，知道其能为我们带来什么样的功能。

Resources
---

### Cluster

包含 Master 节点和众多的 Node 节点

### Master

管理集群的节点，其上包含下列服务

kube-apiserver

  - CLI 或者 UI

kube-scheduler

  - 决定 Pod 放哪个 Node

kube-controller-manager

  - 资源管理

Node Controller

  - Node go down 的时候进行处理

Replication Controller

  - 保证 Pod 的数量是正确的

Endpoints Controller

  - 连接 Service 和 Pods

Service Account & Token Controllers

  - 维护账号和用于 API 的 access token

cloud-controller-manageretcd

  - 数据存储
  - alpha feature
  - 与云服务商的服务打交道

Pod 网络

  - IP-per-Pod，每个 Pod 都拥有一个独立 IP 地址，Pod 内所有容器共享一个网络命名空间
  - 集群内所有 Pod 都在一个直接连通的扁平网络中，可通过 IP 直接访问
  - 所有容器之间无需 NAT 就可以直接互相访问
  - 所有 Node 和所有容器之间无需 NAT 就可以直接互相访问
  - 容器自己看到的 IP 跟其他容器看到的一样
  - Master 节点的 etcd 服务存放着各个 Node 的网络信息

### Node

集群中的节点，提供服务的节点，包含一个或多个 Pod

包含以下服务

  - kubelet - 与 Master 通信
  - kube-proxy - 转发请求到 Pod
  - Pod 网络

### Namespace

  - 为物理的 cluster 提供虚拟 cluster 的隔离
  - 如 test, production

### Pod

  - 最小工作单位
  - 同一个 Pod 中共享网络 namespace，即 localhost 可见各个容器的 port
  - 一般是一个 image 一个 Pod

### Controller

  - 用于控制 Pod 部署特性，如副本数量，部署的 Node
  - 常见的 Controller
    - Deployment
    - ReplicaSet - 供 Deployment 使用，管理 Pod 多个副本
    - DaemonSet - 每个 Node 最多一个 Pod，如 k8s 本身的管理进程
    - StatefulSet - 保持部署的名称不变
    - Job - Crontab

### Service

为 Pod 提供负载均衡。一般来说，部署一个服务包含多个 Pod，而 Service 则是在其之上，他们间的关系如下

request -> Service (-> Deployment) -> ReplicaSet -> Pod

Service 是整合 Pod 的资源，作为其 LoadBalance，简单的例子如下：

```yaml
kind: Service
apiVersion: v1
metadata:
  name: my-service
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 80
```

上述 yml 则是将 Service 的 8080 端口映射到 app=nginx 的 Pod 中。因为 Pod 启动时是使用随机的 IP 的，这样子我们就可以通过指定 label 来选择相应的 Pod 了。

默认情况下，Service 的类型是 ClusterIP，即仅提供集群内部的服务，需要对外提供服务，则需要另外配置(spec.type 中定义)，即 NodePort 和 LoadBalancer 两种。

当配置为 NodePort 之后，集群的所有节点都监听一个 30000 以上的随机端口，将其收到的请求转发到 Service 中。此时，你就可以简单的在对应的机器上通过这个端口访问集群内部的 Service。

而 LoadBalancer 目前看则是像与云厂商相关的配置，根据具体厂商自己的负载均衡服务来调用我们定义的 Service。

### DNS

Pod 定义的服务可以通过 IP 和 Port 进行请求，而请求指定的 Service 则是通过 k8s 本身的 DNS 服务进行域名解析。

如一个 Service 名为 serv，其在 test 这个 namespace 下，则其在集群内可以通过 serv.test 来进行访问。而同一个 namespace 下则仅需要 serv 来进行请求。

### Ingress

需要注意的 Ingress 目前还是 beta 的阶段，谨慎使用。

之前提及的 NodePort 也可以提供对外的服务，但是它是服务在 TCP 层上的，意味着其不能根据 path 或者 header 进行转发，而 Ingress 是工作在 HTTP 层。

request(not in cluster) -> Ingress -> Service (-> Deployment) -> ReplicaSet -> Pod

Ingress 的使用需要两部分，Controller 和 Ingress。后者描述规则，前者实现规则。这里跟之前提及的 spec 和 status 概念有点类似。Controller 则是很多常见的做 proxy 的软件，如

  - Nginx
  - Kong
  - HAProxy
  - ...

这里可以看一下简单的定义

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: test-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /testpath
        backend:
          serviceName: test
          servicePort: 80
```

Ingress 使用 annotation 来配置信息。而 spec 的信息一般包含以下内容

  - 可选的 host
  - 一个或多个 path
  - host 和 path 所对应的 host

就目前的信息而言，Controller 这块像一个单独部署的 Nginx Pod，然后监听相关 spec 的更新，然后修改自身的 config 去满足需求。

In-detail
---

### kubectl

kubectl 用于管理 k8s 上的各种资源，常见的就是 kind=Deployment 用于部署服务。其一般用法如下

```
> kubectl apply -f xx.yml
```

这里使用 yml 进行资源描述，而通过更新相应的 yml 文件，再次执行命令是则更新资源。实际上 k8s 是通过 REST API 对外提供服务，这里的 yml 则是实际上转化成 JSON 的格式发给 k8s Master 节点。

对于资源包含三部分信息

 - ResourceSpec: 用户定义的理想状态
 - ResourceStatus: 当前执行的实际状态
 - Resource ObjectMeta: meta 信息，name, API Version, label 或者 annotation 等等，用户和 k8s 都能对其进行更新

而我们定义的是 ResourceSpec 和 Resource ObjectMeta，而 k8s 尽量帮我们满足需求，其实际在系统中表示则是 ResourceStatus。

### Pod

容器只能在 Pod 中创建，这中间包含 Controllers: Deployment, Job, StatefulSet

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: rss-site
  labels:
    app: nginx
spec:
  containers:
    - name: front-end
      image: nginx
      ports:
        - containerPort: 80
```

此时新建的 Pod 则会由 k8s 随机分配一个 IP，无法控制，所以一般不会单独使用 Pod。

上述就是最简单的定义，一个 Pod 中包含一个 Nginx 容器，加一个 label app=nginx。Pod 可设置相应的检查，检查服务或者容器的状态。

 - livenessProbe: 检查容器是否在运行，失败时会触发相应的 restartPolicy
 - readinessProbe: 检查容器能否服务，检查结果为 Success 时才相应地为 Service 服务

这里对于 WEB/HTTP 服务，我们需要每个开发通用的 API，如 HTTP GET ping / pong 来表示统一的容器就绪状态。

这里有一种 initContainers 的配置用于容器启动时的前置条件。可用于执行诸如 Pod 注册的功能，其用法是启动一个新的容器，执行相应的命令。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
  labels:
    app: myapp
spec:
  containers:
  - name: myapp-container
    image: busybox
    command: ['sh', '-c', 'echo The app is running! && sleep 3600']
  initContainers:
  - name: init-myservice
    image: busybox
    command: ['sh', '-c', 'until nslookup myservice; do echo waiting for myservice; sleep 2; done;']
  - name: init-mydb
    image: busybox
    command: ['sh', '-c', 'until nslookup mydb; do echo waiting for mydb; sleep 2; done;']
```

除此以外，还有一种用于注入依赖的，如 volume，环境变量

```yaml
apiVersion: settings.k8s.io/v1alpha1
kind: PodPreset
metadata:
  name: allow-database
spec:
  selector:
    matchLabels:
      role: frontend
  env:
    - name: DB_PORT
      value: "6379"
  volumeMounts:
    - mountPath: /cache
      name: cache-volume
  volumes:
    - name: cache-volume
      emptyDir: {}
```

而别的容器使用的时候只需要符合对应的 label role=frontend 即可

需要注意的是，通过 API 去创建 Pod 之后，再去修改配置文件也不会对已有的 Pod 造成影响

> Subsequent changes to the template or even switching to a new template has no direct effect on the pods already created. Similarly, pods created by a replication controller may subsequently be updated directly.

所以，也不推荐单独使用 Pod 这种资源，服务的管理应该使用更高层级的 Deployment 或者 StatefulSet 等等。

### Deployment

Deployment 包含几种功能

  - 使用 ReplicaSet 去上线 Pod，并根据预设条件判断是否成功
  - 更新 template 中 Pod 的状态，新的 ReplicaSet 会创建并转移旧的
  - 回滚到旧的 Deployment 版本
  - 通过设置副本数量扩容 / 减容

这里关注几个常见的场景

```sh
# 根据配置创建 Deployment
kubectl create -f app.yaml

# 查看 Deployment 信息
kubectl get deployments.

# 查看指定 Deployment 的更新状态
kubectl rollout status deployment.v1.apps/nginx-deployment

# 更新指定 Deployment 的镜像版本
# 后面 --record 选项需要添加，这样就可以在错误的升级之后回滚
kubectl set image deployment.v1.apps/nginx-deployment nginx=nginx:1.9.1 --record

# 查看 rollout 信息
kubectl rollout history deployment.v1.apps/nginx-deployment

# 查看指定版本的 rollout 信息，版本信息可以在上面的命令获取
kubectl rollout history deployment.v1.apps/nginx-deployment --revision=2

# 回滚到上一个版本
kubectl rollout undo deployment.v1.apps/nginx-deployment

# 回滚到指定版本
kubectl rollout undo deployment.v1.apps/nginx-deployment --to-revision=2

# 手动扩容
kubectl scale deployment.v1.apps/nginx-deployment --replicas=10

# 根据条件自动扩容
kubectl autoscale deployment.v1.apps/nginx-deployment --min=10 --max=15 --cpu-percent=80

# rolling update，作用于 Pods 和 ReplicationControllers，还是推荐使用 Deployment
kubectl rolling-update frontend-v1 frontend-v2 --image=image:v2
```

需要注意的是，Label selector 并不推荐更新，需要在部署的时候就提前规划好 label 的使用

> It is generally discouraged to make label selector updates and it is suggested to plan your selectors up front. In any case, if you need to perform a label selector update, exercise great caution and make sure you have grasped all of the implications.

#### ReplicaSet

docs: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/

ReplicaSet 是下一代的 Replication Controller，加多了 selector 的支持。官方更推荐使用 Deployment 来管理多个副本，而不用自己维护一个 ReplicaSet

>  If you want the rolling update functionality please consider using Deployments instead.

除了 rolling update 这个功能以外，看这个 [文章](https://segmentfault.com/a/1190000016060606) 似乎 ReplicaSet / Deployment 会影响到单独创建的符合条件的 Pod.

#### Others

除了最简单的 Deployment 以外，还包含其它资源类型：StatefulSet, DaemonSet, Job

> Note: StatefulSets are stable (GA) in 1.9.

与 Deployment 不同，StatefulSet 用于部署有状态（磁盘）的应用。有着更为严格的扩容，更新机制，详见 [文档](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)。

> A DaemonSet ensures that all (or some) Nodes run a copy of a Pod.

DaemonSet 用于部署如日志收集，监控系统等服务。

Job 为分布式的 Crontab，可以指定 Pod 去执行任务。

Conclusion
---

本文简介了 k8s 一些常用服务及其相关关系，而其底层实现（如其实现转发的 iptables 规则等等）则暂未涉及。

这里我们可以知道，k8s 本身仅仅做服务或者说 Pod 的管理，如果需要精确到流量（如 X% 的流量走这个版本，Y% 的流量走第二个版本）在 k8s 中则需要配置相应的 replicas 数量来实现。

而 Istio 或其它 ServiceMesh 插件或框架则提供了这类功能。

References
----

 - [5 分钟玩转 Docker 容器系列文章](https://www.cnblogs.com/CloudMan6/p/8294766.html)
 - [k8s Deployment 生动的介绍](https://www.cncf.io/wp-content/uploads/2018/03/CNCF-Presentation-Template-K8s-Deployment.pdf)
 - [k8s API 文档](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.10/#-strong-api-overview-strong-)
 - [Pod 配置 Probe](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/)

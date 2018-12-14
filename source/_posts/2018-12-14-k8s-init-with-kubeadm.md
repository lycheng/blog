---
layout: post
title: 使用 kubeadm 初始化 k8s 集群
tags: [docker, k8s]
---

系统环境：CentOS 7.X

Kubernetes 相关版本：

 - kubeadm - v1.13.0
 - kubelet - v1.13.0
 - kubectl - v1.13.0


k8s master 初始化
---

配置仓库，安装 kube 相关依赖

```
> vim /etc/yum.repos.d/kubernetes.repo
```

设置 kubernetes 的 aliyun 仓库，CentOS 本身的源只支持到 1.5.X 的版本

```
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
```

```
> setenforce 0
> yum install -y kubelet kubeadm kubectl
> vim /etc/fstab # 注释最后一行来去掉 swap
> swapoff -a
> systemctl enable kubelet && systemctl start kubelet
```

指定版本，指定仓库

```
> kubeadm init --pod-network-cidr=10.244.0.0/16 --image-repository registry.aliyuncs.com/google_containers --kubernetes-version v1.13.0
```

配置 kubectl 环境，让非 root 用户都能使用 kubectl

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

安装 flannel 网络

```
> docker pull registry.cn-hangzhou.aliyuncs.com/kubernetes_containers/flannel:v0.10.0-amd64
> docker tag registry.cn-hangzhou.aliyuncs.com/kubernetes_containers/flannel:v0.10.0-amd64 quay.io/coreos/flannel:v0.10.0-amd64
> kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

安装完之后如果 coredns 有问题，可以修改 coredns deploy 配置之后再进行部署，

```
> kubectl -n kube-system get deployment coredns -o yaml > coredns.yaml
> vim coredns.yml # allowPrivilegeEscalation: true
> kubectl apply -f coredns.yml
```

相关 issue: https://github.com/kubernetes/kubeadm/issues/998

之后在 master 节点执行下面的命令，应该是所有的服务都是在运行的

```
> kubectl get pods -n kube-system
```

至此，master 节点的初始化结束

k8s node 节点初始化
---

在 master 节点执行命令，获取用于 join 的命令

```
> kubeadm token create --print-join-command
```

在 worker 节点上 执行上述命令

```
> kubeadm join ...
```

然后在 master 节点执行可见相关结果

```
> kubectl get pods -n kube-system
> kubectl get nodes
```

如果遇到 NotReady 的情况，可尝试先将该节点删掉

```
> kubectl drain <node name> --delete-local-data --force --ignore-daemonsets
> kubectl delete node <node name>
```

然后在 worker 节点

```
> kubeadm reset
```

之后再重新 join。目前遇到最多的问题是 cgroups-driver 不一致，目前尝试将 k8s 和 docker 都改成 systemd 即可。可使用下面的命令查看

```
> systemctl status kubelet
> docker info | grep -i driver
```

给节点设置 role

```
> kubectl label node <node name> node-role.kubernetes.io/node=
```

写在最后
---

1.13 版本的 k8s 使用 kubeadm 安装的话会比之前的体验好很多，但是自己测试下来还是挺多坑的

  - 网络的问题，新版的 kubeadm 可以支持修改镜像仓库，使用 aliyun 的话还行，但你安装 flannel 的话还是需要手动处理下
  - cgroups.driver 问题，这个的话与 k8s 和 docker 都有关系，两边需要统一才行

总体而言会比之前的体验好点，目前新版的 kubeadm 也到了 GA 阶段了，未来的话希望体验更好点吧。

References
---

  - [使用 kubeadm 初始化 1.13 版本的 k8s 集群][1]
  - [k8s 1.13 的 release 博客][2]


  [1]: https://www.cnblogs.com/RainingNight/p/using-kubeadm-to-create-a-cluster-1-13.html
  [2]: https://kubernetes.io/blog/2018/12/03/kubernetes-1-13-release-announcement/

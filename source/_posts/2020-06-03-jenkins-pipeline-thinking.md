---
layout: post
title: Jenkins pipeline thinking
tags: [jenkins, pipeline, docker]
---

在 2019 年中至今花了挺多时间在 Jenkins pipeline 的改造，本文旨在描述这个过程中的一些思考和实践。涉及到 Python，Java，前端的项目。

## Version 0.1

最开始接手项目时，一个项目只有一个 Jenkinsfile。使用 branch 进判断，像 master 分支对应 production 环境，只要有代码提交，则 Jenkins 进行构建，执行 terraform 代码。程序本身通过 docker 来运行，每个 image 的 tag 对应其发布分支的 commit hash id。

对于 Python library 类的项目，则会区分 master 分支和非 master 分支，如果最新的一个 commit message 中包含一个 `[release]` 的信息，则会进行构建，并进行 Github Release，区别就是 master 分支构建的版本是正式版本，非 master 的分支构建出来的版本包含 commit hash id 的信息。

这种 pipeline 的模式好处就是非常简单，如果需要发布新版本只需要在对应的分支提交代码 / PR 即可。但后续我们加入了 dev / test 的环境，意味着我们需要维护 4 个分支。

除此以外，因为我们使用 terraform 来进行部署，最终是通过 AWS 的 [ECS](https://aws.amazon.com/ecs/) 来运行，所以包括 staging / production 环境的资源限制（基于 cloudwatch 的 autoscaling），数据库和 Kafka 的配置等信息都通过代码来控制。我们需要更新这些配置的话，就需要编辑代码，则会引发 docker image 的更新。如果是简单的更改配置的话，也需要走一遍重新构建镜像的过程。

最重要的问题是，我们没法回滚。因为部署都是基于 branch 的，没有一个版本的概念。发布了之后只能通过 git commit hash id 去找到我们发布时候的那个点，或者切换到想要回滚的那个点，找回那个点对应的镜像。

## Version 0.2

对于一个项目来说，功能开发完会提 PR，Github 那里会检测这个 PR 的测试的结果，代码质量检测，只有合格了才进行 merge。那么对于同一个阶段的代码来说，一次发布从代码提交到部署的中间必须会执行两次代码测试，image 构建等等。如果这些耗时很长的话，则会导致一次发布拖延甚久。

如果不同项目之间出现依赖问题，那么一个项目的发布导致的拖延，线上的检查等等则会造成更多的等待。除此以外，因为 branch 是自动构建的，我们也只能等到发布的时候才进行 PR 的 merge。所以 0.2 的版本的首要解决的问题是，构建（image）和发布分离。

这里我们去掉了原有 Jenkinsfile 中的部署部分的代码，将其移动到了 Jenkinsfile-release 中。通过 [Jenkins Parameterized Build](https://stackoverflow.com/questions/47565933/build-pipeline-using-a-branch-parameter) 的形式选择想要发布的 branch，获取到对应的 docker image 的 tag 然后执行相应的 terraform 代码，完成更新。

这个模式目前只能解决发布和构建耦合在一起的问题。除此以外，这里一个比较严重的问题是，Jenkins 支持下拉框对应的 tag / branch，但实际上并不 checkout 到对应的 ref。后来发现应该是 Jenkins Git Plugin 的 [bug](https://issues.jenkins-ci.org/plugins/servlet/mobile#issue/JENKINS-28447)。

## Version 0.3

与上个版本最大的不同是，使用 git tag 来进行发布。保护分支变成两种，master 分支和 release/* 分支。前者对应 production / staging 的代码，后者对应 dev / test 的代码。对于 master 分支和 release/* 分支，都会打出 git tag，不同的是，后者会有个 build 的 suffix，用到了 Jenkins 构建时候的环境变量 `env.BUILD_NUMBER` ，如当前版本是 v1.0.0 则 release 对应的版本是 `v1.0.0b<env.BUILD_NUMBER>` 直到测试通过合并到 master 分支，则会打出 v1.0.0 不含后缀的 git tag。

语义化版本之后，通过 Jenkins 的参数化构建，我们就能通过选择发布的 tag 来进行发布。如果我们 build 出来的 docker image 的 tag 也遵循这个规则，我们就能通过这个 git tag 对应上。那么部署要做的事情就简单多了，checkout 出对应的代码，通过 Makefile 获取对应的 image name 等基础信息，组合成需要发布的 docker image，通过这个点上的 terraform 代码进行部署。

除此以外，如果通过选择 tag 的形式，如果新旧两个版本的代码没有兼容性问题，我们可以简单的通过选择上次稳定版本的代码来进行发布。

## Version 0.4

直到现在我们还是使用 terraform 来进行发布，好处还是我们能通过代码控制基础设施，包括内部域名，autoscaling 的参数配置等等。但随之而来的就是每次更新配置都需要修改项目的代码。当前最简单的方法就是将 terraform 代码迁移出来通过别的项目来管理，每次需要更新的时候，提 PR 更新想要发布的项目的 image tag 即可，此外，我们也有了一个统一管理不同服务版本的办法。

最开始公司内部使用的是 k8s 来作部署工具，当时我写了一个简单的 Python 脚本加一个 template 的来渲染出对应 dev / test 环境的 k8s deployment.yml，然后复制到 k8s 对应的集群执行 `kubectl apply -f deployment.yml` 即可。现在逐步改用 [kustomize](https://kustomize.io/) 来部署，算是正规化了许多。而且，在 Jenkins slave 中保存了对应 k8s 集群的认证的配置文件，可以直接从 Jenkins slave 中发起 k8s deployment 的更新。

基于 kustomize 还有一个比较重要的原因它支持 [remote resource](https://github.com/kubernetes-sigs/kustomize/blob/master/examples/remoteBuild.md#url-format)。所以我们目前的做法是，在项目中编写 base / dev / test layer，而去执行部署的程序引用 base layer，能保证我们 production 环境的端口，环境变量等基本配置一一致，而针对具体环境，又能设置具体的如资源限制，configmap，或者 ingress。

## Version X

~~到了 0.4 的阶段，我觉得基本能满足我们的需求了。基本的目的是，项目本身只负责 image build 这一阶段，而后续的 push image 则是由具体的环境的 Jenkins 来进行，如你在 AWS / Aliyun 各有一个 docker registry。~~

后面重新试了下，觉得这种方式过于繁琐，需要维护各种环境的构建环境，后续的想法是有在国内进行 image 的构建，而某个具体环境需要部署时，则将该版本的 docker image 推到对应的 docker registry。

AWS 上的基础设置还是通过 terraform 来维护，不同的是，只有基础设置，具体服务就由 Jenkins Pipeline 来负责部署。而不同环境 / AWS 帐号的差异则通过 kustomize 的不同 layer 来实现。

## Tools

### Jenkins

目前在各个项目中分布着 Pipeline 的两种语法，Goovy 的写法会更灵活，但 Declarative 的写法会更家规范。我们希望将所有的构建的细节都用 Makefile 封装起来，而 pipeline 则仅仅负责调用。对于不同的环境（国内 / 国外或者 AWS / Aliyun）的配置（如 docker registry）则通过环境变量来引入。

### Docker

docker 在不同环境中的主要问题是网速，特别是依赖库的更新。这里可以通过 build args 来定制化这些配置，如 pip

```Dockerfile
ARG PYPI_MIRROR=https://pypi.python.org/simple/
RUN pip install -i ${PYPI_MIRROR} -r config/requirements.txt
```

npm

```Dockerfile
ARG NPM_REGISTRY=https://registry.npm.taobao.org
RUN npm install -g xxx --registry=${NPM_REGISTRY}
```

还有一个问题，必须要区分 build args 和 runtime env variables。前者是无关环境的，一个判别方法是，如果这个 image 换到别的环境去使用，能否仅仅通过 env variables 去配置？常见的就是前端的代码，因为 Nginx 或者 image 中放置的是通过工具编译过的 JavaScript 文件，无法配置环境变量。这里就需要额外添加 entrypoint.sh 和命令 `envsubst` 来进行改造。

### kustomize

这里我们还有讨论到一个点，就是 dev / test 环境的 configmap 要不要项目本身来维护。如果由自己来维护的话，方便进行开发调试，但另一方面就可能导致有配置和 staging / production 不一致出现问题。除此以外，如果 configmap 同名的话，仅仅是更新配置但 deployment 是不会重启 pod 的。

### terraform

目前项目有用到 0.11 版本的语法的 terraform 0.12 版本的 terraform。目前发现，对于已经用旧语法进行部署的服务，如果用新的版本的 terraform 进行部署，则会报错。在这个过程中，需要维护旧的服务，并且逐渐迁移到新的版本。

0.12 的语法更加简洁，并且有新加的如 `count` 和 `for_each` 等用法可以方便编写相似的资源。除此以外，新版本 terraform 去读取旧语法生成的 state 的内容也是可以的。


## References

* https://semver.org/
* https://www.jenkins.io/doc/book/pipeline/syntax/#compare
* https://mirror.tuna.tsinghua.edu.cn/help/pypi/
* https://ledermann.dev/blog/2018/04/27/dockerize-and-configure-javascript-single-page-application/

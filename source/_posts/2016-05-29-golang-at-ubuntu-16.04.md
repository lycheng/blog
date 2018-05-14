---
layout: post
title:  Golang 开发配置 @ ubuntu 16.04 LTS
tags: [golang, ubuntu]
---

环境
---

ubuntu 16.04 的源的 Golang 的版本是 1.6+ 的，不用像 14.04 那样需要自己手动去更新版本。

在 `$HOME/.zshrc` 上配置该变量

```bash
export GOPATH=/home/lycheng/projects/go
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:$GOPATH/bin"
```

其中 `$GOPATH` 是一个重要的环境变量，该目录用于存放源代码和可执行文件。大概的结构如下

```
├── bin # 可执行文件
│   ├── govendor
│   ├── motion
│   └── ...
├── pkg # 外部的包依赖
│   └── linux_amd64
│       ├── 9fans.net
│       ├── github.com
│       └── ...
└── src # 源代码
    ├── 9fans.net
    │   └── go
    ├── github.com
    │   ├── alecthomas
    │   ├── aws
    │   └── ...
    ├── golang.org
    │   └── x
    ├── gopkg.in
    │   └── alecthomas
    └── sourcegraph.com
        └── sqs
```

基本上开发实在 `$GOPATH/src/github.com/{username}/{project}` 下进行，同时使用 github 作为版本管理平台，完美。

编辑器 / IDE
---

我的主力开发工具是 vim

```bash
# 16.04 里面的没人 vim 不开 python 支持了
# 这是单纯的命令行版本
sudo apt-get install vim-nox
```

```bash
# 也可以使用别的项目
# 主要是需要 https://github.com/fatih/vim-go
git clone git://github.com/lycheng/dot-vimrc.git ~/.vim
ln -s ~/.vim/vimrc ~/.vimrc
git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle
```

在 vim 里面

```
:BundleInstall
:GoInstallBinaries
```

编译 YCM

```bash
cd ~/.vim/bundle/YouCompleteMe
./install.py --clang-completer --gocode-completer
```

YCM 不是一个必要的条件，可参考文末的 [文章][1] 去配置 `neocomplete.vim` 作为代码提示插件。

idea 和 vscode 都有对 Golang 很好的支持，一般情况下我都是开着 vscode 看代码然后使用 vim 进行开发。

因为众所周知的原因，vim vscode 不少的依赖是需要架梯子去下载的。可设置

```bash
 export http_proxy=http://127.0.0.1:1080/
 export https_proxy=$http_proxy
```

依赖管理
---

一般普通的包的安装只要简单的命令即可

```bash
go get -u github.com/kardianos/govendor
```

`go get` 命令包含两层意思

1. 下载源码包到 `$GOPATH/src/..` 中
2. 生成链接对象 （*.a） 到 `$GOPATH/pkg/...` 中，如有必要也会生成可执行文件到 `$GOPATH/bin` 中

用该命令能很方便的进行 Golang 的第三方包的下载，实际使用的使用也只需要

```go
import "github.com/{username}/{proj}/{package}..."
```

就能正常使用了。但如果需要项目级别的依赖管理，就需要用到 `govendor`

### govendor

使用 govendor 必须是要求 Golang 版本 1.5+。

```bash
go get -u github.com/kardianos/govendor
```

基本用法

```bash
# Setup your project.
cd "my project in GOPATH"
govendor init

# Add existing GOPATH files to vendor.
govendor add +external

# View your work.
govendor list

# Look at what is using a package
govendor list -v fmt

# Specify a specific version or revision to fetch
govendor fetch golang.org/x/net/context@a4bbce9fcae005b22ae5443f6af064d80a6f5a55
govendor fetch golang.org/x/net/context@v1   # Get latest v1.*.* tag or branch.
govendor fetch golang.org/x/net/context@=v1  # Get the tag or branch named "v1".

# Update a package to latest, given any prior version constraint
govendor fetch golang.org/x/net/context
```

初始化之后 govendor 会在项目文件内创建一个 vendor 的文件夹，会将相应的第三方依赖下载到该目录下，目录的组织机构和 `$GOPATH` 一样。

更多的细节可见 [这里][3]

个人见解
---

在用了两年 Python 之后，再来尝试 Golang，其实第一感觉是它的语法挺啰嗦的。然后认认真真写了几天代码之后其实感觉挺好的，啰嗦带来的好处就是有些问题，特别是变量的类型问题在运行前就可以发现了，`go fmt` 带来的好处是各个人的代码都起码不会太难看。

因为是静态类型，各种工具的支持很棒，例如 [这个][2] 东西就很棒，在 github 上看代码太舒服了。

参考
---

1. [配置 VIM 作为 IDE][1]
2. [一个超棒的 chrome 插件 / 网站，用于浏览 github 的源代码，目前只支持 Golang][2]
3. [govendor][3]

  [1]: http://farazdagi.com/blog/2015/vim-as-golang-ide/
  [2]: https://sourcegraph.com/
  [3]: https://github.com/kardianos/govendor

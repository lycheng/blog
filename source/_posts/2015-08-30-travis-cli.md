---
layout: post
title: Travis Cli
tags: [ci, python]
---

发现这个东西是因为之前看 [werkzeug](https://github.com/mitsuhiko/werkzeug) 的 README 时候发现有个图片，然后看了下是实时生成的。然后就跟着进去发现了 [travis CI](https://travis-ci.org/)，这是用于持续集成的项目，通过配置文件去定义自己的构建，测试。以 Python 为例，可以测试不同的 Py 版本，自定义测试环境（依赖包等等）。

于是就在自己的 [项目](https://github.com/lycheng/pylib) 上试用了下。

首先是，[tox](https://testrun.org/tox/latest/)，这个也是新发现的东西，用于 Python 的测试。需要注意的是，tox 用在可安装的包中，所以必须编写自己的 setup.py 文件。

我的 tox 配置文件如下

```yaml
[tox]
envlist = py27.py34

[testenv]
deps=nose

commands=
    nosetests
```

我用的是 nosetest 来进行测试，测试的环境是 py2.7 和 py3.4。上面的配置文件也标明了测试的依赖和测试的命令。奇怪的是，一定要 sudo 权限运行，tox 明明是用 virtualenv 来设置测试环境的，却必须要用 root 权限。这个回头看下。

配置好之后，执行命令 sudo tox -e py 就可以进行测试。一般到这里就是常见的开发测试了，接下来配置 Travis Cli。

首先需要去它们网站设置需要测试的项目，之后需要配置 .travis.yml 文件，我的配置如下

```yaml
language: python
sudo: true
python:
    - "2.7"
    - "3.4"

install:
    - pip install tox nose

script:
    - tox -e py
```

这个也是很简单的配置语法，也是需要配置依赖，设置想要测试的版本，接下来就是提交你的东西了。

Travis Cli 每次 commit 之后就会执行构建，之后会通过邮件通知用户，你也可以去网站看到构建结果。然后你可以贴个图到 README ，这样用你的代码的人一眼就可以看到你的代码的情况了。

![svg](https://api.travis-ci.org/repositories/lycheng/pylib.svg?branch=master)

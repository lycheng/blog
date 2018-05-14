---
layout: post
title: virtualenvwrapper 使用记录
tags: [python, virtualenv, virtualenvwrapper]
---

[virtualenvwrapper](http://virtualenvwrapper.readthedocs.org/en/latest/) 是个方便管理 virtualenv 工具。


## 初始化环境

当前使用的是 Arch 所以默认版本为 python3，以下为在该环境下的使用方法

```shell
sudo pip2 install virtualenvwrapper
...
export WORKON_HOME=~/Envs
mkdir -p $WORKON_HOME

# 在使用默认版本 py3 的环境里面，如果需要使用 py2 的话，则需要另外加一行
# 如果只是 py3 的话不需要理会
export VIRTUALENVWRAPPER_PYTHON=/usr/local/bin/python2.7

source /usr/bin/virtualenvwrapper.sh
mkvirtualenv env

# 加载系统现有的包去初始化环境
mkvirtualenv env --system-site-packages
```

在 `.zshrc` 中加入

```shell
source /usr/bin/virtualenvwrapper.sh

# 具体的文件位置不一定
# 官方文档的例子是 source /usr/local/bin/virtualenvwrapper.sh
# 可用 find / -name virtualenvwrapper.sh 去确定.
```

## 使用

```
# 创建环境
mkvirtualenv env

pip2 install requests

# 切换环境
workon env2

# 离开环境
deactivate

# 查看当前环境安装的包
lssitepackages

# 其他操作
lsvirtualenv, rmvirtualenv
```

## 项目管理

```
# 在已有的项目使用虚拟环境，然后在下次进入该项目的时候就回自动启用虚拟环境

setvirtualenvproject [virtualenv_path project_path]
```

在设置了虚拟环境之后，执行 `workon env` 就可以自动跳转到项目路径，如果在别的路径下面使用可以不自动跳转 `workon env -n`

## 其它一些东西

如果需要在 env 环境下手动安装依赖，需要指定 python，如

```shell
/home/lycheng/Env/tw/bin/python setup.py install
```

命令行更好的提示

```shell
# $WORKON_HOME/postactivate
PS1="$_OLD_VIRTUAL_PS1"
_OLD_RPROMPT="$RPROMPT"
RPROMPT="%{${fg_bold[white]}%}(env: %{${fg[green]}%}`basename \"$VIRTUAL_ENV\"`%{${fg_bold[white]}%})%{${reset_color}%} $RPROMPT"

# $WORKON_HOME/postdeactivate
RPROMPT="$_OLD_RPROMPT"
```

## 暂时的问题

目前还有的问题就是，通过 cd 真的会自动切换虚拟环境，但是在 tmux 中，新建 session，切分窗口也不能自动使用路径对应的虚拟环境。必须手动重新加载一次。

## 参考

 1. [官方文档](http://virtualenvwrapper.readthedocs.org/en/latest/index.html)

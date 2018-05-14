---
layout: post
title: Jekyll + Github Pages
tags: [blog]
---

现在的目录结构如下

```
├── about.html
├── config.rb
├── _config.yml
├── css
│   └── blog.css
├── index.html
├── _layouts
│   ├── layout.html
│   └── post.html
├── LICENSE
├── _posts
│   ├── 2015-08-23-first.md
│   └── 2015-08-23-Jekyll-Github-Pages.md
├── README.md
├── sass
│   ├── blog.scss
│   └── partials
│       ├── _layout.scss
│       ├── _post.scss
│       ├── _public.scss
│       └── _reset.scss
└── static
    └── css
        └── blog.css
```

其中，`config.rb` 是 compass 的配置文件，`sass` 用于存放 `*.scss` 文件。当前使用的 `sass` 的写法参考的是之前的项目，需要更多研究下这个东西。

`_config.yml` 为 `jekyll` 的配置文件，`_layout` 文件夹存放的是页面结构定义的 html，`_post` 存放的是实际的日志文件。

---
layout: post
title: Python 编码问题
tags: [python, encoding]
---

本文关注的是 python2 和 python3 在编码处理上的异同。所使用的python2 的版本为 2.7.12，python3 的版本为 3.5.2。

unicode
---

unicode 是为了解决不同的语言背景下的统一的文字编码问题，简单来说就是给全世界所有的语言的字符唯一的 ID 来进行识别。例如，使用 python2 来输出汉字 “你好”

```python
s = u'你好'
print(s) # u'\u4f60\u597d'
```

上述的 \u 开头的代码即 unicode 对汉字的唯一代码。但实际上，在计算机中，并不直接存放该代码。在 unicode 之前，普遍使用的是 ASCII 的方式进行编码，在英文世界中，一个字节可表示的 128 个符号已经足够了。如果普遍使用 unicode 则相应的英文存储的空间要扩大一倍以上。

所以就有了 utf-8 的出现。utf-8 是最普遍的 unicode 的实现方式，最主要的特点是可变长的编码形式。对于 ASCII 这种单字节的形式，第一个 bit 设置为 0，后面 7 位为有效位，即可完美兼容 ASCII。对于其他形式，则相应的位数有相应的规则，这里就不展开讨论了。

最后，需要注意的是，utf-8 是变长的，由前缀的 bit 位的规则来决定字节数。之后来谈谈在 python 中的实现。

python2
---

python2 的默认编码为 ASCII。在源代码文件中，如果用到非 ASCII 字符，需要在文件头部进行编码声明，当然，这并不影响实际程序的编码

```python
# -*- coding: utf-8 -*-
```

在 python2 中，与编码对应的有两种类型，str 和 unicode。简单来说，str 由 unicode 经过某种编码之后的字节组成。两者的关系如下

 - 都是 basestring 的子类
 - 相对来说，unicode 才是真正意义上的字符串，调用 len 方法统计的是有多少个“字”，而 str 则是有多少字节
 - str  -> decode('the_coding_of_str') -> unicode
 - unicode -> encode('the_coding_you_want') -> str

```python
# -*- coding: utf-8 -*-

u = u'你好'
s = u.encode("utf-8")
# u.decode("utf-8")  # UnicodeEncodeError: 'ascii' codec can't encode ...

u0 = s.decode("utf-8")
# s.encode("utf-8")  # UnicodeDecodeError: 'ascii' codec can't decode ...

s = '你好'  # 如果不加源文件的 coding 声明，这里会报错
u = s.decode("utf-8")
#  u.decode("utf-8")  # UnicodeEncodeError: 'ascii' codec can't encode

s = u.encode("utf-8")
#  s.encode("utf-8")  # UnicodeDecodeError: 'ascii' codec can't decode

u = u'abc'
s = 'abc'

print(s + u)  # abcabc
print(s == u)  # True
```

上述代码可以看到，decode 和 encode 的调用需要明确，unicode 需要根据一定的编码规则解析成机器可识别的字节流 str，而一堆字节流我们需要知道它所用的编码规则来解析成 unicode。

需要注意的是，如果是涉及 unicode 和 str 进行拼接和比较，则会有一次隐式转换，即先将 str 转成 unicode 再进行比较。如果 str 不是 ASCII 的话可能会出现转码错误。

### 建议

1. python 源文件指定编码，一般推荐为 utf-8
2. 硬编码的字符，使用 unicode 进行声明，如 `s = u'你好'`
3. 统一转成 unicode 来使用
4. Decode early, Unicode everywhere, Encode later

python3
---

python3 中，相关的类型为 unicode 和 byte。与 python2 相对应的是

 - python2:str == python3:bytes
 - python2:unicode = python3:str

这样子更容易理解，str 存放的即是我想要的数据，bytes 存放的是实际的二进制数据。还有就是 python3 中将严格区分 str 和 bytes。str 类型只有 encode 方法，bytes 类型只有 decode 方法。

```python
s = "你好"
b = s.encode("utf-8")
print(b)  # b'\xe4\xbd\xa0\xe5\xa5\xbd'
s0 = b.decode("utf-8")
print(s0)  # 你好

# str 和 bytes 被认为是两种类型，比较和连接并不会进行自动的类型转换
s = "abc"
b = b"abc"
print(s == b)  # False
print(s + b)  # TypeError: Can't convert 'bytes' object to str implicitly
```

对文件的操作也不同了，你通过 open 函数打开的文件返回的东西可能不同了。如果指定 `rb` 模式打开的文件，其内容为二进制流，即 bytes。如果是 `r` 模式，其内容为 str，这点需要额外注意。

```python
fp = open("./index.html")
print(type(fp.read()))  # <class 'str'>

fp = open("./index.html", "rb")
print(type(fp.read()))  # <class 'bytes'>
```

总结
---

python3 比 python2 在编码上更加严格了，默认的编码就是 utf-8，已经不再需要在原文件头声明编码。decode 和 encode 方法也不再是两个类型都能调用，这个我认为是比较重要的，这样在写代码的时候就不需要纠结要用哪个方法了，最后是推荐阅读参考的第一个文章，很好的讲解了 unicode 的出现背景。

参考
---

1. [unicode 的出现背景和相关知识](https://www.joelonsoftware.com/2003/10/08/the-absolute-minimum-every-software-developer-absolutely-positively-must-know-about-unicode-and-character-sets-no-excuses/)
2. [阮一峰的关于 unicode 的笔记](http://www.ruanyifeng.com/blog/2007/10/ascii_unicode_and_utf-8.html)
3. [Unicode HOWTO python2](https://docs.python.org/2/howto/unicode.html)

---
layout: post
title: Python3 字符串问题
tags: [python, encoding]
---

在写代码的时候遇到一个比较奇怪的问题，精简之后的代码如下

```python
import redis

try:
    from urllib.parse import urlparse
except:
    from urlparse import urlparse

key = 'baidu'
val = 'http://www.baidu.com'
schemes = ['http', 'https', 'socks']

rdb = redis.StrictRedis(host='localhost', port=6379, db=0)
rdb.set('baidu', 'http://www.baidu.com')

url = rdb.get('baidu')
# print(type(url))
o = urlparse(url)

print(o.scheme in schemes)
```

上述代码初看之下没有问题，但是在 Python3 中跑的话与在 Python2 中跑的结果不一样。Python3 中输出 False，Python2 中输出 True。

为什么呢？

字符串类型
---

上述问题是由 Python3 中 str 和 bytes 造成的。与 Python2 相比，Python3 的字符串类型改成了 str 和 bytes，其中 str 相当于 Python2 的 unicode，bytes 相当于 Python2 的 str。从 redis 中拿回的数据是 bytes 类型，bytes 类型的与 list 中的 str 去比较则是永远都是 False。

在 Python2 中，unicode 和 str 的混合使用会有隐式的类型转换，Python3 中则是完全两种类型，不存在比较的可能性

```
print(u'' == '') # Python2 -> True
print(b'' == '') # Python3 -> False
```

Python2 中的 unicode 和 str 实际上都继承于 basestring

```python
# python2
isinstance('', basestring) # True
isinstance(u'', basestring) # True
```

在 Python2 中处理字符串编码问题的时候，经常会让人感到疑惑，我究竟是要调用 decode 方法还是 encode 方法呢？哪怕你混用 decode 方法和 encode 方法都是没有问题的，不会有异常抛出。

```python
# python2
s = ''
print(type(s)) # str
s.encode('utf-8') # 错误调用，不会报错
s.decode('utf-8') # 正确调用
```

但在 Python3 环境中，这两个类型就完全不同了。

Python3 中的正确用法
---

你如果去查看 Python3 中的 str 和 bytes 对象的方法，你会看到他们方法其实是大部分相同的，如 split, startswith 等等一类字符串的处理的方法两者都是有的。最重要的不同就是，str 只有 encode 方法，而 bytes 只有 decode 方法

```python
# python3
s = ''
s.encode('utf-8')
e.decode('utf-8') # AttributeError: 'str' object has no attribute 'decode'

# 其对应的方法参数还是需要和原对象一致
b = b''
b.startswith('') # TypeError: startswith first arg must be bytes or a tuple of bytes, not str
```

除此之外，在 Python2 中，很多时候为了类型转换，可能就直接通过 str(obj) 来进行操作，之前这样处理是没问题的，但现在这种处理方式不可行了

```python
# python3
b = b'hello world'
str(b) # b'hello world'
```

上述代码可以看到，通过 str 之后，bytes 的确是变成了 str 类型，但是其多出了一个 b 的前缀。这里的正确姿势是

```python
# python3
if isinstance(b, bytes):
    b = b.decode('utf-8')
else:
    b = str(b)
```

除此以外，不少的标准库的函数接收的类型也限制了，例如 hashlib 中的方法只接收 bytes 类型，json.loads 只接收 str 类型等等。

写在最后
---

我个人是比较喜欢 Python3 的更新的，默认的 utf-8 编码解决了很多的问题。

相比于 Python2，可能 Python3 的处理要繁琐一点，但安全性会好很多，一些很奇怪的问题可以及时发现。例如 decode 和 encode 方法的明确。同时，因为这些变化，我们需要在 bytes 可能出现的地方留心（一般是程序外部来的数据），进行类型转换，数据交互的层面统一使用 str 进行处理。

与 Python2 相比，str 和 bytes 的命名其实也更贴近实际的情况。我是这样去记两者的关系的：str 是 unicode 的 code 的序列，可认为是该字符在世界的唯一标识（code point），而 bytes 则是 str 通过某种编码（utf-8）实际保存的二进制数据。unicode 是种协议，而 utf-8 是这种协议的某种实现方式。

参考
---
1. [unicode](https://www.joelonsoftware.com/2003/10/08/the-absolute-minimum-every-software-developer-absolutely-positively-must-know-about-unicode-and-character-sets-no-excuses/)
2. [Python3 Unicode HOWTO](https://docs.python.org/3/howto/unicode.html)
3. [Python2 Unicode HOWTO](https://docs.python.org/2/howto/unicode.html)

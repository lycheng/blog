---
layout: post
title: Python mock 的使用
tags: [python, mock, unittest, patch]
---

以 ubuntu 18.04 上的 Python 3.6 为测试环境，Python 3.3 以前是需要额外安装 mock 库，现在是内置的标准库。

Base
---

mock 属于 unittest 的一部分，一般用于单元测试时去模拟调用外部系统的函数，类，如网络请求，操作系统的实时数据等等。下面是一个简单的例子

```python
import requests

def func():
    req = requests.get("http://www.baidu.com")
    return req.content
```

现在需要对上述代码进行测试，或者对依赖该模块的代码进行测试，需要对其网络请求进行模拟。

```python
from unittest import mock

import requests

from core import func


def mock_requests_get(s):
    class Response:
        content = "mock_requests_get"

    return Response()


class MockResponse:
    content = "mock_response"


@mock.patch('requests.get', mock_requests_get)
def mock_requests_with_decorator():
    print(func())


@mock.patch('requests.get')
def mock_requests_with_decorator_and_args(mock_get):
    assert mock_get == requests.get
    print(func()) # <MagicMock name='get().content' id='140081676909704'>


if __name__ == "__main__":

    # 1
    with mock.patch('requests.get', mock_requests_get):
        print(func())

    # 2
    mock_requests_with_decorator()

    # 3
    mock_requests_with_decorator_and_args()

    # 4
    mock_get = mock.Mock(return_value=MockResponse())
    requests.get = mock_get
    print(func())
```

上述示例中的 1, 2 两种写法个人比较推崇，因为只会在使用到的时候才会去修改对应的代码。

除此以外还有挺多有意思的用法，如 `side_effect`

```python
from unittest import mock

mock = mock.Mock()

mock.side_effect = range(1, 10)

for i in range(11):
    print(mock()) # 1, 2, 3, ..., 9
# raise exception when i == 10

mock = mock.Mock()
mock.side_effect = KeyError('foo')
mock()
# KeyError: 'foo'
```

与固定的 `return_value` 不同，`side_effect` 可以是一个可迭代对象，也可以是一个异常，相比于前者能更简单的模拟更多的情况。

Mock
---

在最开始的代码中 `mock_requests_with_decorator_and_args` 用到了 Mock 类，但实际上没有指定具体的实现，却不妨碍代码继续执行。

```python
from unittest import mock

mock = mock.Mock()

print(mock)
print(mock.b) # <Mock name='mock.b' id='140415940033728'>
print(mock.b.assert_called) #
```

Mock 是一个非常灵活的类，除了一些 magic method 和一些属性（见 [这里](https://docs.python.org/3/library/unittest.mock.html#id3) 的解释，解析器会对这些属性和方法的调用有额外的优化，不一定遵循规则）以外，调用一般的方法和属性都会自动生成一个出来。

查看代码 `/usr/lib/python3.6/unittest/mock.py` 可以看到，Mock 类是重写了 `__getattr__`，`__setattr__` 还有 `__call__` 一类 magic method 并且记录了调用次数，返回预定义的返回值 `return_value` 等等，可用于监控是否进行了调用。

Patch
---

Patch 则是使用 Python 的上下文管理（Context Manager）的用法，重写了 `__enter__` 和 `__exit__`。同样在 `mock.py` 同一个代码文件中，可以参考下具体的写法。简单来说就是 `__enter__` 保存原有的 import，在 `__exit__` 的时候去掉 mock 的代码，将原有的 import 重新设置。

这里面涉及到很多的 `__getattr__`，`__setattr__` 和 `__import__` 的用法，有兴趣的话可以详细看下。

References
---

  1. https://docs.python.org/3/library/unittest.mock.html#quick-guide

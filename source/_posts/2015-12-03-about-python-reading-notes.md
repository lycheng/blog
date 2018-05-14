---
layout: post
title: 关于 《Python 学习笔记》
tags: [python]
---

最近看 [Python 学习笔记][1] 记录下一些之前没注意的东西。

## 环境

### 虚拟机初始化顺序

1. 创建解释器和主线程状态对象,这是整个进程的根对象。
2. 初始化内置类型。数字、列表等类型都有专门的缓存策略需要处理。
3. 创建 `__builtin__` 模块,该模块持有所有内置类型和函数。
4. 创建 sys 模块,其中包含了 sys.path、modules 等重要的运行行期信息。
5. 初始化 import 机制。
6. 初始化内置 Exception。
7. 创建 `__main__` 模块,准备运行行所需的名字空间。
8. 通过 site.py 将 site-packages 中的第三方方扩展库添加到搜索路径列表。
9. 执行行入入口口 py 文文件。执行行前会将 `__main__.__dict__` 作为名字空间传递进去。
10. 程序执行行结束。
11. 执行行清理操作,包括调用用退出函数,GC 清理现场,释放所有模块等。
12. 终止止进程。

### 对象

一切皆对象，引用计数来进行拉圾回收机制。

```python
import sys
a = 456
sys.getrefcount(a)  # 2
b = a
sys.getrefcount(a)  # 3
del b
sys.getrefcount(a)  # 2
```
初始化之后计数是 2 的原因是，当你调用 `sys.getrefcount` 的时候，`a` 复制了一遍，所以就是 2 了。

### 名字空间

python 中的变量，更多的时候用名字来表示会更好理解，在 Py 里面，变量仅仅用来指向内存中的某一个实际的对象 `name->object`，所以在函数传值也仅仅是告诉函数需要用到的参数是哪个，如下

```python
def alter(bar):
    bar.append(4)
    bar = [0,1]

foo = [1,2,3]
print 'foo', foo # [1, 2, 3]
alter(foo)
print 'foo', foo # [1, 2, 3, 4]
```

上述的代码中，`bar = [0, 1]` 实际上是改变了函数名字空间内的 `bar` 的指向而已，不对函数外的 `foo` 有任何影响。

在 Py 中，可以通过函数 `globals` 和 `locals` 查看模块的名字空间，以及函数内的名字空间，在函数外部调用的时候，两者相同。

也可以通过 `<module>.__dict__` 查看其它模块的名字空间。

### 内存管理

总是引用传递。

避免循环引用。

## 内置类型

### int

`int` 类型是特殊处理的，[-5, 257) 之前的小数字通过固定数组来存储，通过下标来获得指针。其它情况通过 `PyIntBlock` 缓存区存储整数类型，直到进程结束，这部分内存才还给操作系统。

所以对大整数一类的操作需要谨慎，多使用 `xrange` 去替代 `range`，这样一些内存就能省下来。

### float

精度不足，一些小数的操作需要谨慎

```python
3 * 0.1 == 0.3 # False
```

使用 `Decimal` 去替代 `float` 就能解决问题。内存方面也采取和 `int` 的策略，但没有针对小的浮点数去处理。

### string

动态生成的字符串可用 `intern` 进行池化，简单来说，就是让这个字符串变成一个引用，而不是一个每次都重新生成的字符串，用于节省内存。

### list

列表对象和存储元素指针的数组是分开的两块内存，后者在堆上分配。

如果需要频繁进行元素的增删，可用数组 `array` 代替，这个直接内存数据，省了创建对象的开销。

### dict

要去判断两个字典间的差异，可以使用视图。

``` python
d1 = dict(a = 1, b = 2)
d2 = dict(b = 2, c = 3)

v1 = d1.viewitems()
v2 = d2.viewitems()

v1 & v2 # {('b', 2)}
v1 | v2 # {('a', 1), ('b', 2), ('c', 3)}
v1 - v2 # {('a', 1)}
```
视图还有一个很实用的地方就是，当你更新了原来的 `dict` 之后，视图也会同时更新。

## 函数

### 参数

默认参数使用可变类型时需要注意，它的值在函数创建的时候就存在了，这个很容易出错

```python
def fun(a, b=[]):
    b.append(a)
    return b

test(1) # b = [1]
test(2) # b = [1, 2]
test(1, []) # return [1] b = [1, 2]
test(3) # b = [1, 2, 3]
```
需要用这类可变类型的参数时，可以 `b=None` 再在函数内进行判断。

### 作用域

函数参数和内部变量都存在 `locals` 的名字空间中。

名字的查找顺序为 `locals -> enclosing function -> globals -> __builtins__`

### 闭包

当函数离开创建环境时，依然保留其上下文状态。下例，是因为 x 的添加到 `func_closure` 列表中，引用计数增加了。

```python
def test():
    x = [1, 2]
    print hex(id(x)) # same

    def a():
        x.append(3)
        print hex(id(x))

    def b():
        print hex(id(x))

    return a, b
a, b = test()
a() # same
b() # same
```

### 协程

```python
def coroutine():
    print 'start'
    result = None

    while True:
        s = yield result
        result = s.split(',')

c = coroutine()

# 启动协程
c.send(None)

# 向协程发送消息
print c.send('a,b')
print c.send('c,d')

c.close()
```
上面的代码的流程如下：

1. 创建协程后对象,必须使用用 send(None) 或 next() 启动。
2. 协程在执行行 yield result 后让出执行行绪,等待消息。
3. 调用用方方发送 send("a,b") 消息,协程恢复执行行,将接收到的数据保存到 s,执行行后续流程。
4. 再次循环到 yeild,协程返回
5. 直到关闭或被引发异常

## 模块

### 搜索路径

1. 当前的进程根目录
2. PYTHONPATH 环境变量指定的路径列表
3. Python 标准库的目录列表
4. 路径文件保存的目录

当进程启动之后，所有的这些路径都被组织到 `sys.path` 列表中，任何 `import` 操作都会按照 `sys.path` 来查找模块。

进程中的模块对象都是唯一的。在首次成功导入之后，模块对象被添加到 `sys.modules` ，以后的操作都总是先检查模块对象是否已经存在。

## 类

### 字段和属性

字段（field）和属性（property）是不同的，

1. 实例字段存储在 `instance.__dict__`, 代表单个对象实体的状态。
2. 静态字段存储在 `class.__dict__`, 为所有同类型实例共享。
3. 必须通过类型和实例对象才能访问字段。
4. 以双下划线开头的 `class` 和 `instance` 成员视为私有，会被重命名。(module 成员不变)

属性 (Property) 是由 getter、setter、deleter 几个方方法构成的逻辑，在查找中，属性优先于实例字段。


```python
class User(object):
    @property
    def name(self):
        return self.__name

    @name.setter
    def name(self, value):
        self.__name = value

u = User()

print u.__dict__ # {}
u.name = "lycheng"
print u.__dict__ # {'_User__name': 'lycheng'}
print u.name
```

### 方法

特殊方法

1. `__new__`: 创建对象实例。
2. `__init__`: 初始化对象状态。
3. `__del__`: 对象回收前被调用用。

### 继承
多重继承成员搜索顺序,也就是 mro (method resolution order) 要稍微复杂一一点。归纳一一下就
是:从下到上 (深度优先,从派生生类到基类),从左到右 (基类声明顺序)。mro 和我们前面面提及的成
员查找规则是有区别的，`__mro__` 列表中并没有 instance。所以在表述时,需要注意区别。

super 依照 mro 搜索顺序搜索基类成员

## 装饰器

### 类装饰器

```python
def singleton(cls):
    def wrap(*args, **kwargs):
        o = getattr(cls, "__instance__", None)
        if not o:
            o = cls(*args, **kwargs)
            cls.__instance__ = o
        return o
    return wrap


@singleton
class A(object):
    def __init__(self, x):
        self.x = x

print A

a, b = A(1), A(2)
print a is b # True
```

将 func wrap 换成 class wrap

```python
def singleton(cls):
    class wrap(cls):
        def __new__(cls, *args, **kwargs):
            o = getattr(cls, "__instance__", None)
            if not o:
                o = object.__new__(cls)
                cls.__instance__ = o
            return o
    return wrap

@singleton
class A(object):
    def test(self): print hex(id(self))

a, b = A(), A()
print a is b
```

创建继承自自原类型的 class wrap,然后在 `__new__` 里里面面做手手脚就行行了。上述这个代码可以通过装饰器去修改类型的一些函数，也可以用以下的代码去增加额外的成员。

```python
def action(cls):
    cls.func = staticmethod(lambda: 'hello world')
    return cls

@action
class Func(object):
    pass

print Func.func()
```

## 元类

元类的关系

```python
Data = type("Data", (object,), {"x": 1}) # 实际创建类型的指令
class = metaclass(...)       # 元类创建类型
instance = class(...)        # 类型创建实例

instance.__class__ is class  # 实例的类型
class.__class__ is metaclass # 类型的类型
```

自定义元类，需要注意的是，自定义元类都是从 `type` 继承而来，并且是重写 `__new__` 方法

```python
# -*- coding: utf-8 -*-
class InjectMeta(type): # 从 type 继承
    def __new__(cls, name, bases, attrs):
        t = type.__new__(cls, name, bases, attrs)

        def print_id(self):
            print hex(id(self))

        t.print_id = print_id  # 为类型对象添加实例方方法。
        t.s = "Hello, World!"  # 添加静态字段。
        return t

    def __init__(cls, name, bases, attrs):
        print 'class', cls
        type.__init__(cls, name, bases, attrs)

class Data(object):
    __metaclass__ = InjectMeta

print Data.s
Data().print_id()
```

以下是使用元类实现的静态类和密封类（禁止继承）

```python
class StaticClassMeta(type):
    def __new__(cls, name, bases, attr):
        t = type.__new__(cls, name, bases, attr)

        def ctor(cls, *args, **kwargs):
            raise RuntimeError("Cannot create a instance of the static class!")
        t.__new__ = staticmethod(ctor)
        return t

class Data(object):
    __metaclass__ = StaticClassMeta
```

```python
class SealedClassMeta(type):
    _types = set()
    def __init__(cls, name, bases, attrs):
        if cls._types and set(bases):
            raise SyntaxError("Cannot inherit from a sealed class!")
        cls._types.add(cls)

class Data(object):
    __metaclass__ = SealedClassMeta

class B(Data):
    pass
```

## 标准库

### heapq

最小堆，完全平衡二叉树，所有节点都小于其子节点

```python
from heapq import heappush, heappop
from random import sample

src = sample(xrange(100), 10)

heap = []
for x in src:
    heappush(heap, x) # type(heap) == 'list'

while heap:
    print heappop(heap)
```

## 参考文档

 1. https://github.com/qyuhen/book
 2. https://www.python.org/dev/peps/pep-3129/


  [1]: https://github.com/qyuhen/book

---
layout: post
title: Python 中的虚拟基类
tags: [python]
---

Python 这类动态类型语言，Duck Typing 是一个比较突出的优点。属性，方法的惰性计算，给代码的编写带来了高度的灵活性。当然有利有弊，Duck Typing 这东西在 Python 中更多是一种规范，而不是强制约束。如果我们需要约束这些接口，需要做些什么呢？

运行时检查
---

下面看一下简单的例子，这是个比较常见的场景，通过基类定义了一系列的接口，然后继承的子类根据自己特定的需求实现具体的接口。

```python
class Animal:
    def action(self):
        raise NotImplementedError()

class Bird(Animal):
    def action(self):
        return "fly"

class Dog(Animal):
    pass

bird = Bird()
dog = Dog()

animals = [Bird(), Dog()]
for animal in animals:
    print(animal.action())

# 输出如下：
# fly
# Traceback (most recent call last):
#  File "test.py", line 22, in <module>
#    print(animal.action())
#  File "test.py", line 4, in action
#    raise NotImplementedError()
# NotImplementedError
```

我们可以看到，Animal 的 action 的确是会抛出异常，但如果子类实现了该方法，则相应的方法查找则会屏蔽掉基类的该方法而使用自己当前的版本。

这的确是能实现简单的抽象方法的概念，但是，该错误直到运行时才能暴露出来。极端点的情况，你可能还要去判断这个 name 是否可以调用，调用的参数对不对。

抽象基类
---

Python 本身是支持抽象基类的，最常用的是 collections 里面提供的一些抽象类。如常见的用于判断类型

```python
import collections
isinstance([], collections.MutableSequence) # True

# 还有数类型
import numbers
isinstance(12313.123, numbers.Number) # True
```

如果我们用来实现序列，那就更简单了

```python
import collections

class Sequence(collections.MutableSequence):
    pass

seq = Sequence()

# Traceback (most recent call last):
#   File "test.py", line 8, in <module>
#     seq = Sequence()
# TypeError: Can't instantiate abstract class Sequence with abstract methods # __delitem__, __getitem__, __len__, __setitem__, insert
```

跟之前的代码相比，这个是在实例化的时候进行检查的，你继承了某些抽象类之后，在实例化的时候，会去检查是否有实现具体的方法。collections 中还有其它的基础类型的抽象类，如果要实现相应协议的话，可以去看看。

自定义抽象类
---

同样的，我们也可以实现自己的抽象基类，然后通过具体的子类去定义具体的行为

```python
import abc

class Base(abc.ABC):
    @abc.abstractmethod
    def name(self):
        ''' just docs
        '''
        return "Base"

class A(Base):
    def name(self):
        return self.__class__.__name__

a = A()
print(a.name())
```

上述代码中，如果类 A 不定义 name 的方法，则会抛出 TypeError 的异常。但实际上，如果我们去修改 Base 中 name 的函数签名，例如加个参数什么的，上述代码依旧是能正常运行的。这样子的话，其实 Python 本身支持的抽象方法只是检验是否有这个可调用的类成员。

```python
class A(Base):
    name = print
    # name = 1
    # TypeError: 'int' object is not callable
```

再看鸭子类型
---

最开始接触 Python 的时候，觉得这一特性很好用啊，例如我要处理一大串对象，只要里面的对象实现了这个方法，就可以都扔到同一个队列里面进行处理，但这个东西很容易滥用。如果你在处理之后需要相应的回调，这又必须跑去实现回调函数，但因为函数调用的检查是在处理该对象的时候，如果忘了某些对象的相应方法，可能最后上线才能发现问题。

接触了一阵子的 golang，使用 interface 之后简直如沐春风，运行时的错误在编译阶段就能避免了，减少了很多查 bug 的时间。在这一点上，如果需要使用类似的特性，python 对程序员的能力要求反而更高了。

我个人比较推崇先去判断这个对象是什么类型，如判断它是不是可以迭代的，可调用的，这样子，你就知道了该对象支持什么样的方法。如果不行再去判断是否实现了具体的方法。当然，运行时去判断这些东西是有消耗的，具体的需要就要看业务场景了。

灵活是抛弃了一些约束的结果，没有了约束效率就会低下，哪样较好没有绝对的定论。

参考
---

1. [Python abc 库的文档](https://docs.python.org/3/library/abc.html)

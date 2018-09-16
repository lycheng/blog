---
layout: post
title: Python metaclass 的使用
tags: [python, metaclass]
---

之前有个需求，需要去监控某些类的所有的函数调用的耗时，当时团队里面最开始的方案是通过继承某个基类来实现

```python
import functools
import types
import inspect
import time

WRAPPER_ASSIGNMENTS = ('__module__', '__name__', '__doc__', '__self__')


class Timer(object):

    def __init__(self, key):
        self.key = key
        self.ts = time.time()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        print("---- {} consumes: {}".format(self.key, time.time() - self.ts))


class MonitorBase(object):
    '''
    base interceptor for performance monitor system.
    '''
    def __getattribute__(self, attrname):

        # 防止死循环
        # https://stackoverflow.com/questions/13538324/python-avoiding-infinite-loops-in-getattribute
        attrvalue = super(MonitorBase, self).__getattribute__(attrname)

        if not inspect.ismethod(attrvalue):
            return attrvalue

        @functools.wraps(attrvalue, WRAPPER_ASSIGNMENTS)
        def warpFunc(_self, *args, **kwargs):

            raise_ex = None
            key = "{}.{}".format(self.__class__.__name__, attrname)
            with Timer(key):
                result = None
                try:
                    result = attrvalue(*args, **kwargs)
                except Exception as ex:
                    raise_ex = ex

            if raise_ex is not None:
                raise raise_ex
            return result

        # https://stackoverflow.com/questions/37455426/advantages-of-using-methodtype-in-python
        bound_method = types.MethodType(warpFunc, self, type(self))
        return bound_method


class Worker(MonitorBase):
    def work(self):
        print("exec work")


class WorkerChild(Worker):
    def work(self):
        print("exec work")


w = Worker()
w.work()

wc = WorkerChild()
wc.work()
```

这是团队里面一个人写的初始版本，十分的清晰易懂，通过改写 `___getattribute__` 方法，只对方法调用进行监控，对异常和返回值都原样处理。唯一的不同就是调用方法时使用 Timer 进行耗时计算。

这样子的写法的好处是，只要是基类继承了该监控类，后续的子类也会有相同的效果，但这里也衍生出另外的问题

 - 因为 `__getattribute__` 是实例方法，对类中的 staticmethod 和 classmethod 方法没有效果
 - 每次调用都会重新把方法重新绑定到 self 中

后续的讨论中主要是担心第二点会带来性能损耗。哪怕你对某些函数设置了标记位从而不去进行监控，因为你重写了这个 `__getattribute__` 方法，在实际使用上还是得去重新绑定到 self 上去。

metaclass
---

后面有人提出了元类的改进方案，具体代码如下

```python
import functools
import inspect
import time

TIMED_METHOD_FLAG = "__is_timed_method__"


class Timer(object):
    def __init__(self, key):
        self.key = key
        self.ts = time.time()

    def __enter__(self):
        return self

    def __exit__(self, exc_ty, exc_val, tb):
        print("---- {} consumes: {}".format(self.key, time.time() - self.ts))


def timed_wrapper(f, stats_key):
    @functools.wraps(f)
    def wrapper(*args, **kwargs):
        with Timer(stats_key):
            return f(*args, **kwargs)
    return wrapper


class MonitorMeta(type):

    @staticmethod
    def not_timed(f):
        setattr(f, TIMED_METHOD_FLAG, False)
        return f

    @staticmethod
    def is_timed_method(f):
        return getattr(f, TIMED_METHOD_FLAG, True)

    @staticmethod
    def need_to_timed(fname, f):
        # staticmethod or classmethod returns False
        if not inspect.isfunction(f):
            return False

        if not MonitorMeta.is_timed_method(f):
            return False

        # is magic method
        if fname.startswith("__") and fname.endswith("__"):
            return False
        return True

    def __init__(self, clsname, bases, attrs):
        super(MonitorMeta, self).__init__(clsname, bases, attrs)
        for attrname, attrvalue in attrs.items():
            if not MonitorMeta.need_to_timed(attrname, attrvalue):
                continue
            setattr(self, attrname, timed_wrapper(attrvalue, ".".join((clsname, attrname))))


# class C(metaclass=MonitorMeta): # work at >=python3.5
class C(object):

    __metaclass__ = MonitorMeta

    def haha(self):
        print("hah")

    @staticmethod
    def hehe():
        print("asdads")

    @classmethod
    def heihei(cls):
        print("asdads")


class D(C):
    def __init__(self, hi):
        self.hi = hi

    def show(self):
        print("Hello world")

    @MonitorMeta.not_timed
    def work(self):
        print("work")


d = D(123)
d.haha()
d.show()
d.work()
```

这里涉及的改进是

 1. 通过装饰器去设置标记位 `TIMED_METHOD_FLAG`，标记某些方法不进行收集，默认情况下除去一些 magic method 都进行收集
 2. 可以感知到 staticmethod 和 classmethod，但需要进一步的判断方法
 3. 只有需要收集的方法会有额外的操作，别的方法没有额外的操作

但使用元类又有一个比较纠结的问题，在上述的例子中，C 使用了元类，D 继承 C，如果通过 D 的实例调用方法 `hah` 则实际上记录到的是 `C.hah`。

这里，我们希望知道的是具体的类对象的调用的时延，使用元类（之前的继承的方法没有这个问题）的话，可能会有一些这样造成困惑的数据。

conclusion
---

这是我第一次涉及到 Python 的元类相关的具体应用，最开始理解起来觉得比较绕，但实际上你记住 Python 里面一切皆对象就很容易理解了，类其实也是一种对象，我们可以通过元类去产生具体的类，由具体的类再产生对象

```python
MyClass = MetaClass()
my_object = MyClass()
```

后续参考中的答案写得非常清晰，强烈推荐阅读。

references
---

 1. https://stackoverflow.com/questions/100003/what-are-metaclasses-in-python

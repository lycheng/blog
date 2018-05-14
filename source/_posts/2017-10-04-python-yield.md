---
layout: post
title: Python yield 用法示例
tags: [python]
---

本文主要关注 Python 中 yield 的相关用法，包括 Python3 中新增的特性。

基础用法
---

```python
import inspect

def looper():
    print("started")
    for i in range(3):
        yield i

# 此时还没开始执行
# 后面也可以看到他的状态为 GEN_CREATED 即等待开始执行
loop = looper()
print(inspect.getgeneratorstate(loop)) # GEN_CREATED

# 调用 next 方法，则往前执行到第一个 yield 后暂停
# 等待下一次调用 next
print(next(loop))
# started
# 0

print(inspect.getgeneratorstate(loop)) # GEN_SUSPENDED
print(next(loop)) # 1

loop = looper()
# for 语法中它会自动帮你处理 next 调用
# 还会自动处理 StopIteration 的异常并安全退出
for i in loop:
    print(i)
```

上述代码演示的是 yield 最常见的用法，与普通的函数调用不同，函数体内有 yield 关键字的，并不是像普通的函数一样执行，而且需要手动触发其第一次执行，这里就是通过 next 方法。

这里还有另一种更简单的写法

```python
# 生成器表达式，与 [] 的不同，这里是惰性求值的
loop = (x*x for x in range(3))
print(inspect.getgeneratorstate(loop)) # GEN_CREATED
print(next(loop)) # 0
print(inspect.getgeneratorstate(loop)) # GEN_SUSPENDED
```

简单来说就是 **保留现场，惰性求值**。

send, close, throw
---

yield 生成器除了可以返回值以外，外部还可以通过 send 方法与其通信。

```python
def adder():
    ret = 0
    while True:
        i = yield ret
        ret += i

looper = adder()
# looper.send(1)
# TypeError: can't send non-None value to a just-started generator

print(next(looper))  # 0
print(next(looper)) 
# TypeError: unsupported operand type(s) for +=: 'int' and 'NoneType'
# 继续调用 next 传进去的是一个 None，+= 计算时便出现了问题

# 第一次调用 next 去到 yield 处返回 ret，此时值为 0，并暂停
# 后面的代码调用 send 的时候从暂停处恢复，ret += 1 并 yield 返回结果，继续暂停
for n in range(1, 10):
    i = looper.send(n)
    print(i) # 1, 3, 6 ...
```

这里需要注意的激活生成器可以调用 `gen.send(None)` 来处理，但上述的代码中并没进行对接收到的数据的类型检查，加法会出现问题。

send 是用在和生成器正常交互的，close 和 throw 则是用在关闭或者说处理相应异常逻辑的。相关文档 [点这里][1]。

```python
looper.close()
print(inspect.getgeneratorstate(looper))  # GEN_CLOSED
```

close 在 yield 暂停处 raise 一个 GenerationExit 的异常（需要注意的是，这类异常不能用通用的 Exception 去捕捉）。如果不处理这异常，则在调用方不会报错，如果忽略该异常，则会报 RuntimeError。

```python
def echo(v=None):
    while True:
        try:
            v = (yield v)
        except Exception as ex:
            print("common exception")
        except GeneratorExit as ex:
            print("gen exit")
            return

g = echo()
next(g)
g.close()
# RuntimeError: generator ignored GeneratorExit
```

throw 则是外部传入一个异常，需要生成器自身去处理。

```python
def echo():
    i = 0
    while True:
        i += 1
        try:
            yield i
            print('aha')
        except TypeError as ex: # 如果异常不处理，则会往上冒泡，传给调用方
            print(ex, i)
        except GeneratorExit:
            print("gen exit", i) # 这个会在程序结束的时候自动调用
            return


g = echo()
print("from generator:", next(g))
print(g.throw(TypeError, "TypeError: from caller")) # 2
print(next(g))
print("END")
```

如果处理了 throw 传入的异常，则会往前执行到下一个 yield 处，并且将那个 yield 的返回值作为 throw 的返回值。上述代码一个有意思的地方是，GeneratorExit 会在程序结束时自动调用，一般还是来说不用主动处理该异常。

yield from
---

yield from 是一个 Python3.3 之后新增的 [语法][2]，对于简单的生成器，`yield from iterable` 是这个 `for item in iterable: yield item` 的缩写。下面举一个简单的例子

```python3
import inspect

def adder():
    ''' 子生成器
    '''
    ret = 0
    while True:
        n = yield
        if n is None:
            break
        ret += n
    # 作为 yield from 的返回值
    # 一般的生成器 send(None) 之后将抛出 StopIteration 的异常
    return ret  # 作为 yield from 的返回值

def worker(result, key):
    ''' 委派生成器
    '''
    while True:
        rv = yield from adder()
        result[key] = rv

def main():
    ''' 调用方
    '''
    result = {}
    for i in range(1, 3):
        w = worker(result, i)
        # 这里每次都会新建一个委派生成器，原因是为了传入 i 作为 reuslt 的 key 值
        # 实际上也可以放到循环外，result 改成 list 就好
        next(w)
        for j in range(i, i+3):
            w.send(j)
        w.send(None)
        # 这里 send None 之后委派生成器会更新 reuslt 的值，再起另一个生成器继续等待
        print(inspect.getgeneratorstate(w))  # GEN_SUSPENDED
    print(result)

main()
```

上述代码就简单的演示了下 yield from 是怎么工作的。yield from 的实际功能相当复杂，这里篇幅有限就不展开来讲。

这里面比较关键的是，委派生成器（即介于调用者和子生成器中间的函数）对于 send 的处理。通过委派生成器调用 send 都会直接传给子生成器，send(None) 时，会调用子生成器的 \_\_next\_\_ 方法，send 的参数不为 None 则调用子生成器的 send 方法。

如果子生成器抛出的异常为 StopIteration，那么委派生成器恢复执行，其它异常则照常抛出，需要委派生成器自己去处理。子生成器退出时，return expr 语句将会触发 StopIteration(expr) 的异常。

写在最后
---

以前写代码的时候比较少用 yield 这个语法，单纯的 yield 还好，如果是加上类似协程的相关代码后，就感觉难以理解了。相比 return 处理起来就习惯多了，学习的时候也更多是知道这个语法的用法。

后来 Python3 之后很多接口改成了迭代器的模式，自己才开始去看类似的代码，写了下感觉还好，用来处理数据生成和逻辑代码的解耦真是太舒服了。


参考
---

1. [PEP-255][3]
2. [PEP-380][4]
3. [Stackoverflow 上一个关于 Python3 yield from 语法的问题][5]
4. [Python3 yield from 解析](http://flupy.org/resources/yield-from.pdf)


  [1]: https://docs.python.org/3/reference/expressions.html#generator-iterator-methods
  [2]: https://docs.python.org/3/whatsnew/3.3.html#pep-380
  [3]: https://www.python.org/dev/peps/pep-0255/
  [4]: https://www.python.org/dev/peps/pep-0380/
  [5]: http://stackoverflow.com/questions/9708902/in-practice-what-are-the-main-uses-for-the-new-yield-from-syntax-in-python-3

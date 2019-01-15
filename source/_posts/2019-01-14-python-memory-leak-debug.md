---
layout: post
title: Python 内存暴涨的问题排查
tags: [python, memory-leak, debug]
---

在工作的时候和同事检查一个 Python 程序的问题的时候没有头绪，日志看了下也基本正常。于是在网上搜了下看下别人的思路，发现了 [objgraph][1] 这个库。

抱着试一下的心态安装了试了下，然后发现发问题所在

```
BindParameter    181236 +180366
_anonymous_label 181322 +180365
dict             229511 +180160
...

```

上述输出是 `objgraph.show_growth()` 的输出，该函数会输出类实例的增量的变化。上述输出可以看到三个类型实例变量的增量是同步的，而前两个类型又是 SQLAlchemy 库的类型，于是怀疑是数据库的问题。

后来追查下去，发现变化在于传入了一个千万级别的 ID 数组，使用该数组作为子查询来查询。

除此以外其实还有像 `objgraph.get_leaking_objects()` 这样打印出没有被引用的对象（按其 [文档说明][2] 有 bug）以及通过图来表示对象的引用关系，用来 debug 真是再合适不过了。

由于当时 debug 的环境是 Python 2.6 的，现在 Python 3 有内置的库，如 [tracemalloc](https://docs.python.org/3/library/tracemalloc.html)，该库在 Python 3.4 开始引入，初步看了下，tracemalloc 可以提供比 gc 库更底层的功能。

One-More-Thing
---

我刚看这个 `objgraph.show_growth()` 的例子的时候，以为是用了全局变量去存储上次的结果来做 diff，然后看了代码觉得挺巧妙的

```python
def show_growth(limit=10, peak_stats={}, shortnames=True):
    """Show the increase in peak object counts since last call.

    Limits the output to ``limit`` largest deltas.  You may set ``limit`` to
    None to see all of them.

    Uses and updates ``peak_stats``, a dictionary from type names to previously
    seen peak object counts.  Usually you don't need to pay attention to this
    argument.

    The caveats documented in :func:`typestats` apply.

    Example:

        >>> show_growth()
        wrapper_descriptor       970       +14
        tuple                  12282       +10
        dict                    1922        +7
        ...

    .. versionadded:: 1.5

    .. versionchanged:: 1.8
       New parameter: ``shortnames``.

    """
    gc.collect()
    stats = typestats(shortnames=shortnames)
    deltas = {}
    for name, count in iteritems(stats):
        old_count = peak_stats.get(name, 0)
        if count > old_count:
            deltas[name] = count - old_count
            peak_stats[name] = count
    deltas = sorted(deltas.items(), key=operator.itemgetter(1),
                    reverse=True)
    if limit:
        deltas = deltas[:limit]
    if deltas:
        width = max(len(name) for name, count in deltas)
        for name, delta in deltas:
            print('%-*s%9d %+9d' % (width, name, stats[name], delta))
```

关键在于 `peak_stats` 这个变量，其默认值为 `{}`。函数在 Python 中也是一种对象，而函数参数则是对象的属性，声明之后将一直保存在内存中（传入另一个值则像是屏蔽了该变量，而下次再使用默认值还是会是原来的变量）。

以前遇到过一个 bug，在函数中加入了一个时间值，其默认值设为 `datetime.now()` 则不传入值的时候，该值永远是程序启动时的时间。

在这段代码中则使用该默认值来保存当前的对象的分配情况。在当前调用时，存入该次的状态，下次继续调用时，则可以比较两次调用间的 diff 了。不过这种将状态通过一些语言特性隐藏起来了的写法，感觉还是不应该出现在普通的代码中，这样子特殊用途的代码则可以考虑使用。

References
---

  - [Hunting memory leaks in Python][3]
  - [使用gc、objgraph干掉python内存泄露与循环引用！][4]


  [1]: https://mg.pov.lt/objgraph/
  [2]: https://mg.pov.lt/objgraph/objgraph.html#objgraph.get_leaking_objects
  [3]: https://mg.pov.lt/blog/hunting-python-memleaks.html
  [4]: https://www.cnblogs.com/xybaby/p/7491656.html


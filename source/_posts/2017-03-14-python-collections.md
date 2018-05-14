---
layout: post
title: Python collections 库解析
tags: [python]
---

本文会简单介绍以下 python 标准库 collections 的相关使用。collections 在基础数据结构的基础上进一步封装了更高级的数据结构。

以下代码的环境为 python3.5.2

defaultdict
---

defaultdict 是 dict 的子类，基本用法与 dict 一样，在 key 不存在是，添加了 `default_facetory` 提供的默认值的功能。

定义如下

```
collections.defaultdict([default_factory[, ...]])
```

样例

```python
d = collections.defaultdict(int)
for i in range(10):
    d[i % 3] += 1
print(d)

# 实际上，上述的代码类似于
class D(collections.defaultdict):
    def __missing__(self, key):
        return self.default_factory(key)
d = D(int)

# 更简单的 lambda
def constant_factory(value):
    return lambda: value
d = collections.defaultdict(constant_factory(0))
```

最后，需要注意的是，defaultdict 生效只在 `obj[key]` 这种调用的模式下，如果使用 `obj.get` 则不会触发。

OrderedDict
---

基本用法也和 dict 一样，但是会记住 key 插入的顺序。它有两个额外的方法

 - `popitem(last=True)`: 弹出一个键值对，last=False的话则弹出第一个
 - `move_to_end(key, last=True)`: 移动某个 key 到最后（该 key 必须存在），last=False 则移动到第一

```python
od = collections.OrderedDict
d = od.fromkeys("abcde")
d.move_to_end("b", False)
for key, val in d.items():
    print(key) # b a c d e
```

下面是一些有趣的例子

```python
class LastUpdatedOrderedDict(collections.OrderedDict):
    ''' 每一个 key 新增或者修改操作都将其置于最后，可用于实现类似 LRU 的算法
    '''
    def __setitem__(self, key, value):
        if key in self:
            del self[key]
        super().__setitem__(key, value)
        
# 在初始化时指定 key 的排序依据
d = {'banana': 3, 'apple': 4, 'pear': 1, 'orange': 2}
collections.OrderedDict(sorted(d.items(), key=lambda t: t[0])) # sort by key
collections.OrderedDict(sorted(d.items(), key=lambda t: t[1])) # sort by value
```

Counter
---

同样是 dict 的子类，但是用于统计某个 key 的数量。它提供一些额外方法

1. `elements`: 返回所有大于 1 的 key，如果是 key 的数量大于 1 则会输出多次，同理，小于 0 则不输出
2. `most_common([n])`: 返回 key 和其对应的 count，默认输出全部数据，n=1 则返回 count 最大的
3. `subtract([iterable-or-mapping])`: 对应的 count 的相减
4. `fromkeys(iterable)`: 不可用，使用构造函数
5. `update([iterable-or-mapping])`: 已存在的 key 则 count 增加

常见的用法

```python
c = collections.Counter() # a new, empty counter
c = collections.Counter({'red': 4, 'blue': 2}) # from a mapping
c = collections.Counter(cats=4, dogs=8) # from keyword args

c = collections.Counter('hello') # from an iterable
print(c['l']) # 2

sum(c.values())                 # total of all counts
c.clear()                       # reset all counts
list(c)                         # list unique elements
set(c)                          # convert to a set
dict(c)                         # convert to a regular dictionary
c.items()                       # convert to a list of (elem, cnt) pairs
collections.Counter(dict(list_of_pairs))
c.most_common()[:-n-1:-1]       # n least common elements

b + c                           # 对应的 count 相加（相减）
b | c                           # 并集，相同取最大的 count
b & c                           # 交集，相同取最小的 count

+c # 相当于一个空的 counter 相加（或相减），但只保留整数 count 的 key
-c # 同上
```

deque
---

[deque](https://docs.python.org/3/library/collections.html#deque-objects) 是双端队列，首尾都可以进行插入和删除，同时也可以对某个位置进行插入。

需要注意的是，在初始化的时候指定了 maxlen，则在相应的更新操作则会造成已有的元素的移动

```python
d = collections.deque(maxlen=3)
d.extend(range(3)) # deque([0, 1, 2], maxlen=3)
d.append(4) # deque([1, 2, 4], maxlen=3)
d.insert(0, -1) # IndexError: deque already at its maximum size

d.pop()
d.insert(0, -1) # deque([-1, 1, 2], maxlen=3)
```

一些样例

```python
def tail(filename, n=10):
    ''' Return the last n lines of a file
    '''
    with open(filename) as f:
        return deque(f, n)

def delete_nth(d, n):
    ''' 删除第 n 个元素
    '''
    d.rotate(-n)
    d.popleft()
    d.rotate(n)
```

nametuple
---

[nametuple](https://docs.python.org/3/library/collections.html#collections.namedtuple) 是种用于强化 tuple 的可用性的数据结构。将 tuple 的 index 对应到 key，增强代码的可读性。

```python
Point = collections.namedtuple('Point', ['x', 'y'])
# Point = collections.namedtuple('Point', 'x y') # 也是可以的

# 增加的文档
Point.__doc__ += "Point with (x, y)"

p = Point._make((1, 2))
print(p.x == p[0]) # True
isinstance(p, tuple) # True
isinstance(p, Point) # True

p.x = 1 # AttributeError: can't set attribute
p = p._replace(x=2) # 新对象，x=2,y=2
```

```python
class Point(collections.namedtuple('Point', 'x y')):
    """ 这样则可以定义相应的方法
    
    下方 __slots__ = () 的设置则是为了不让对象生成 __dict__
    """
    __slots__ = ()
```

上述的代码可见，nametuple 同时具备类对象的属性引用和 tuple 的不可变性，实际上，你可以当做一个不可变属性的类对象来使用。

ChainMap
---

用于管理多个映射的数据结构。

```python
d1 = {1: 2, 3: 4, 5: 6}
d2 = {1: 1, 6: 7}

cm = collections.ChainMap(d1, d2)
cm.get(1) # 2

cm = collections.ChainMap(d2, d1)
cm.get(1) # 1

scm = cm.new_child() # ChainMap({}, {1: 2, 3: 4, 5: 6}, {1: 1, 6: 7})
pcm = cm.parents # ChainMap({1: 1, 6: 7})
```

在上述代码中，可以看到对于同样的 key，会根据初始化时的顺序来定优先级，可以在数据级别实现类似于作用域的查找关系。

ChainMap 把状态存储在 `maps` 这个 list 中，用户是可以编辑的，可以随意修改其中的顺序和值。 `new_child(m=None)` 则是可以根据当前的数据新建一个 ChainMap 但是在 list 的最前方插入一个参数中指定的 m，如果没有则是一个空的字典。`parents` 则返回去掉第一个 map 的 ChainMap。

一些有趣的例子

```python
# python 变量查找顺序的模拟
import builtins
pylookup = collections.ChainMap(locals(), globals(), vars(builtins))

class DeepChainMap(collections.ChainMap):
    ''' 实现层级更新和删除
    '''
    def __setitem__(self, key, value):
        for mapping in self.maps:
            if key in mapping:
                mapping[key] = value
                return
        self.maps[0][key] = value

    def __delitem__(self, key):
        for mapping in self.maps:
            if key in mapping:
                del mapping[key]
                return
        raise KeyError(key)
```

UserDict, UserList, UserString
---

比直接继承 dict, list, str 的区别就是，你可以直接使用 `self.data` 去获取数据。在里面就以 dict, list, str 来保存数据，相应的接口来操纵这个数据。

在查找相关资料的时候，我没有发现使用这几个类去集成和去继承相应的 str, dict 有什么具体的优势。相关信息可参考 [这里](http://stackoverflow.com/questions/7148419/subclass-dict-userdict-dict-or-abc)。

参考
---

1. [collections 模块源码](https://hg.python.org/cpython/file/tip/Modules/_collectionsmodule.c)

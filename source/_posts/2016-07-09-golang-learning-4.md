---
layout: post
title:  Golang 学习 4
tags: [golang]
---

前面 1 ~ 3 系列是看着书来写的，后面的是自己遇到的一些问题的总结。

## 类型转换

Golang 是强类型语言，类型的转换必须显式转换，interface 除外。

数值类型的转换，哪怕是底层类型相同的 `int` 和 `int32` 也不能直接赋值。同理，自定义的类型哪怕底层类型相同也不能直接赋值。

```go
type MyInt int

func main() {
    var i int = 100
    var j int32 = int32(i) // 显式类型转换
    var k MyInt = MyInt(i) // 显式类型转换
    fmt.Println(i)
    fmt.Println(j)
    fmt.Println(k)
}
```

string 类型的转化可以借助 package `fmt` 和 `strconv` 来进行。

interface 的类型转换没那么复杂，但两者必须是包含关系，例如 A interface 的方法包含 b 的方法，则可以 `a = A` 但不能 `A = a`，例如

```go
var w io.Writer
w = os.Stdout           // OK: *os.File has Write method
w = new(bytes.Buffer)   // OK: *bytes.Buffer has Write method
w = time.Second         // compile error: time.Duration lacks Write method

var rwc io.ReadWriteCloser
rwc = os.Stdout         // OK: *os.File has Read, Write, Close methods
rwc = new(bytes.Buffer) // compile error: *bytes.Buffer lacks Close method

w = rwc                 // OK
rwc = w                 // compile error: io.Writer lacks Close method
```

当一个变量赋值到一个 interface 变量时，再转换回来需要需要使用类型断言

```go
type Stringer interface {
    String() string
}

func str(val interface{}) string {
    switch s := val.(type) { // 类型断言
    case string:
        return "I'm String:" + s
    case Stringer:
        return s.String()
    default:
        return "I don't KNOW"
    }
}

type Human struct {
}

func (h Human) String() string {
    return "WOW"
}

type Animal struct {
}

func main() {
    fmt.Println(str("asdada")) // I'm String:asdada

    h := Human{}
    fmt.Println(str(h)) // WOW

    a := Animal{}
    fmt.Println(str(a)) // I don't KNOW
}
```

上述的函数 `str` 中，接收的参数是空的 interface，在函数调用的时候进行了隐式的类型转换，因为任何类型都包括空的 interface。

### interface 内存结构

Golang 中的 interface 包括两个部分

1. 底层的数据
2. 描述符，即方法表

方法表中，关联着相关类型和方法列表。这些都不是动态类型，所以可以用来进行类型检查。底层数据存放的是复制的一份新的原始数据。在调用的时候，将底层数据作为方法的第一个参数来进行调用。

空的 interface 就是方法表为空的变量。

## slice

slice 是变长数组，在使用的时候有些需要注意的地方。

首先看下 slice 的结构

```go
type Slice struct{
    byte*    array;        // actual data
    uintgo    len;        // number of elements
    uintgo    cap;        // allocated number of elements
};
```

```go
func appendSlice(array []int) {
    array[0] = 10000
    fmt.Printf("%p\n", array)
    array = append(array, 5)
    fmt.Printf("%p\n", array) // 与上面的地址不同
    array[0] = 10001
}

func main() {
    l := []int{1, 2, 3, 4}
    fmt.Println(l) // [1 2 3 4]
    appendSlice(l)
    fmt.Println(l) // [10000 2 3 4]
}
```

上述代码中，修改 slice 里面元素的值成功了，但是 append 失败了。因为 Golang 中传参数是复制的，对 slice 内部的 array 复制进去了，所以修改是成功的。但是 append 之后其实是将旧的 slice 复制到了新的 slice，然后已经是一个新的值了，所以修改是不成功的。


## new & make

`new` 方法返回空值的结构体的指针，类似于 `&File{fd, name, nil, 0}` 这样的结构，不过其内部的成员都各自为其类型对应的空值。

`make` 用于 slice, channel, map 类型的初始化。与 `new` 不同的是，`make` 分配对象相应的指定的存储空间，但不会置对应的空值，不返回指针。

## 重复声明和重复赋值

Golang 中的 `:=` 是赋值和声明的简写，该符号左边至少需要有一个新的变量，如果对以后的变量进行操作则会报错。

需要注意的是，如果在外层作用域定义的变量，再用 `:=` 进行赋值操作的话，则会屏蔽掉外层作用域的变量，特别是循环内部判断 `error` 的时候需要特别注意。

```go
var err error
for i := 1; i <= 10; i++ {
    j, err := f()

    fmt.Println(j)
    fmt.Println(err) // some error
    if err != nil {
        break
    }
}
fmt.Println(err) // nil
```

## 一点总结

用 Golang 大概一个多月，除了上手时候有点纠结外，感觉这门语言还是很舒服的。当然，标准库和第三方库还是不能和 Python 比，但编译检查静态错误的这个点开发起来很舒服，一些可能的问题能够尽早的发现。

interface 这点的引入能够减少不少的重复代码，变量默认零值也能让人逃开奇奇怪怪的构造函数的坑。

感觉在开发大型项目上，特别是系统级软件会比较适合。在使用过 Python 开发之后，越发觉得有必要加强开发工具对人的约束，代码风格的统一以及对无用 import 和无用变量的约束能够对共同开发起到良好的补充。

之后如果有耐心，希望可以把几个 Golang 常用的场景写下

1. Golang 的反射，动态修改
2. Golang 的并发
3. ...


## 参考

1. [interface 内存结构](http://research.swtch.com/interfaces)
2. [Effective Go](https://golang.org/doc/effective_go.html)

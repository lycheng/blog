---
layout: post
title:  Golang 学习 1
tags: [golang]
---

## 字符串


不可变的字节序列。对于不同编码的字符串所有都是同样的操作，字符串的每一位都是一个 ASCII 值，需要额外进处理去解析 unicode 字符串。

```go
import "unicode/utf8"

s := "Hello, 世界"
for i := 0; i < len(s); {
    r, size := utf8.DecodeRuneInString(s[i:])
    fmt.Printf("%d\t%c\n", i, r)
    i += size
}

// 也可以使用 range，Go 本身会自动处理 unicode
// 步长的递进可以看到也不是 1
for i, r := range "Hello, 世界" {
    fmt.Printf("%d\t%q\t%d\n", i, r, r)
}
```

## 常量

常量的值在编译期间就确定了。常量定义可用一个 `iota` 去生成，类似于枚举类型。

```go
type Weekday int

const (
    Sunday Weekday = iota // 0
    Monday                // 1 以下以此类推
    Tuesday
    Wednesday
    Thursday
    Friday
    Saturday
)
```

### 无类型常量

如果常量的定义的时候不指定类型，如

```go
const (
    E = 2.71828182845904523536028747135266249775724709369995957496696763
)
```

编译器会提供一个比基础类型更高的运算精度，并且可以无需显式的类型转换就能直接赋值给基础类型。 

## 复合类型

### 数组

固定长度的特定元素的序列，因为不可扩展，一般直接用 `slice`。

### slice

与数组不同的是，在初始化的时候无需指定长度。而且对 slice 的比较操作也是非法的。

需要注意的是，slice 的切片操作不是复制，而是引用，意味着修改会改变原始数据。

```go
a := []int{1, 2, 3, 4, 5}
b := a[:3]
b[0] = 12313

// a = [12313 2 3 4 5]
// b = [12313 2 3]
```

### map

map 可以用于和 `nil` 进行比较，但赋值操作必须先进行 `make` 来创建 map。

可以用 `map[string]bool` 来实现简单的 set 操纵

```go
set := make(map[string]bool)
set["a"] = true

fmt.Println(set["a"]) // true
fmt.Println(set["b"]) // false
```

因为类型是确定的，所以在使用的时候可以放心使用，在不存在 key 的情况下返回的都是该类型的空值。

## 函数

Go 中函数是 first-class function，函数的参数传递是值传递，因此引用类型的传递会对函数体外的变量进行修改。

函数声明时，可提供返回值的参数变量名，之后该变量就会被声明成该函数内部的一个局部变量，按照该类型来进行初始化，返回时也不需要明确返回。

```go
func sum(x, y float64) (z float64) {
    z = x + y
    return
}
```

### 可变参数

```go
func sum(vals...int) int {
    total := 0
    for _, val := range vals {
        total += val
    }
    return total
}

// 对于一个 slice 可以用下面的方法求和
values := []int{1, 2, 3, 4}
fmt.Println(sum(values...)) // "10"
```

### 错误处理

#### defer

Go 中使用 `defer` 关键字来指定在函数 return 之后的操作，如常见的打开文件，关闭文件。

```go
// src.Close() 在 return 之后执行
src, err := os.Open(srcName)
if err != nil {
    return
}
defer src.Close()
```

这里有几个点需要注意的

1 `defer`中的函数参数是声明的时候确定的，与 `return` 的位置无关

```go
func a() {
    i := 0
    defer fmt.Println(i) // print 0
    i++
    return
}
```

2 `defer` 的执行顺序为 FILO，后声明的 `defer` 先执行

3 `defer` 可以更新命名的返回值（named return variables）

```go
func c() (i int) {
    defer func() { i++ }() // return 2
    return 1
}
```

#### panic & recover

`panic` 函数执行之后，正常的函数流程就会停止，转去执行 `defer` 定义的行为。

`recover` 只能在 `defer` 内的函数使用。三者加起来的用法大概如下

```go
package main

import "fmt"

func main() {
    f()
    fmt.Println("Returned normally from f.")
}

func f() {
    defer func() {
        if r := recover(); r != nil {
            fmt.Println("Recovered in f", r)
        }
    }()
    fmt.Println("Calling g.")
    g(0)
    fmt.Println("Returned normally from g.")
}

func g(i int) {
    if i > 3 {
        fmt.Println("Panicking!")
        panic(fmt.Sprintf("%v", "asdadada"))
    }
    defer fmt.Println("Defer in g", i)
    fmt.Println("Printing in g", i)
    g(i + 1)
}
```

最后的输出

```
Calling g.
Printing in g 0
Printing in g 1
Printing in g 2
Printing in g 3
Panicking!
Defer in g 3
Defer in g 2
Defer in g 1
Defer in g 0
Recovered in f asdadada
Returned normally from f.
```

可以简单的看出

1. `Panicking` 是在所有的 `defer` 执行之后再进行工作
2. `recover` 可以简单的理解为在 `defer` 中处理 `panic` 函数传过来的值

## 参考

1. [gopl-zh](https://www.gitbook.com/book/wizardforcel/gopl-zh/details)
2. [defer, panic and recover](https://blog.golang.org/defer-panic-and-recover)

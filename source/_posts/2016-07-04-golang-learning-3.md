---
layout: post
title:  Golang 学习 3
tags: [golang]
---

## 包管理

Golang 中的包 `package` 是代码组织的基本单位。与 `struct` 的方法相同，大写字母开头的就是该包对外可以访问的方法，变量。

每个文件开头的 `package` 关键字用来标识该文件所在的包名，通常就是包含该文件的文件目录名。

当导入包遇到重名的时候，可以像下面的代码一样

```go
import (
    "crypto/rand"
    mrand "math/rand" // alternative name mrand avoids conflict
)
```

### 匿名导入

因为在使用别的包的时候，如果仅仅是 import 但不使用的话是会报错的，但有种情况是仅仅希望执行某个包对应的 `init` 函数，因为在 import 的时候，会自动调用包里面各个文件的 `init` 函数。

像官网的例子，读取图片文件

```go
import (
    "fmt"
    "image"
    "image/jpeg"
    _ "image/png" // register PNG decoder
)
```

上述导入的 `image/png` 实际执行了以下的函数，详见 [源文件](https://golang.org/src/image/png/reader.go#L847)

```go
func init() {
    image.RegisterFormat("png", pngHeader, Decode, DecodeConfig)
}
```

执行了 [image/format](https://golang.org/src/image/format.go#L24) 的 `RegisterFormat` 去注册解码器

```go
// Formats is the list of registered formats.
var formats []format

// RegisterFormat registers an image format for use by Decode.
// Name is the name of the format, like "jpeg" or "png".
// Magic is the magic prefix that identifies the format's encoding. The magic
// string can contain "?" wildcards that each match any one byte.
// Decode is the function that decodes the encoded image.
// DecodeConfig is the function that decodes just its configuration.
func RegisterFormat(name, magic string, decode func(io.Reader) (Image, error), decodeConfig func(io.Reader) (Config, error)) {
    formats = append(formats, format{name, magic, decode, decodeConfig})
}
```

当然，这里的仅仅是用来读文件，如果需要对 png 进行操作的话，还是需要导入 png 的 package。除了这里的图片操作以外，数据库操作也是类似的 [代码](https://github.com/go-sql-driver/mysql#usage)。

### 工作区

Golang 中需要配置 `$GOPATH` 来指定工作区，换个角度来讲，只要控制 `$GOPATH` 就可以控制不同的工作区，防止不同的项目依赖互相污染。

## 反射

在编译的时候不知道变量的值，但是运行时可以进行检查判断，更新，这在 Golang 中就是反射。简单来说，反射是一种检验变量的类型和值的机制。这里面的操作对象是 interface。

### 基本用法

```go
var x float64 = 3.4
v := reflect.ValueOf(x)
fmt.Println("type:", v.Type())
fmt.Println("kind is float64:", v.Kind() == reflect.Float64)
fmt.Println("value:", v.Float())

// type: float64
// kind is float64: true
// value: 3.4
```

### 从 interface value 到 reflection object 的

reflect pacakge 的两个基本函数 `reflect.TypeOf` 和 `reflect.ValueOf`，都是接收 `interface{}` 的参数。任何类型都包含 empty interface，所以任何 interface 都能转成 `interface{}`。

如上述的代码一样，可以通过判断 reflect object 的类型来进行相应的输出

### 从 reflection object 到 interface object

```go
type MyInt int

func main() {
    var x MyInt = 7

    v := reflect.ValueOf(x)
    y := v.Interface().(MyInt) // 这里如果用 int 会 panic

    fmt.Println(v)
    fmt.Println(v.Kind()) // int
    fmt.Println(v.Type()) // main.MyInt
    fmt.Println(y)
}
```

上面的代码可以看到，`Kind` 方法不能正确辨识变量的类型，但 `Type` 可以，虽然底层类型都是一样的。

v 调用 `Interface` 之后返回的是 empty interface，可以用 `fmt.Println` 等方法能正确识别为 int 类型。

### 想要修改 reflection object，那该变量必须是 settable

```go
var x float64 = 3.4
v := reflect.ValueOf(x)
v.SetFloat(7.1) // panic

fmt.Println("settability of v:", v.CanSet()) // false
```

错误的原因是 `reflect.Value.SetFloat using unaddressable value`，该变量是无法寻址的。reflect 中，可寻址标识可以修改变量实际存储的东西。在上面的函数调用中，复制了 `x`，即使修改也只是对函数内部的临时变量进行修改。

改成指针

```go
p := reflect.ValueOf(&x) // Note: take the address of x.
fmt.Println("type of p:", p.Type())
fmt.Println("settability of p:", p.CanSet()) // false
```

指针也不行，我们实际需要修改的东西是 `p` 指向的内存，而不是 `p` 本身。正确的用法如下

```go
var x float64 = 3.4
p := reflect.ValueOf(&x)
v := p.Elem()

v.SetFloat(7.1)
fmt.Println(v.Interface())
fmt.Println(x)
fmt.Println(v)
```

这里有点绕，需要仔细理解下才行。

三个用法看下来发现其实反射用起来是比较危险的，因为无法进行静态分析，程序可能在某个地方就 panic 了，在实际场景中因该尽量避免使用反射。

## 参考资料

1. [Go 语言圣经](https://wizardforcel.gitbooks.io/gopl-zh/content/)

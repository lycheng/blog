---
layout: post
title:  Golang 学习 2
tags: [golang]
---

## struct

用于聚合数据的结构体，简单用法如下

```go
type Employee struct {
    ID        int
    Name      string
    Address   string
    DoB       time.Time
    Position  string
    Salary    int
    ManagerID int
}

var dilbert Employee

// . 操作
dilbert.Salary = 4000

// 指针也是同样
ptr := &Employee{}
ptr.ID = 1
```

结构体还是该结构体的指针，都支持 . 操作，两者是等效的。在需要传结构体当作参数的时候，最好是使用指针的方式，这就减少了复制结构体的成本。

结构体的成员大小写也跟 Go 本身的包导出规则类似，小写开头的参数如果使用在包外使用会报错。

### 匿名嵌入

当需要一个结构体内加入另一个结构体的时候，可以用匿名成员，只在结构体内写类型或类型指针而不是成员变量。

```go
type AA struct {
    A int
    C int
}

type BB struct {
    AA
    B int
    C int
}

// 直接访问而不是指定 b.AA.A

b := BB{}
b.A = 1
b.B = 2
b.C = 3
b.AA.C = 1111
fmt.Println(b) // 结果 {1 1111} 2 3
```

上面最后可以看到，如果是同名成员的话，会优先访问本类型的成员，忽略匿名成员，这点和其它语言类似。

但是初始化的时候还是得按照类型来。

```go
bb := BB{
    AA: AA{A: 1},
    B:  2,
}
```

### 方法

函数声明时，在函数前面加类型，则为该类型添加了一个方法。

```go
type Point struct {
    X float64
    Y float64
}

// 这里如果使用 p Point 来声明，在使用的时候也是一样的
// 但是调用的时候会发生以此 Point 的复制，所以尽量使用指针
func (p *Point) ScaleBy(factor float64) {
    p.X *= factor
    p.Y *= factor
}

Point{1, 2}.ScaleBy(2) // 临时变量则无法获取其地址，不能这样用
```

须明确一点，**所有的函数调用都是传值的，哪怕是 receiver**。所以对于数据量大的方法更多应该考虑指针的 receiver。

## interface

### 方法集合

类似于 `duck typing` 的意思，`interface`是一种类型，它定义一组方法，任何有实现这些方法的类型都能使用。常用于函数的参数定义中，我们不去关心这个类型具体做什么，而是关心这个类型能不能做我们想要的某些东西。如下面的 `fmt.Stringer`

```go
package fmt
// The String method is used to print values passed
// as an operand to any format that accepts a string
// or to an unformatted printer such as Print.
type Stringer interface {
    String() string
}
```

假如有一个函数，需要使用上述的 `String()`，则你在函数声明的时候可以传入一个 `fmt.Stringer`，任何实现了 `String()` 方法的类型都可以使用。

```go
func testString(i fmt.Stringer) {
    fmt.Println(i.String())
}

type Human struct {
    Name string
    Age  int
}

func (h Human) String() string {
    return fmt.Sprintf("Name %s, Age %d", h.Name, h.Age)
}
```

值得注意的是，这里 `Human` 的 `String` 方法使用变量而不是指针作为 recevier。因为值类型的方法可以使用指针去访问，但是反过来不行。使用值类型的方法相对更通用一些。

### 通用类型

interface 无关是指针还是值，它是什么取决于你怎么去处理。

在很多标准库的定义中，很多函数接收 `v inteface{}` 的参数，意味着可以传入任何类型的变量。

使用原则简单来说就是 [宽以待人，严于律己](https://en.wikipedia.org/wiki/Robustness_principle)，如果返回 interface 类型的话则会需要后人去猜测变量的类型。你会看到在许多的函数参数中都会有 interface 类型，使用上更多是传入一个指针，这样就可以确认函数修改 / 更新的值是确定的。

## Goroutines && Channels

使用简单的语法就可以开启一个新的线程去执行函数

```
go f()
```

主函数也是一个 `goroutine`，当主函数退出，所有的 `goroutine` 都会退出。

不同的 `goroutine` 之间使用 `channel` 进行通信，`channel` 是指定类型的。

```go
ch := make(chan int) // 无缓冲
ch1 := make(chan int, 1) // 有缓冲

ch <- x  // 发送
x = <-ch // 接收
<-ch     // 接收并抛弃
```

上方代码中创建的无缓冲的 `channel`，这样子接受者和发送者都会同时阻塞，相当于两者做一次同步，当通过无缓冲的 `channel` 进行发送时，接受者收到数据发生在发送者唤醒之前。

需要注意的是，哪怕是有缓冲的 `channel` 在其没有元素的时候，接收动作 `<-ch` 是阻塞的，直到有数据过来。

### select 的多路复用

```go
select {
case <-ch1:
    // ...
case x := <-ch2:
    // ...use x...
case ch3 <- y:
    // ...
default:
    // ...
}
```

当有多个 `channel` 需要进行监控的时候，可以用 `select` 的语法进行操作，只有在某个 `channel` 有数据时才会执行相应的 `case`，否则执行 `default` 块。

`time` 包中有一个 Tick 函数能很方便地执行定时任务

```go
func main() {
    tick := time.Tick(3 * time.Second)
    for i := 0; i < 100; i++ {
        select {
        case <-tick:
            fmt.Println("Do Some Thing")
        default:
            fmt.Println("Sleep 1s")
            time.Sleep(time.Duration(1) * time.Second)
        }
    }
}

// 输出如下
Sleep 1s
Sleep 1s
Sleep 1s
Do Some Thing
Sleep 1s
Sleep 1s
Sleep 1s
Do Some Thing
Sleep 1s
Sleep 1s
Sleep 1s
Do Some Thing
Sleep 1s
Sleep 1s
Sleep 1s
Do Some Thing
Sleep 1s
...
```

### channel 泄漏

上述代码中，`tick` 在循环之外还会继续作用，这种情况叫做 `channel` 的泄漏，它只适合用在整个程序生命周期都存在的情况。

当你试图去 `close` 的时候，则会报错

> invalid operation: close(tick) (cannot close receive-only channel)

还有另一种 tick 能使用

```go
ticker := time.NewTicker(1 * time.Second)
<-ticker.C    // receive from the ticker's channel
ticker.Stop() // cause the ticker's goroutine to terminate
```

### 退出多个 goroutine

如果维护了多个 goroutine 的话，需要类似于广播的一类事件，可以通过关闭一个 channel 来进行类似的操作。

```go
var done = make(chan struct{}) // 注意是无缓冲的

func cancelled() bool {
	select {
	case <-done:
		return true
	default:
		return false
	}
}

func worker(i int) {
    for {
        if cancelled() {
            break
        }
        fmt.Printf("worker %d work\n", i)
        time.Sleep(time.Duration(1) * time.Second)
    }
    fmt.Printf("worker %d cancelled\n", i)
}

func manager() {
    time.Sleep(time.Duration(2) * time.Second)
    fmt.Println("close workers")
    close(done)
    time.Sleep(time.Duration(5) * time.Second)
}

func main() {
    for i := 1; i < 5; i++ {
        j := i
        go worker(j)
    }
    manager()
}
```

## 一些有趣的文章

1. [Handling 1 Million Requests per Minute with Go](http://marcio.io/2015/07/handling-1-million-requests-per-minute-with-golang/)
2. [Golang 的 interface](http://jordanorelli.com/post/32665860244/how-to-use-interfaces-in-go)
3. [Golang interface 的内存实现](http://research.swtch.com/interfaces)

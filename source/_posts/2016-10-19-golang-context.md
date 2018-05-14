---
layout: post
title:  Golang context
tags: [golang,context]
---

前言
---

在去使用 Golang context 之前，推荐先去看 Golang pipeline 的[博文][1]，这里有讲到 Golang channel 的一些使用的技巧。

> 1.6 的版本只能通过 `golang.org/x/net/context` 来使用， 1.7 之后才可以通过直接引用来使用

应用场景
---

Golang 创建了 goroutine 之后，在外部很难进行干预（只能依靠一个 chan 的关闭来通知）或者一些需要处理超时的请求很不方便，特别是多个 goroutine 进行协同工作时，我们需要一种模式来协同工作。

Golang 的 context 包就是解决这类问题的，它的基本结构如下

```golang
type Context interface {
    Done() <-chan struct{}
    Err() error
    Deadline() (deadline time.Time, ok bool)
    Value(key interface{}) interface{}
}
```

下面以一些常见的例子来讲解下

### 超时处理

Golang 官方 wiki 的超时处理是 [这样的][4]

```golang
c := make(chan error, 1)
go func() { c <- client.Call("Service.Method", args, &reply) } ()
select {
  case err := <-c:
    // use err and reply
  case <-time.After(timeoutNanoseconds):
    // call timed out
}
```

通过另外起 goroutine 来执行操作，本身则进行计时。当然简单的任务可以这样玩，但如果多个函数调用就非常囧了。我们假设有个函数如下

```golang
func work(ctx context.Context) (err error) {
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
			fmt.Println("working")
			time.Sleep(time.Duration(1) * time.Second)
		}
	}
	return
}
```

则我们可以在 main 函数中这样用

```golang
var (
	ctx    context.Context
	cancel context.CancelFunc
)
ctx, cancel = context.WithTimeout(context.Background(), time.Duration(2)*time.Second)
defer cancel()

c := make(chan error, 1)
go func() { c <- work(ctx) }()
select {
case <-ctx.Done():
	fmt.Println("Timeout")
	fmt.Println(ctx.Err()) // context deadline exceeded
case err := <-c:
	if err != nil {
		fmt.Sprintf("Error occor %s\n", err)
	} else {
		fmt.Println("Prefect work")
	}
}
```

这个例子其实跟之前 timeout 的做法类似，通过 goroutine 设置超时限制来达到控制函数超时的目的。那么我们多出来了什么？这里最明显的就是 `context.CancelFunc` 这个可以从外部控制的函数。除此之外，我们也可以通过参数 `ctx` 来通知子 context 外部的情况，如果外部取消或者超时了，我们可以进行诸如资源释放的操作，最后安全退出。

### 外部控制

如果在 ctx 对应的函数执行的过程中，外部的情况发生了变化，例如手动取消了进程，则该 goroutine 下对应的子 goroutine 也应该取消之后的操作。

```golang
var (
	ctx    context.Context
	cancel context.CancelFunc
)
ctx, cancel = context.WithCancel(context.Background())
defer cancel()

c := make(chan error, 1)
go func() { c <- work(ctx) }()
select {
case <-time.After(time.Duration(1) * time.Second):
	cancel()
	fmt.Println(ctx.Err()) // context canceled
case err := <-c:
	fmt.Println(err)
}
```

这里是外部取消了 work 的后续操作。同样的，之前的 `WithCancel` 也返回 cancel 函数可供使用，两者是等效的。

with 函数
---

`context` 提供了几组 with 开头的方法，包括上面我们看到的 `WithCancel` 和 `WithTimeout`。它们的共同作用都是继承父级 context 来创建子 context，如果父级的 context 关闭了，其下的 context 也会关闭。

```golang
var (
	ctx0    context.Context
	cancel0 context.CancelFunc
	ctx1    context.Context
	cancel1 context.CancelFunc
)
ctx0, cancel0 = context.WithTimeout(context.Background(), time.Duration(50)*time.Second)
defer cancel0()

ctx1, cancel1 = context.WithTimeout(ctx0, time.Duration(100)*time.Second)
defer cancel1()

c0 := make(chan error, 1)
c1 := make(chan error, 1)

go func() { c0 <- work0(ctx0) }()
go func() { c1 <- work1(ctx1) }()
time.Sleep(time.Duration(3) * time.Second)
fmt.Println("cancel work0")
cancel0()
time.Sleep(time.Duration(10) * time.Second)
```

上述的 `work0` 和 `work1` 函数的实现和之前的 `work` 一样，只是输出不同，下面是这个函数的输出

```
work1 is working
work0 is working
work1 is working
work0 is working
work1 is working
work0 is working
cancel work0
// wait 10s but nothing else
```

输出明确了 ctx0 和 ctx1 的关系。

补充说明
---

在上述的代码中，都有用到 `context.Background()` 这个 context，这是最顶层的 context，伴随程序的生命周期。所有的 context 都从这里来，所以新建 context 的时候需要指定从这里派生出新的 context。

除了之前提到的超时和取消的函数之外，context 还可以传递参数

```golang
func WithValue(parent Context, key interface{}, val interface{}) Context

// for use
value, ok := ctx.Value(key).(string)
```

这个参数不是用来传递普通参数的，设计的初衷是用来传递 `request-scoped` 的参数，元数据。

注意事项
---

1. ctx 变量推荐作为函数的第一个参数传递使用，而不要放在结构体中
2. ctx 变量可以多个 goroutine 一起使用，不必担心安全问题
3. cancel 函数在声明之后应该直接跟着 `defer` 来使用

参考
---

1. [Golang 使用 channel 实现 pipeline 模式][1]
2. [Golang context 应用][2]
3. [Golang context talk][3]


  [1]: https://blog.golang.org/pipelines
  [2]: https://blog.golang.org/context
  [3]: https://talks.golang.org/2014/gotham-context.slide#1
  [4]: https://github.com/golang/go/wiki/Timeouts

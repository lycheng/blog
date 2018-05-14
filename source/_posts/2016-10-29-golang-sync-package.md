---
layout: post
title:  Golang sync 相关使用
tags: [golang,sync]
---

前言
---

本文大概讲下 golang sync 包的相关用法。sync 用在较为底层的库的同步上面，别的情况是推荐使用 channel 来同步进程。

Mutex
---

sync 包里面有两种互斥锁，分别是 `sync.Mutex` 和 `sync.RWMutex`。前者是基本的互斥锁，后者在前者的基础上实现的读写锁。

在这里我有一个简单的 stack 的实现，这里仅列出 push 方法的实现，可以看到，线程安全的的 stack 的 push 方法仅仅是比普通的 push 多出一个加锁解锁的过程。

```golang
type Stack struct {
	data  []interface{}
	count int
}

type SafeStack struct {
	stack *Stack
	sync.RWMutex
}

func (s *Stack) Push(item interface{}) {
	if len(s.data) == s.count {
		s.data = append(s.data, item)
	} else {
		s.data[s.count] = item
	}
	s.count += 1
}

func (s *SafeStack) Push(item interface{}) {
	s.Lock()
	defer s.Unlock()
	s.stack.Push(item)
}
```

这里有个简单的 benchmark，简单的加锁解锁之后的性能仅剩下之前的十分之一了。

```
BenchmarkStack-4        30000000                38.4 ns/op
BenchmarkSafeStack-4     3000000                403 ns/op
```

Pool
---

临时变量池。值得注意的是，golang 在 GC 的时候会将所有的 Pool 的临时变量全部删除，所以并不适合用在需要持久化用的环境里面。

```golang
var pool = sync.Pool{
	New: func() interface{} {
		b := make([]int, 1)
		return &b
	},
}

func main() {
	s := pool.Get().(*[]int)
	(*s)[0] = 99
	pool.Put(s)
	fmt.Println(s) // &[99]

	d := pool.Get().(*[]int)
	fmt.Println(d) // &[99]
}
```

WaitGroup
---

WaitGroup 用在等待子 goroutine 的场景。主 routine 通过指定需要等待的 routine 的个数，然后子 routine 手动通知上层任务完成。

```golang
// 注意这里不可直接用 wg 变量，而是需要传地址
func work(i int, wg *sync.WaitGroup) {
	defer wg.Done()
	fmt.Printf("Work %d\n", i)
	time.Sleep(time.Duration(1) * time.Second)

}

func main() {
	var wg sync.WaitGroup
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go work(i, &wg)
	}
	// 如果 work 直接传值，这里就会死锁
	// fatal error: all goroutines are asleep - deadlock!
	wg.Wait()
	fmt.Println("done")
}
```

Cond
---

条件变量，初始化时需要指定 locker。用于等待条件触发再去执行之后的操作。

```golang
func work(c *sync.Cond) {
	time.Sleep(time.Duration(1) * time.Second)
	fmt.Println("Notify main")
	c.Signal()
}

func main() {
	var (
		locker = new(sync.Mutex)
		cond   = sync.NewCond(locker)
	)
	cond.L.Lock()
	go work(cond)
	cond.Wait()
	fmt.Println("Done")
}
```

也可以广播

```golang
func work(cond *sync.Cond, i int) {
	cond.L.Lock()
	defer cond.L.Unlock()
	cond.Wait()
	fmt.Println("work", i)
}

func main() {
	var cond = sync.NewCond(new(sync.Mutex))
	for i := 0; i < 10; i++ {
		go work(cond, i)
	}
	// 下面的 sleep 很重要
	time.Sleep(time.Duration(2) * time.Second)
	fmt.Println("Wake up")
	cond.Broadcast()
	time.Sleep(time.Duration(20) * time.Second)
	fmt.Println("Done")
}
```

上述的代码我调试的时候出现了诡异的不稳定状态，work 函数中一直没有输出，或者没有输出全部的信息。

之前的代码中不包含上述的 sleep 两秒的代码，后来找了很久的原因无意中看到说有可能出现竞争。即 `cond.Broadcast()` 的执行优先于 work 的 `cond.L.Lock()`。因为广播是通知所有在 wait 的 routine。Golang 并不保证 routine 的执行顺序，所以应该有外部手段去控制相应的执行顺序。

为了解决上述的问题，官方文档推荐

```golang
c.L.Lock()
for !condition() {
    c.Wait()
}
... make use of condition ...
c.L.Unlock()
```

通过额外的变量 condition 去控制 wait 的时机，这个就是后话了。

总结
---

除了上述的数据结构，还有 `sync.Once` 等有用的东西，更多可参考官方文档。在我看来，互斥锁加上 channel 已经可以解决绝大部分的问题了。

需要注意的是，所有 sync 包的提供的数据结构都不允许复制，如果需要函数传值，则必须使用传地址的方式。这里还有很多细节还没有详细写，也可以看看 [别人的][4] 的关于 sync 的使用。

sync 库的应用场景更偏向与底层，更高层的进程间通信更应该使用 channel 来使用，两者应该是相辅相成的关系。

参考
---

1. [Dancing with go's mutexes][1]
2. [Mutex or channel][2]
3. [sync 官方文档][3]
4. [别人写得 sync 包的使用][4]


  [1]: https://medium.com/@deckarep/dancing-with-go-s-mutexes-92407ae927bf#.yflgzc611
  [2]: https://github.com/golang/go/wiki/MutexOrChannel
  [3]: https://golang.org/pkg/sync/
  [4]: https://github.com/polaris1119/The-Golang-Standard-Library-by-Example/blob/master/chapter16/16.01.md

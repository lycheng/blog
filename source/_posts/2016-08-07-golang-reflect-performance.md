---
layout: post
title:  Golang reflect 性能测试
tags: [golang,reflect]
---

前言
---

这阵子用 Golang 实现了一个类似于 python `in` 语法的小函数，项目 [gox](https://github.com/lycheng/gox) 的 benchmark 测试的结果如下

```
BenchmarkOriIn-4        500000000                3.22 ns/op
BenchmarkMyIn-4         10000000               175 ns/op
BenchmarkOriMapIn-4     100000000               16.3 ns/op
BenchmarkMyMapIn-4       2000000               784 ns/op
ok      github.com/lycheng/gox/container        7.939s
```

其中，OriIn 是顺序查询 slice 和 array 的元素是否存在，OriMapIn 是原生的语法去判断 key 是否存在。上述的结果可以看到相当巨大的性能差异。

我实现的 In 的函数在处理 Map 的时候是通过遍历 keys 来查询的，因此每次的类型判断乘上数据量不仅仅是一个跟 N 有关的线性增长。

profile
---

使用 Golang 的 `runtime/pprof` 包来检查相应的 CPU 消耗，这里不考虑内存消耗的问题。

profile 程序

```go
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"runtime/pprof"

	"github.com/lycheng/gox/container"
)

var cpuprofile = flag.String("cpuprofile", "gox.prof", "write cpu profile to file")

// l 如果太大则会内存不足
var l = flag.Int("len", 100000000, "find item in N sequence")
var ori = flag.Bool("ori", false, "use ori array func")

func oriFind(item int, items []int) bool {
	for _, i := range items {
		if i == item {
			return true
		}
	}
	return false
}

func main() {
	flag.Parse()
	if *cpuprofile != "" {
		f, err := os.Create(*cpuprofile)
		if err != nil {
			log.Fatal(err)
		}
		pprof.StartCPUProfile(f)
		defer pprof.StopCPUProfile()
	}

	items := []int{}
	for i := 0; i < *l; i++ {
		items = append(items, i)
	}
	item := items[len(items)-1]

	if *ori {
		fmt.Println(oriFind(item, items))
	} else {
		fmt.Println(container.In(item, items))
	}
}
```

应用如下

```
> go build profile.go

# 简单的数组遍历
> ./profile -ori true
true

# 使用 reflect
> ./profile
true
```

相对不用 `reflect` 只是简单的整型数组的查找，top10 的消耗如下

```
> go tool pprof profile gox.prof
Entering interactive mode (type "help" for commands)
(pprof) top10
3060ms of 3060ms total (  100%)
Dropped 6 nodes (cum <= 15.30ms)
Showing top 10 nodes out of 27 (cum >= 20ms)
      flat  flat%   sum%        cum   cum%
     810ms 26.47% 26.47%     1790ms 58.50%  runtime.scang
     760ms 24.84% 51.31%      980ms 32.03%  runtime.readgstatus
     630ms 20.59% 71.90%      630ms 20.59%  runtime.memmove
     340ms 11.11% 83.01%     1250ms 40.85%  main.main
     220ms  7.19% 90.20%      220ms  7.19%  runtime/internal/atomic.Load
     200ms  6.54% 96.73%      200ms  6.54%  runtime.memclr
      80ms  2.61% 99.35%       80ms  2.61%  main.oriFind
      20ms  0.65%   100%       20ms  0.65%  runtime.scanblock
         0     0%   100%       20ms  0.65%  runtime.(*mspan).sweep
         0     0%   100%       20ms  0.65%  runtime.(*mspan).sweep.func1
```

gox 的版本

```
> go tool pprof profile gox.prof
Entering interactive mode (type "help" for commands)
(pprof) top10
5100ms of 5260ms total (96.96%)
Dropped 15 nodes (cum <= 26.30ms)
Showing top 10 nodes out of 29 (cum >= 200ms)
      flat  flat%   sum%        cum   cum%
    1010ms 19.20% 19.20%     1010ms 19.20%  runtime.memmove
     780ms 14.83% 34.03%     1450ms 27.57%  runtime.scang
     590ms 11.22% 45.25%     2310ms 43.92%  github.com/lycheng/gox/container.inArray
     540ms 10.27% 55.51%     1040ms 19.77%  github.com/lycheng/gox/container.equals
     530ms 10.08% 65.59%      670ms 12.74%  runtime.readgstatus
     500ms  9.51% 75.10%      500ms  9.51%  reflect.Value.Int
     480ms  9.13% 84.22%      480ms  9.13%  reflect.Value.Index
     270ms  5.13% 89.35%     3770ms 71.67%  main.main
     200ms  3.80% 93.16%      200ms  3.80%  reflect.Value.Len
     200ms  3.80% 96.96%      200ms  3.80%  runtime.memclr
```

两种代码的执行时间只是 5s 和 3s 的区别，而 `container.inArray` 在这里面就占用了 2310ms，几乎花了一半的时间在类型判断和比较上面。

`gox` 这东西可能在数据量较小的情况下可以使用。但在我平时工作的应用场景里面，很少用到这种异构的数组。每个元素去判断类型消耗实在是太大了啊。

总结
---

`reflect` 这东西感觉还是少用点会比较好，除非用来编写奇怪动态数据，例如根据 key 修改 struct 的某些数据。文章后面的参考中有较好的第三方库。

而在我编写的过程中，也很容易出现各种 panic 的情况，例如需要覆盖各种可能的数据类型，这种情况不好处理，万一有所遗漏则就是 bug 了。

参考
---

1. [profiling in golang](https://blog.golang.org/profiling-go-programs)
2. [Golang 中动态修改 struct 的库](https://github.com/fatih/structs)

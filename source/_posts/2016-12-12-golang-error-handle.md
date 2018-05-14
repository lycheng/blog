---
layout: post
title:  Golang 错误处理
tags: [golang,error]
---

前言
---

Golang 中 error 的类型定义很简单，就是一个 [interface](https://github.com/golang/go/blob/master/src/builtin/builtin.go#L254)

```golang
type error interface {
	Error() string
}
```

在标准库中，可以使用 `errors` 和 `fmt` 包来生成 error

```golang
e1 := fmt.Errorf("%s", "error")
e2 := errors.New("error")
```

error 是变量，可用于比较
---

因为 error 是可比较的，我们可以通过比较来进行判断具体的错误。

```golang
var (
	error1 = fmt.Errorf("error1")
	error2 = fmt.Errorf("error2")
)

func F() error {
	return error1
}

func main() {
	err := F()
	if err != nil {
		switch err {
		case error1:
			fmt.Println(error1)
		case error2:
			fmt.Println(error2)
		}
	}
}
```

例如，在 [go-pg](https://github.com/go-pg/pg) 这个开源项目中，也在代码中定义了相应的 error 供我们判断情况 [error.go](https://github.com/go-pg/pg/blob/v5/error.go)。下面的代码就是用来判断当做的错误是不是网络错误。

```golang
func isNetworkError(err error) bool {
	if err == io.EOF {
		return true
	}
	_, ok := err.(net.Error)
	return ok
}
```

压缩代码行数
---

在刚接触 Golang 的时候，我在每个返回 error 的函数中都进行了判断与返回，这样就导致了代码都长下面这样

```golang
d, err := F()
if err != nil {
	fmt.Println(err)
	return err
}

c, err := F1()
if err != nil {
	fmt.Println(err)
	return err
}
```

可以如下的写法，减少代码行数

```golang
var d int
if d, err := F(); err != nil {
	fmt.Println(err) // some int
	return err
}
fmt.Println(d) // 0
```

这种写法适合遇到 error 就直接返回上层函数的情况。

不管是上面的代码，还是之前的代码，都有一个 `:=` 导致的作用域的小坑需要注意一下。如果 `:=` 左边的某个变量在外部的作用域已经定义，这里面的赋值会导致屏蔽掉外部的变量，创建一个新的变量在当前的作用域使用。如果需要对外部的变量进行变更的话，则需要赋值的 `=`。

```golang
func wrapper() (err error) {
	for i := 0; i < 10; i++ {
		n, err := work(i)
		if err != nil {
			return // err is shadowed during return
		}
		fmt.Println(n)
	}
	return
}
```

上述的例子就是 err 被屏蔽了，会出现编译错误。

错误统一处理
---

还有一种写法就是，通过一个 struct 内部的 error 变量来获知是否有错误发生。例如

```golang
type Controler struct {
	err error
}

func (c *Controler) Work(num int) bool {
	if num > 5 {
		c.err = fmt.Errorf("Number too big")
		return false
	}

	fmt.Println(num)
	return true
}

func (c *Controler) InError() bool {
	return c.err != nil
}

func (c *Controler) Error() error {
	return c.err
}

func main() {
	c := Controler{}
	for i := 1; i < 10; i++ {
		c.Work(i)
	}

	if c.InError() {
		fmt.Println(c.Error())
	}
}
```

在上述的代码中，我不关心哪个步骤出了问题，我关心的是整体是否出错。这种场景下就可以用这种方法进行错误处理。同时，缺点也是优点，我们就会不知道到底哪里出的问题。

错误还是异常
---

Golang 中在语法层面区分了错误和异常，就是 `error` 和 `panic` 的区别。panic 函数实际上就是强制停止了函数，并返回上层函数，如果上层函数没有做 recover 检查的话（当然也可以在当前函数的 defer 处使用 recover），则整个程序就会停止。

```golang
func div(x, y float64) float64 {
	if y == 0 {
		panic("zero")
	}
	return x / y
}

func work(x, y float64) float64 {
	defer func() {
		if r := recover(); r != nil {
			fmt.Println("Recovered in div", r)
		}
	}()
	return div(x, y)
}

func main() {
	x := 1.0
	y := 0.0
	fmt.Println(work(x, y))
}
```

在标准库中，[json 的 decode.go](https://golang.org/src/encoding/json/decode.go#L151) 中有使用 panic 的例子。在解析 json 格式的时候有多个递归，如果其中一个遇到错误，则调用 panic 函数，整个调用栈就会相继退出，然后在最上层的函数调用 recover 进行捕获。

然而，不少的标准库其实也没有太多地使用 panic 这个功能，第三方库更多也是以 error 代替这个功能。[Effective Go](https://golang.org/doc/effective_go.html#panic) 中也推荐我们少用 panic 这个函数。

异常处理在 Golang 中更多是通过比较 error 的值来进行，不同的 error 执行不同的函数，当然，这样就意味着我们必须在二值返回的时候认真处理 error，所以有时候代码真的不能太优雅。


写在最后
---

上述的所有基础来自 error 是可比较的，interface 的相等是双方都是类型相同，并且方法 Error 的返回值相同。也正因为它是 interface 所以可以用于与 nil 的比较。

Golang 的错误处理我觉得很奇怪，我是习惯了 Python 那种使用 `try ... except` 代码块包含的方式去处理错误 / 异常，这里我必须每个函数调用都判断一次。

例如在 [go-pg](https://github.com/go-pg/pg#select) 中，通过 id 查询一个 model 的使用，如果找不到该记录的话，他是会返回一个找不到记录的错误，如果当前数据库那边有问题，该错误就会表示数据库那边的问题。但如果你是通过条件去找一堆 `id` 的话

```golang
var ids []int
err := db.Model(&Book{}).ColumnExpr("array_agg(id)").Select(pg.Array(&ids))
```

如果找不到，这个 `err` 也还是 `nil`。这个处理逻辑的确是会让人迷惑。

参考
---

1. [Golang 中的比较](https://golang.org/ref/spec#Comparison_operators)
2. [Defer, Panic and Recover](https://blog.golang.org/defer-panic-and-recover)
3. [Golang 的错误处理机制的争议](http://www.infoq.com/cn/news/2012/11/go-error-handle)

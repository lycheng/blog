---
layout: post
title:  Golang 算术表达式解析
tags: [golang,eval]
---

前言
---

项目中需要用到解析算术表达式的模块，简单来说，就是 `eval` 函数，但并没有相应的标准库有类似的实现，所以想使用栈实现一个简单的算术表达式解析的模块。

首先，需要明确的是运算符优先级，这里只需要实现加减乘除，括号，and，or，不等号相关的符号即可。对应的优先级如下

1. 括号
2. 类型运算符（前缀 + -）
3. 乘，除
4. 加，减
5. 大于，小于，不大于，不小于
6. 不等于，等于
7. and
8. or

程序需要做的就是把优先级相关的东西去掉，然后转化成后缀表达式，即逆波兰表达式。

处理流程
---

需要两个栈，`result` 和 `ops` 前者用于保存结果，后者用于暂存操作符。

1. 如果遇到操作数，则 `result` 入栈
2. 如果遇到操作符，则检查 `ops` 栈顶元素优先级
  1. 如果其优先级不低于当前操作符（左括号除外），则弹出 `ops` 栈顶元素并压入 `result` 中
  2. 重复此过程直到 `ops` 栈顶元素优先级小于当前操作符，或为左括号，或者 `ops` 为空
  3. 将当前操作符压入 `ops` 中
3. 如果遇到左括号，直接压入 `ops`
4. 如果遇到右括号，则将 `ops` 中元素弹出，直到遇到左括号为止。左括号只弹出栈而不输出
5. 表达式处理完毕，则将栈中元素依次压入 `result` 中

例如，`1 * 2 + 3 * 4` 就变成 `1 2 * 3 4 * +`。后缀表达式的计算比中缀要容易得多，也不需要关心优先级，只需要简单的使用栈处理下就好。这里需要注意的是，由于比较运算法需要关注左右操作数的位置，所以实际运算的时候需要注意使用栈弹出之后位置就发生了交换。

上面的逻辑没有处理 `+` `-` 的类型前缀的情况。如果需要进行相关处理，则需要判断符号前面是不是数，如果是数的话，则认为当前的符号是二元操作符。因为一元操作符比二元操作符的优先级高，所以也可以将其转化为二元操作符。例如 `-1 + 1` 则可转变为 `-1 * 1 + 1`。

代码实现
---

首先用正则解析出合法的输入

```golang
var legalArthmeticRegex string = `^(\d+(\.\d+)?|\+|\-|\*|\/|and|or|\(|\)|==|>=|<=|!=|>|<)+$`
```

然后需要实现一个简单的 [stack](https://github.com/lycheng/gox/blob/master/stacks/stack.go)，Golang 里面竟然没有实现 stack 这样的东西啊。

然后解析出来之后，将其转为逆波兰式，这里需要用到 stack 来帮助解析。解析出来之后的计算就很简单了。

```golang
func calculateRPN(tokens []string) (result float64, err error) {
	stack := stacks.NewStack()
	for _, token := range tokens {
		if isNumber(token) {
			stack.Push(token)
			continue
		}

		if stack.Size() < 2 {
			err = fmt.Errorf("reverse polish notation is wrong")
			return
		}
		b := stack.Pop()
		a := stack.Pop()
		result, err = calculate(a.(string), b.(string), token)
		if err != nil {
			return
		}
		stack.Push(fmt.Sprintf("%.2f", result))
	}
	return
}
```

最后输出的结果是 `float64` 的类型，布尔类型的结果只能以是否为 0 来进行判断。

高级玩法
---

使用后缀表达式，没办法解决例如 `and` `or` 的优化，只能简单的处理计算而已。

小结
---

其实真正写的时间就一个下午而已，使用栈来实现的算法也是一搜一大堆。写下来发现其实感觉编译原理挺好玩的。

参考
---

1. [gox](https://github.com/lycheng/gox)
2. [C++ 运算符优先级](https://msdn.microsoft.com/zh-cn/library/126fe14k.aspx)
3. [github 上一个类似的 Golang 项目 goexpression](https://github.com/zdebeer99/goexpression)

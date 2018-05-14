---
layout: post
title: react 安利文
tags: [react]
---

[React](https://facebook.github.io/react/) 是 Facebook 开源的一款 *仅仅* 是 javascript 库。当然，现在已经是讲类似的理念推广到了 React Native 去，用于开发 Android 和 iOS 的程序。

这篇文章是一篇 *安利* 文，没有涉及到更多的高深的东西，老手请右上角。

## 基本的东西

### 简单例子


```javascript
var TodoList = React.createClass({
  render: function() {
    var createItem = function(item) {
      return <li key={item.id}>{item.text}</li>;
    };
    return <ul>{this.props.items.map(createItem)}</ul>;
  }
});
var TodoApp = React.createClass({
  getInitialState: function() {
    return {items: [], text: ''};
  },
  onChange: function(e) {
    this.setState({text: e.target.value});
  },
  handleSubmit: function(e) {
    e.preventDefault();
    var nextItems = this.state.items.concat([{text: this.state.text, id: Date.now()}]);
    var nextText = '';
    this.setState({items: nextItems, text: nextText});
  },
  render: function() {
    return (
      <div>
        <h3>TODO</h3>
        <TodoList items={this.state.items} />
        <form onSubmit={this.handleSubmit}>
          <input onChange={this.onChange} value={this.state.text} />
          <button>{'Add #' + (this.state.items.length + 1)}</button>
        </form>
      </div>
    );
  }
});

ReactDOM.render(<TodoApp />, mountNode);
```

这是个官网偷回来的例子，简单来说就是一个输入，enter 之后添加一个 ToDoList 的条目。基本结构再 ToDoApp 的 render 函数里面可以看到。

在 render 里面也可以看到通过参数调用 ToDoList 去渲染已经添加的 ToDo 条目。

### JSX

上述的不像 javascript 的代码是 jsx，最后真正使用的时候需要编译成 javascript 来写，当然也可以用 react 手写 javascript，那会麻烦很多。

值得一提的是，我刚开始用的时候，编译需要用到 `JSXTransformer.js` 这个东西，在官网新版已经不见了。新版使用的是 [babel](https://babeljs.io/) 进行编译。Google 搜出来第一个中文的关于 React 的网站就是使用的旧版，除了编译以外，一些调用方法也发生了改变。

### state

这个是核心的东西，上述代码中

```javascript
this.setState({items: nextItems, text: nextText});
```

调用该函数之后，React 会重新渲染，重新执行 render 函数去生成新的页面。每次重新生成的时候，会通过 diff 去判断哪些元素需要更新，而不是全部是重新刷新。

但不是所有的变量都需要 state，大部分的变量只需要 props 就好了。

## 组件化

在上面的例子我们看到，我们定义了两个类 TodoApp 和 TodoList。两者是一个从属关系，当页面逻辑比较丰富的时候，可以抽出更多的类，一些也可以复用。关系如下

```
TodoApp
- ToDoList
```

如果需要更复杂的关系，可以新增一个 ToDoItem

```
ToDoApp
- ToDoList
 - ToDoItem
```

没有用过除了 jQuery 的前端库，第一次用下来的感觉是非常流畅，没有之前用 jQuery 时候的割裂感。这个感觉是之前感觉是数据和展现是脱节的，需要手动去处理很多数据变更之后的东西，清理现场等等。

这篇 [文章](https://facebook.github.io/react/docs/reconciliation.html) 聊了下 react 组件化的东西，强烈推荐。

## 总结下

在公司项目中一次开发中，因为前一晚刚好看了下 react 的东西，于是觉得合适就开始用起来了，基本没有门槛，分类分层次组件的东西写起来感觉很清爽，很多时候只需要注意维护 state 就好了。

感觉是前端这块工具发展得很快，多尝试下各种新的东西对自己一些思维上的帮助是很大的。react 这种组件的方式对于我这种一直用着 jQuery 那种库来写前端的人来说简直就是一次思维方式的洗礼。

## 更多好玩的东西

1. [React 服务器渲染](https://blog.coding.net/blog/React-server-rendering )
2. [React Diff](https://facebook.github.io/react/docs/reconciliation.html)

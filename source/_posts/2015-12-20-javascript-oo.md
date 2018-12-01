---
layout: post
title: Javascript 面向对象
tags: [javascript]
---

创建对象
---

以下是几种创建对象的方法

### 工厂模式

```javascript
function createPerson(name, age) {
  var o = new Object({});
  o.name = name;
  o.age = age;
  o.sayName = function() {
    console.log(o.name);
  };
  return o;
}
```

缺点是：无法识别对象

### 构造函数模式

```javascript
function Person(name, age) {
  this.name = name;
  this.age = age;

  this.sayName = function() {
    console.log(this.name);
  };
}
var persion1 = new Person("lycheng", 123);
console.log(person1.constructor == Person); // true
console.log(person1 instanceof Person); // true
console.log(person1 instanceof Object); // true
```

上述代码中，如果不用 `new`

```javascript
var person2 = Person("person2", 123);
console.log(person2); // undefined
global.sayName(); // person2
```

因为当在全局环境中调用函数，`this` 总是指向 `global`，所以在使用构造函数的时候必须使用 `new` 来新建对象。

构造函数模式比起工厂模式更加像面向对象了，但是有个问题就是内部的函数都是每个对象不同的。意味着在新建对象的时候又要重新新建一个方法对象。

### 原型模式

```javascript
function Person() {
}

Person.prototype.name = "lycheng";
Person.prototype.age = 25;
Person.prototype.sayName = function() {
  console.log(this,name);
};

var person1 = new Person();
var person2 = new Person();

console.log(person1.sayName == person2.sayName); // true
```

从上面的代码可见，对象 person1 和 person2 的 sayName 函数是同一个了。也可以才用下方的字面值的写法

```javascript
function Person() {
}

Person.prototype = {
  constructor: Person, // 用于类型判断
  name: "lycheng",
  skills: ["javascript", "python"],
  age: 25,
  sayName: function() {
    console.log(this.age);
  }
};
```
简单的原型模式大概如此，这种方法的问题在于，没有构造函数，所有的实例共享所有的变量，如果是引用类型的化，则会出现问题。

```javascript
var person1 = new Person();
person1.sayName();
person1.skills.push("linux");

var person2 = new Person();
console.log(person2.skills);  // [ 'javascript', 'python', 'linux' ]
```

### 组合使用构造函数和原型

所以常用的会有混合使用构造函数和原型对象

```javascript
function Person(name, age) {
  this.name = name;
  this.age = age;
  this.skills = [];
}

Person.prototype = {
  sayName: function() {
    console.log(this.name);
  }
};

var person1 = new Person("lycheng", 25);
person1.skills.push("linux");
console.log(person1.skills); // [ "linux" ]

var person2 = new Person("lyc", 18);
person2.skills.push("vim");
console.log(person2.skills); // [ "vim" ]
```

这种是比较常用的方法，还有更多的动态原型模式，寄生构造函数模式就不一一赘述了。

继承
---

### 原型链

在之前的文章里也提到过原型，javascript 实现面向对象主要通过原型来实现。通过使用原型，可以实现实例对象共有的方法。这种原型对象的关系称为原型链。

每个对象都有原型，通过指针可以查看原型对象，直到最后为 null。通过这样的方法，如果一个对象的原型指向另一个对象，就可以通过这样的方式实现继承。

### 继承

```javascript
function Person(name) {
  this.name = name;
}

Person.prototype.sayName = function(){
  console.log(this.name);
};

function Student(name, age) {
  // 继承属性
  Person.call(this, name, age);
  this.age = age;
}

// 继承方法
Student.prototype = new Person();
Student.prototype.constructor = Student;

Student.prototype.sayAge = function() {
  console.log(this.age);
};

var student = new Student("lycheng", 25);
student.sayName();
student.sayAge();
```

上述代码中主要通过构造函数来继承实例属性，通过原型链来实现原型方法和属性的继承。

### Object.create

ES5 中可以使用新的方法实现继承，将上述的代码改成如下即可
```
Student.prototype = Object.create(Person.prototype);
```
简单来讲
> new X is Object.create(X.prototype) with additionally running the constructor function.

`Object.create` 执行构造函数，但其实我们这里并不需要构造函数，我们仅仅需要的是它的原型部分。但这里两者起到的作用是一样的。

个人想法
---

javascript 一些面向对象的实现看起来很诡异，感觉像是硬要为了实现面向对象而将这一套方法论套在基于原型的 javascript 里面。

参考
---

 1. [Javascript 高级程序设计](http://www.ituring.com.cn/book/946)
 2. [继承与原型链](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Inheritance_and_the_prototype_chain)
 3. [javascript 面向对象介绍](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Introduction_to_Object-Oriented_JavaScript#JavaScript_Review)
 4. [create](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/create)

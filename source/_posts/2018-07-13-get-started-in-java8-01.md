---
layout: post
title: Java8 学习记录 01
tags: [java, java8]
---

环境：Java8, Idea 社区版，ubuntu 18.04 LTS

背景：基本没有 Java 实战经验，有 Python 和 Golang 的经验

Intro
---

 - JVM（Java Virtual Machine，Java 虚拟机）的缩写
 - JRE（Java Runtime Environment，Java 运行环境），运行 Java 程序所必须的环境的集合，包括 JVM 和 Java 程序所需的核心类库等
 - JDK（Java Development Kit ，Java 开发工具包）是 Java 语言的软件开发工具包(SDK)。JDK 是提供给 Java 开发人员使用的，其中包含了 Java 的开发工具，也包括了JRE。

所以安装了JDK，就不用在单独安装 JRE 了。他们的关系为 JVM <= JRE <= JDK，包含关系


Init
---

首先下载 JDK，然后设置相关环境变量

```sh
export JAVA_HOME=/home/lycheng/bin/jdk
export JRE_HOME=/home/lycheng/bin/jdk/jre
export PATH="$JAVA_HOME/bin:$PATH"
```

`which java` 看下是否有问题，然后就是 HelloWorld 程序

```java
class HelloWorldApp {
    public static void main(String[] args) {
        System.out.println("Hello World!");
    }
}
```

编译，执行

```sh
javac main.java
# 生成 HelloWorldApp.class
java HelloWorldApp
```

Basic-Syntax
---

### Class

规则

 1. 一个源文件中只能有一个 public 类
 2. 一个源文件可以有多个非 public 类
 3. 源文件的名称应该和 public 类的类名保持一致。例如：源文件中 public 类的类名是 Employee，那么源文件应该命名为 Employee.java
 4. 如果一个类定义在某个 package 中，那么 package 语句应该在源文件的首行
 5. 如果源文件包含 import 语句，那么应该放在 package 语句和类定义之间。如果没有 package 语句，那么 import 语句应该在源文件中最前面
 6. import 语句和 package 语句对源文件中定义的所有类都有效。在同一源文件中，不能给不同的类不同的包声明

class 定义的基本语法

```java
public class Animal {

    // 成员变量
    private String name;

    // 类变量
    private static String animalType = "cat";

    public Animal() {
        // 调用其它构造函数
        this("default-name");
    }

    public Animal(String name) {
        this.name = name;
        // 可以在实例方法中修改类静态变量，会提示 warning
        // this.animalType = "dog";

        // 也可以简单的，不提示 warning
        // animalType = "dog";
    }

    @Override
    public String toString() {
        // Override 会去检查父类有没该方法，签名是否对的上
        // 不加的话如果对不上，则会认为是新的方法
        return "Animal's name is " + name + ", type is " + animalType;
    }

    public static String getAnimalType() {
        return animalType;
    }

    public static void setAnimalType(String animalType) {
        Animal.animalType = animalType;
    }
}
```

其中 this 的用法

 - 当你局部变量有和类实例变量同名时，用来明确表示使用的是类实例变量
 - 当前的对象的引用
 - 调用别的构造函数

### Inheritance

Java 中只允许单继承

```java
class Cat extends Animal{
    public Cat(String name) {
        super(name);
    }

    public String str() {
        return super.toString();
    }
}
```

上述的 super(name) 是调用父类的构造函数，第二个 super 则是父类引用，用于调用父类的成员函数。

关于 static 有以下特性

 - 在子类调用父类的 static 方法，也会影响到父类
 - static 的属性不依赖于任何的对象和子类，在内存中只会存在一份副本
 - static 语句在类加载的时候执行，按顺序执行，并只执行一次

需要注意 Java 的类方法和属性在定义的时候可以设定访问权限，对应的关系如下

Access Level | Class | Package | Subclass | World
--- | --- | --- | --- | ---
public | Y | Y | Y | Y
protected | Y | Y | Y | N
no | Y | Y | N | N
private | Y | N | N | N

可以看到，private 的最严格，public 最松散。

### Interface

interface 简单来说就是规定了类的函数签名

```java
public interface Bicycle {
    void speedUp(int incrment);
    void applyBreaks(int decrement);
}
```

```java
public class TheBicycle implements Bicycle {

    private String brand;
    private int speed;

    public TheBicycle(String brand) {
        this.brand = brand;
        this.speed = 0;
    }

    @Override
    public void speedUp(int incrment) {
        this.speed += incrment;
    }

    @Override
    public void applyBreaks(int decrement) {
        if (decrement > this.speed) {
            this.speed -= decrement;
        } else {
            this.speed = 0;
        }
    }
}
```

与类继承的异同如下

 - 类继承仅允许单继承，而接口允许继承（extends）多个接口
 - 类能实例化对象，但接口不能，所以也没有构造函数
   - 抽象类同样不能实例化，继承其的子类也必须实现父类的抽象方法，其余的非抽象方法则可当做为子类提供的默认实现
 - 接口中可以含有变量，但是接口中的变量会被隐式的指定为 `public static final` 变量（并且只能是 public，用 private 修饰会报编译错误）
 - 接口被类实现其函数签名

有了接口，实际调用的时候，可以通过声明接口的参数，至于其底层实现则不关心

```java
public class Main {

    public static void test(Transportation t) {
        System.out.println(t);
    }

    public static void main(String[] args) {
        System.out.println("Hello World!");

        // Bicycle 和 Car 都实现了 Transportation 这个接口
        Bicycle b = new TheBicycle("Giant");
        Car c = new Car();

        test(b);
        test(c);
    }
}
```

与继承不同，接口实现这种方式不同的对象可以是完全不相干的，保证其接口是相同的就可以。

Project-Structure
---

### Package

首先，一个 java 文件中只能有一个类是 public 的，所以定义多个类的时候必须有多个文件。而多个文件的管理则必须通过 package 来管理。

package 在文件层面看就是同一个文件夹下的不同 java 文件，代码层面就是 . 分隔的模块。

```
├── core
│   ├── Bicycle.java
│   ├── Car.java
│   └── Transportation.java
└── Main.java
```

每一个 Java 文件必须写明来自哪个 package

```java
package core;

// package name 全小写
```

在实际使用的时候可以通过 `import` 语句来引入系统 / 自定义的 package。

```java
import java.util.Date;

public class Main {

    public static void test(core.Transportation t) {
        System.out.println(t);
    }

    public static void main(String[] args) {
        System.out.println("Hello World!");

        core.Bicycle b = new core.Bicycle("Giant");
        core.Car c = new core.Car();

        test(b);
        test(c);

        // 如果去掉 Date 的 import
        // java.util.Date d = new java.util.Date();
        // 也可以 import java.util.*; 这样也可以不用写完整的类名，但是不推荐
        Date d = new Date();
        System.out.println(d);
    }
}
```

上述的代码也可以添加 import 语句来简化代码

```java
import core.Transportation;
import core.Bicycle;
import core.Car;

// Car c = new Car();
```

需要注意的是，package 里面定义的类只有 public 外部（别的 package）才可见。

如果使用通配符 * 来 import 还需要注意的是, * 只会 import 那一层级的类，不会递归查找去 import

```java
import java.awt.*;
import java.awt.color.*; // 如果想要使用 color 的类，则必须多加一个 import
```

#### Static-Import

在类中定义了 static 成员时，如果外部需要使用，则 import 之后需要带上类名 prefix 才能访问。此时就可以使用 static import 就可以减少代码量

```java
// before
// System.out.println(Math.PI);

// after
// import static java.lang.Math.PI;

System.out.println(PI);
```

方便使用的同时也带来了问题，丢失了这些 static 成员的出处，查看代码是容易混乱，谨慎使用。

### Naming

 1. 驼峰命名
 2. 函数，方法，变量以首字母小写的驼峰命名
 3. 类，接口以首字母大写的驼峰命名
 4. 常量用全大写，下划线分隔的写法

企业开发的 package 以域名作为项目的 package 命名，如 `com/baidu/www/...`

 - package 命名为全小写，原则上不加分隔符
 - Java 的关键字 / 数字开头 不推荐使用

References
---

 1. [Idea 社区版和商业版的区别](https://www.jetbrains.com/idea/features/editions_comparison_matrix.html)
 2. [JDK 下载](http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html)
 3. [Java Tutorial](https://docs.oracle.com/javase/tutorial/)
 4. [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html)

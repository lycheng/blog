---
layout: post
title: Java8 学习记录 02
tags: [java, java8, lambda, generic, annotation]
---

环境：Java8, Idea 社区版，ubuntu 18.04 LTS

背景：基本没有 Java 实战经验，有 Python 和 Golang 的经验

前篇 [01](/2018/07/13/get-started-in-java8-01/)

Basic-Data-Type
---

常见类型有

 - byte (8)
 - short (16)
 - int (32)
 - long (64)
 - float (32)
 - double (64)
 - boolean
 - char (16)

需要注意的是，局部变量声明后需要进行初始化，否则将报错。但作为类的成员则有默认值，如 int 不初始化则默认为 0。

Array
---

Array 为定长的固定类型的数组。

```java
// 声明但不初始化使用则会报错，variable X might not have been initialized
int[] array;

array = new int[1];

// 如果不赋值，array[0] 为对应类型的默认值，这里为 0
array[0] = 1;
System.out.println(array);

// array = {1};
// 不能重新初始化

int[] list = {1, 2, 3, 4};
System.out.println(list);

// 二维数组
String[][] names = {
    {"Mr. ", "Mrs. ", "Ms. "},
    {"Smith", "Jones"}
};
```

在 `java.util.Arrays` 中包含众多 array 的有用的方法

```java
int[] src = {1, 2, 3, 4, 5, 6, 7};
int[] dst = Arrays.copyOfRange(src, 0, 5); // copy
Arrays.sort(dst); // sort

for (int item: dst) {
    System.out.println(item);
}

System.out.println(Arrays.binarySearch(src, 8)); // binarySearch
```

Nested-Classes
---

嵌套类分两种，static 的和 non-static 的。前者为静态嵌套类，后者为内部类。

### Static-Nested-Classes

静态嵌套类（下称嵌套类）为包含其的类（这里称为外部类）的一个成员。

嵌套类能访问外部类的 static 属性（包括 private）和方法，即与该类关联，而不是与该类的实例管理。常用来实现外部类相关的一些 helper 方法。

```java
public class OuterClass {

    private static int objCnt = 0;

    public static class StaticNestedClass {

        public int getObjCnt() {
            return objCnt;
        }
    }

    public OuterClass() {
        objCnt +=1;
    }
}

// OuterClass.StaticNestedClass snc = new OuterClass.StaticNestedClass();
// System.out.println(snc.getObjCnt());
```

### Inner-Classes

内部类的实例与外部类的实例绑定，与嵌套类不同的是，内部类不允许有 static 的成员。

```java
public class OuterClass {

    public int v = 0;

    public int x = 0;

    public class InnerClass {

        public int v = 1;

        public void testPrint() {
            System.out.println("this.v = " + v);
            System.out.println("this.v = " + this.v);
            System.out.println("OuterClass.this.x = " + x);
            System.out.println("OuterClass.this.v = " + OuterClass.this.v);
        }
    }
}

// OuterClass.InnerClass ic = oc.new InnerClass();
// ic.testPrint();
// -> this.v = 1
// -> this.v = 1
// -> OuterClass.this.x = 0
// -> OuterClass.this.v = 0
```

上述 this 的用法与之前说过的类似，用于指明访问的是哪一个变量。如果内部类定义了与外部类同名的成员，则直接使用会屏蔽外部类对应的成员。

### Local-Classes

```java
public class Main {

    public static void main(String[] args) {

        String word = "word";
        // word = "helloworld";
        // 去掉注释则会报错

        class Test {
            public void print() {
                System.out.println(word);
            }
        }

        Test t = new Test();
        t.print();
    }
}
```

本地类用于用完即弃的场景。

需要注意的是，在本地类中可以访问外部的局部变量，前提是这些变量是 final 的或者是 effectively final。effectively final 为 Java8 新增的特性，即变量初始化时编译器都当作 final，但在更新时变成了 non-final。

同样的，如果本地类中定义了同名的成员，则会屏蔽外部的变量。

### Anonymous-Classes

```java
public class Main {

    interface Greeter {
        public void sayHi();
    }

    public static void main(String[] args) {

        Greeter helloWorld = new Greeter() {
            public void sayHi() {
                System.out.println("hello-world");
            }
        };

        helloWorld.sayHi();
    }
}
```

同内部类和本地类，匿名类都不能有 static 属性 / 方法，但是可以有 `final static` 的属性。匿名类的常见例子如实现自定义排序的规则。

```java
Integer[] ls = {1, 4, 2, 3, 0};

Arrays.sort(ls, new Comparator<Integer>() {
    @Override public int compare(Integer x, Integer y) {
        return x - y; // 升序排列
    }
});
```

Lambda
---

上述的排序可以以 Lambda 表达式改写

```java
Arrays.sort(ls, (x, y) -> x - y);
```

Lambda 表达式基本语法如下

```
(arg1, arg2...) -> { body }

(type1 arg1, type2 arg2...) -> { body }

() -> { body }
```

这里还有另一个常见的例子，用于过滤数组

```java
import java.util.Arrays;
import java.util.List;

interface Predicate<T> {
    boolean test(T t);
    // 用于 Lambda 的 interface 只能有一个方法
}

public class Main {
    public static void main(String[] args) {
        List<Integer> list = Arrays.asList(1, 2, 3, 4, 5, 6, 7);

        evaluate(list, x -> x > 1);
        evaluate(list, x -> true);

        // 将标准库原有的函数转化为 Lambda 表达式
        list.forEach(System.out::println);
    }

    public static void evaluate(List<Integer> list, Predicate<Integer> predicate) {
        for (Integer n : list) {
            if (predicate.test(n)) {
                System.out.print(n + " ");
            }
        }
        System.out.println();
    }
}
```


基本的规则如下

 - 可带参数，也可不带参数
 - 可带类型，也可不带类型，根据上下文来推导类型

Lambda 更多与 Interface 细节相关，这里先只介绍相关语法。

Annotation
---

注解，对被注解代码的逻辑没有直接的影响，而是在逻辑以外提供额外的数据信息。

 - 可提供信息给编译器使用
 - IDE 可根据注解生成对应的配置文件
 - 其信息可被编译进 class 文件中，或者说保留在 Java 虚拟机中，供运行时判断

对于 Java 代码从编写到运行有三个时期

 1. 代码编辑
 2. 编译成 .class 文件
 3. 读取到 JVM 运行

针对这三个时期有三种 Annotation 对应

 1. RetentionPolicy.SOURCE  // 只在代码编辑期生效
 2. RetentionPolicy.CLASS   // 在编译期生效，默认值
 3. RetentionPolicy.RUNTIME // 在代码运行时生效

除此之外，Java 提供了 @Target 这个 元注解 来指定某个 Annotation 修饰的目标对象，如

```java
@Target({TYPE, FIELD, METHOD, PARAMETER, CONSTRUCTOR, LOCAL_VARIABLE})
@Retention(RetentionPolicy.SOURCE)
public @interface SuppressWarnings {
    /**
     * The set of warnings that are to be suppressed by the compiler in the
     * annotated element.  Duplicate names are permitted.  The second and
     * successive occurrences of a name are ignored.  The presence of
     * unrecognized warning names is <i>not</i> an error: Compilers must
     * ignore any warning names they do not recognize.  They are, however,
     * free to emit a warning if an annotation contains an unrecognized
     * warning name.
     *
     * <p> The string {@code "unchecked"} is used to suppress
     * unchecked warnings. Compiler vendors should document the
     * additional warning names they support in conjunction with this
     * annotation type. They are encouraged to cooperate to ensure
     * that the same names work across multiple compilers.
     * @return the set of warnings to be suppressed
     */
    String[] value();
}
```

`SuppressWarnings` 这个注解作用于类型函数等等，并且在代码编辑期间生效。代码编辑期间的注解更多是用于代码检查，如更常见的 `Override`。

### Runtime-Annotation

runtime annotation 是基于 Java 本身的反射机制来实现，反射指的是在运行期间动态操作类 / 对象，这里先不展开来讲。

```java
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
@interface JsonKeyField {
    String value() default "";
}

public class Person {

    @JsonKeyField("first_name")
    public String firstName;

    @JsonKeyField("last_name")
    public String lastName;

    @JsonKeyField()
    public int age;

    public Person(String firstName, String lastName, int age) {
        this.firstName = firstName;
        this.lastName = lastName;
        this.age = age;
    }

    public String toJsonStr() throws JsonProcessingException, IllegalAccessException {
        Map<String, Object> map = new HashMap<String, Object>();
        for (Field field : this.getClass().getDeclaredFields()) {
            if (field.isAnnotationPresent(JsonKeyField.class)) {
                JsonKeyField jkf = field.getAnnotation(JsonKeyField.class);
                String key = jkf.value().isEmpty()? field.getName(): jkf.value();
                map.put(key, field.get(this));
            }
        }
        return new ObjectMapper().writeValueAsString(map);
    }
}
```

上述代码使用注解 `JsonKeyField` 来规范导出成 JSON 时候的字段，如果没有指定，则沿用原有的成员名字。这里的写法有点类似 Golang 中的 struct tag 的功能，如果有多种格式（如 Msgpack）的需求可以写多个注解。

其实可以看到，注解本身其实只起到一个标记或者说文档的作用，而真正的用处是供外部调用在运行时提供信息给外部进行判断来执行相应的操作。

需要注意的是，注解中只有一个属性，使用 `value()` 来定义，则使用注解时可以不用指定参数名。常见的用于代码检查的注解和用于运行时检查的注解，还有编译时使用的注解，后者这边就不进行讨论了。

Generics
---

泛型

```java
public class GenericBox<T>  {

    private T item;

    public T getItem() {
        return item;
    }

    public void setItem(T item) {
        this.item = item;
    }
}

// Box<String> box = new Box<>();
```

这里需要注意的是，泛型中的类型不能是基础类型（如 int，char），你可以是任何的类，接口。

这里有个约定的类型命名

 - E - Element (used extensively by the Java Collections Framework)
 - K - Key
 - N - Number
 - T - Type
 - V - Value
 - S,U,V etc. - 2nd, 3rd, 4th types

### Generic-Method

```java
interface Pair<K, V> {
    public K getKey();
    public V getValue();
}

class OrderedPair<K, V> implements Pair<K, V> {

    private K key;
    private V value;

    public OrderedPair(K key, V value) {
        this.key = key;
        this.value = value;
    }

    public K getKey()	{ return key; }
    public V getValue() { return value; }

    public static <K, V> boolean equals(Pair<K, V> p1, Pair<K, V> p2) {
        return true;
    }
}

// Pair<Integer, String> p1 = new OrderedPair<>(1, "apple");
// Pair<Integer, String> p2 = new OrderedPair<>(2, "pear");
// boolean same = OrderedPair.<Integer, String>equals(p1, p2);
// same = OrderedPair.equals(p1, p2); // 1.7+
```

与普通的函数不同的是，上述的泛型方法声明时前面需要添加 `<T...>`

### Bounded-Type-Parameter

当使用泛型时，如尝试在函数内进行比较操作，如果一些自定义类没有实现 compare 相关的方法，则会在运行时报错。这里可以引入泛型边界的用法。

```java
class Box<T extends Number> {
    private T item;

    public T getItem() {
        return item;
    }

    public void setItem(T item) {
        this.item = item;
    }
}

// Box<Number> box = new Box<>();
```

如果使用类不是 Number 或者不是继承了 Number 的类则会在编译时报错。此外也可以添加多个约束，语法为 `<T extends B1 & B2 & B3>`

```java
class Data implements Comparable<Data> {
    int data;

    public int compareTo(Data d) {
        return data - d.data;
    }

    public int function(Box<Double> bi) {
        return 1;
    }
}

class Box<T extends Comparable<T>> {
    private T item;

    public T getItem() {
        return item;
    }

    public void setItem(T item) {
        this.item = item;
    }

    public static void f(List<Number> l) {
        ;
    }
}

// Data data = new Data();
// Box<Data> box = new Box<>();

// Box.f(Arrays.asList(1, 2, 3, 4)); // Error
```

也可以使用接口去限制，这里则是要求必须实现 `Comparable` 接口。这里需要注意的是，像上述代码 `Box` 中像方法 `f` 如果试图传入 `List<Integer>` 则会报错。

`Integer` 的确是 `Number` 子类，但 `Box<Integer>` 不是 `Box<Number>` 的子类，准确来说两者没有任何关系，他们的父类均是 `Object`。另一方面 `ArrayList<String>` 的父类是 `List<String>` 并以此类推。

### Type-Inference

类型推断

```java
Map<String, List<String>> myMap = new HashMap<String, List<String>>();
Map<String, List<String>> myMap1 = new HashMap<>();
```

上述两种调用都是合法的，需要注意的是 `HashMap` 后面的 `<>` 不能忽略。这里涉及更多是编译器的优化，如

```java
void processStringList(List<String> stringList) {
    // ...
}

// processStringList(Collections.emptyList());
// 上述调用在 Java7 会报错，Java8 则不会
```

Java10 更是引进了 var 的类型判断机制，在我看来，写代码的时候借助 IDE 工具一般就能解决这些问题。

### Wildcard

通配符，这里有三种通配符

 - Upper Bounded Wildcard
 - Unbounded Wildcard
 - Lower Bounded Wildcard

其对应的语法

```java
// Upper Bounded Wildcard
// 表示 Number 或者 Number 的子类都可以
public static double sumOfList(List<? extends Number> list) {
    double s = 0.0;
    for (Number n : list)
        s += n.doubleValue();
    return s;
}

// Unbounded Wildcard
// 没有任何限制
public static void printList(List<?> list) {
    for (Object elem: list)
        System.out.print(elem + " ");
    System.out.println();
}

// Lower Bounded Wildcard
// Integer 或者 Integer 的父类
public static void addNumbers(List<? super Integer> list) {
	for (int i = 1; i <= 10; i++) {
		list.add(i);
	}
}
```

通配符的使用主要是为了解决诸如 `Box<Integer>` 不是 `Box<Number>` 的子类的问题。

对于选择 Upper 还是 Lower，可以以严于律己宽于待人来设计，即

 - 对于外部输入，用户调用的参数，选择 Upper Bounded Wildcard，它最终也可以是 null 或者 Object 的子类
 - 对于函数的输出，则应该使用 Lower Bounded Wildcard

### Type-Erasure

类型擦除是 Java 泛型的实现方法。编译器在编译的时候去掉了泛型的信息（在 [这里](https://stackoverflow.com/questions/313584/what-is-the-concept-of-erasure-in-generics-in-java) 可以看到编译和反编译代码的区别）。

和 C++ 不同，C++ 会为每一种类型生成对应的函数，而 Java 则只生成一份代码（以 Object 替代自定义类型 T，以及在某些地方添加类型转换）。

References
---

 1. [Difference Between Final And Effectively Final](https://stackoverflow.com/questions/20938095/difference-between-final-and-effectively-final)
 2. [深入浅出 Java 8 Lambda](http://blog.oneapm.com/apm-tech/226.html)
 3. [Java 8 Lambda 表达式详解](https://segmentfault.com/a/1190000009186509)
 4. [Annotation 详解](http://wingjay.com/2017/05/03/Java-%E6%8A%80%E6%9C%AF%E4%B9%8B%E6%B3%A8%E8%A7%A3-Annotation/)
 5. [Java 泛型和类型擦除](http://www.importnew.com/13907.html)
 6. [Java 类型擦除](http://www.angelikalanger.com/GenericsFAQ/FAQSections/TechnicalDetails.html#FAQ101)

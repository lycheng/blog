---
layout: post
title: Java 学习记录 03
tags: [java, thread, concurrency]
---

环境：Java8, Idea 社区版，ubuntu 18.04 LTS

背景：基本没有 Java 实战经验，有 Python 和 Golang 的经验

前篇

 - 学习记录 [01](/2018/07/13/get-started-in-java-01/)
 - 学习记录 [02](/2018/07/27/get-started-in-java-02/)

Thread
---

### Thread-Object

如果需要初始化一个 Thread 对象，则有两种办法

```java
public class HelloRunnable implements Runnable {

    public void run() {
        System.out.println("Hello from a thread!");
    }

    public static void main(String args[]) {
        (new Thread(new HelloRunnable())).start();
    }

}

class HelloThread extends Thread {

    public void run() {
        System.out.println("Hello from a thread!");
    }

    public static void main(String args[]) {
        (new HelloThread()).start();
    }

}
```

上述两种方法在这里是等价的，run 方法实现具体的线程的功能，通过 start 方法去启动线程。具体的选择看具体的要求，一个是实现接口，一个是继承，推荐使用前者。

### Thread-Management

你看 Thread 相关实现会发现，一些用于暂停，关闭线程的方法都被废弃了。像 Thread.stop 方法，会直接关掉线程，导致没办法去执行一些资源释放的操作，容易造成不一致的情况。所以最好的情况是通知线程，让线程自己处理。

相关方法为

 - public void Thread.interrupt()
 - public boolean isInterrupted()
 - public static boolean interrupted()

`isInterrupted` 方法和 `interrupted` 方法实际上有些不同

 - `isInterrupted` 方法仅仅检查是否处于中断状态
 - `interrupted` 方法读取中断状态并清除，即设为 false

`interrupted` 方法可以理解为，当前的请求中断的需求已经知悉，而是否进行处理则是当前线程的责任了。`interrupt` 方法做的仅仅是将线程内的标志位设为 true。

除此以外，如果线程正在处于阻塞状态（Thread.sleep, join ...）时，则会抛出 `InterruptedException` 异常，这个异常需要注意下

 - 当抛出异常，调用 `isInterrupted` 方法，此时处于 false 状态
 - 如果捕获该异常，则应重置该状态，即 `Thread.currentThread().interrupt()`

可见示例代码

```java
public static void main(String[] args) {
    Thread t = new Thread() {
        public void run() {
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                System.out.println(Thread.currentThread().isInterrupted()); // false
            }
        }
    };
    t.start();
    t.interrupt();

    try {
        Thread.sleep(1000);
    } catch (InterruptedException e) {

    }
}
```

Synchronization
---

### happens-before

 - Thread.start 方法调用前的代码 happens-before 线程的创建，相应的修改对新线程可见
 - 一个线程结束后，则会导致 Thread.join 返回，所有该线程结束前的代码 happens-before join 方法调用，该线程的操作对调用 join 的线程可见

### synchronized

synchronized methods

```java
public class SynchronizedCounter {
    private int c = 0;

    public synchronized void increment() {
        c++;
    }

    public synchronized void decrement() {
        c--;
    }

    public synchronized int value() {
        return c;
    }
}

// 也可以写成如下方式
class SynchronizedCounter {
    private int c = 0;

    public void increment() {
        synchronized (this) {
            c++;
        }
    }

    public void decrement() {
        synchronized (this) {
            c--;
        }
    }

    public int value() {
        synchronized (this) {
            return c;
        }
    }
}

// 可以明确指定锁来分离不同的需要加锁的逻辑
public class MsLunch {
    private long c1 = 0;
    private long c2 = 0;
    private Object lock1 = new Object();
    private Object lock2 = new Object();

    public void inc1() {
        synchronized(lock1) {
            c1++;
        }
    }

    public void inc2() {
        synchronized(lock2) {
            c2++;
        }
    }
}
```

同步方法有下面的特点

 - 不同的线程对同一个对象的同步方法调用不会交叉，即一个调用时另一个会 block 然后等前一个调用完成
 - 前一个调用 happens-before 后面别的同步方法的调用，保证改动对所有线程可见
 - 构造函数不能（也没意义）添加 synchronized 关键字

这样就保证了不同线程调用同一个对象时，读、写数据不会造成不一致的情况。

### locks

内在锁（intrinsic lock）或称为监视器锁（monitor lock），用于建立不同线程间调用时 happens-before 的关系。

具体的定义为

> Every object has an intrinsic lock associated with it. By convention, a thread that needs exclusive and consistent access to an object's fields has to acquire the object's intrinsic lock before accessing them, and then release the intrinsic lock when it's done with them. A thread is said to own the intrinsic lock between the time it has acquired the lock and released the lock. As long as a thread owns an intrinsic lock, no other thread can acquire the same lock. The other thread will block when it attempts to acquire the lock.

> When a thread releases an intrinsic lock, a happens-before relationship is established between that action and any subsequent acquisition of the same lock.

当一个线程执行 synchronized 相关方法时，则申请一个内在锁，等到退出（哪怕是未捕捉的异常退出）时释放锁，别的线程才可继续调用该对象的 synchronized 方法。synchronized 为可重入锁，即同一个线程内的可以直接调用其它 synchronized 修饰的方法。

### atomic-access

 - Reads and writes are atomic for reference variables and for most primitive variables (all types except long and double).
 - Reads and writes are atomic for all variables declared volatile (including long and double variables).

关于 long 和 double 类型的读写不是原子性，可见后面的参考文章。即对 long 和 double 类型的读写最好放在 synchronized 中进行。

### guarded-block

即在线程中循环检查某个条件，条件满足之后才进行后续的行为。比较推荐的做法是，检查该条件，并且调用 wait 方法

```java
public synchronized void guardedJoy() {
    // This guard only loops once for each special event, which may not
    // be the event we're waiting for.
    while(!joy) {
        try {
            wait();
        } catch (InterruptedException e) {}
    }
    System.out.println("Joy and efficiency have been achieved!");
}

// 另一个方法调用 notifyAll() 方法去通知等待锁释放的线程
public synchronized notifyJoy() {
    joy = true;
    notifyAll();
}
```

这里需要注意的是，该处的 wait 方法属于 Object 的方法，只能在 synchronized 修饰的方法中使用。除了 notifyAll 以外，还有个 notify 方法，该方法则是随机唤醒一个在等待锁释放的线程，平时更倾向于使用 notifyAll。

Immutable Objects
---

不可变对象，即对象本身的状态（字段）不会更新（不能更新），具体的策略如下

 - 如果需要修改对象属性，可通过方法新建一个对象，原有的对象不变
 - 所有的字段都已经是私有的，加上 final
 - 将类声明为 final 的，子类服务重写其方法，也可以通过将构造函数声明为 private，通过工厂方法创建对象
 - 只有一个字段是对象引用，并且被引用的对象也是不可变对象

High Level Concurrency Objects
---

### Lock-Objects

Lock 类比之前的 synchronized 提供更加细致的方法，如支持 wait / notify 方法，支持 tryLock 可以用于获取锁的超时控制。

### Concurrent-Collections

 - BlockingQueue - FIFO 如果队列满了 / 空了阻塞相应的请求
 - ConcurrentMap - 对 KV 的操作加锁

### Atomic-Variables

如 `java.util.concurrent.atomic.AtomicInteger` 对其进行增减操作不需要进行额外的加锁，其内部进行锁的相关操作。

相比 synchronized 修饰的代码，这边能更精确的控制临界区，减少不必要的同步操作。

References
---

 1. [官方教程](https://docs.oracle.com/javase/tutorial/essential/concurrency/index.html)
 2. [Why are Thread.stop, Thread.suspend and Thread.resume Deprecated?](https://docs.oracle.com/javase/7/docs/technotes/guides/concurrency/threadPrimitiveDeprecation.html)
 3. [Long and Double Values Are Not Atomic in Java](https://dzone.com/articles/longdouble-are-not-atomic-in-java)
 4. [死锁和活锁的区别](https://stackoverflow.com/questions/6155951/whats-the-difference-between-deadlock-and-livelock)
 5. [Lock Objects](https://docs.oracle.com/javase/tutorial/essential/concurrency/newlocks.html)

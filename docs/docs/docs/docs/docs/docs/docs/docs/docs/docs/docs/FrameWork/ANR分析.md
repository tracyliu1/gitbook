## Android ANR

### ANR 四种类型



#### 1.ContentProvider 超时

1. ContentProvider创建发布超时并不会ANR
2. 使用ContentProviderclient来访问ContentProverder可以自主选择触发ANR，超时时间自己定
   client.setDetectNotResponding(PROVIDER_ANR_TIMEOUT);

#### 2.Service超时

1. Service的以下方法都会触发ANR：onCreate(),onStartCommand(), onStart(), onBind(), onRebind(), onTaskRemoved(), onUnbind(),
   onDestroy().
2. 前台Service超时时间为20s，后台Service超时时间为200s
3. 如何区分前台、后台执行————当前APP处于用户态，此时执行的Service则为前台执行。
4. 用户态：有前台activity、有前台广播在执行、有foreground service执行

#### 3.broadcast超时

1. 静态注册的广播和有序广播会ANR，动态注册的非有序广播并不会ANR
2. 广播发送时，会判断该进程是否存在，不存在则创建，创建进程的耗时也算在超时时间里
3. 只有当进程存在前台显示的Activity才会弹出ANR对话框，否则会直接杀掉当前进程
4. 当onReceive执行超过阈值（前台15s，后台60s），将产生ANR
5. 如何发送前台广播：Intent.addFlags(Intent.FLAG_RECEIVER_FOREGROUND)

#### 4.Input超时（5s）

1. InputDispatcher发送key事件给 对应的进程的 Focused Window ，对应的window不存在、处于暂停态、或通道(input channel)占满、通道未注册、通道异常、或5s内没有处理完一个事件，就会发生ANR 
2.  InputDispatcher发送MotionEvent事件有个例外之处：当对应Touched Window的 input waitQueue中有超过0.5s的事件，inputDispatcher会暂停该事件，并等待5s，如果仍旧没有收到window的‘finish’事件，则触发ANR  
3. 下一个事件到达，发现有一个超时事件才会触发ANR



##### Activity生命周期超时会不会ANR？——经测试并不会。 除了普通Anr还有background anr

```
override fun onCreate(savedInstanceState: Bundle?) {
       Thread.sleep(60000)
       super.onCreate(savedInstanceState)
       setContentView(R.layout.activity_main)
   }

```



## background ANR

提问: BroadcastReceiver过了60秒居然没有ANR？ 现场代码如下

```java
 public class NetworkReceiver extends BroadcastReceiver{
    private static final String LOGTAG = "NetworkReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        Log.i(LOGTAG, "onReceive intent=" + intent);
        try {
            Thread.sleep(60000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        Log.i(LOGTAG, "onReceive end");
    }
}
```


回答：实际上已经发生了ANR，只是没有进行对话框弹出而已。这种ANR就是background ANR，即后台程序的ANR，我们可以通过过滤日志验证

```java
 adb logcat | grep "NetworkReceiver|ActivityManager|WindowManager"
I/NetworkReceiver( 4109): onReceive intent=Intent { act=android.net.conn.CONNECTIVITY_CHANGE flg=0x8000010 cmp=com.example.androidyue.bitmapdemo/.NetworkReceiver (has extras) }
I/ActivityManager(  462): No longer want com.android.exchange (pid 1054): empty #17
I/NetworkReceiver( 4109): onReceive end
W/BroadcastQueue(  462): Receiver during timeout: ResolveInfo{5342dde4 com.example.androidyue.bitmapdemo.NetworkReceiver p=0 o=0 m=0x108000}
E/ActivityManager(  462): ANR in com.example.androidyue.bitmapdemo
E/ActivityManager(  462): Reason: Broadcast of Intent { act=android.net.conn.CONNECTIVITY_CHANGE flg=0x8000010 cmp=com.example.androidyue.bitmapdemo/.NetworkReceiver (has extras) }
E/ActivityManager(  462): Load: 0.37 / 0.2 / 0.14
E/ActivityManager(  462): CPU usage from 26047ms to 0ms ago:
E/ActivityManager(  462):   0.4% 58/adbd: 0% user + 0.4% kernel / faults: 1501 minor
E/ActivityManager(  462):   0.3% 462/system_server: 0.1% user + 0.1% kernel
E/ActivityManager(  462):   0% 4109/com.example.androidyue.bitmapdemo: 0% user + 0% kernel / faults: 6 minor
E/ActivityManager(  462): 1.5% TOTAL: 0.5% user + 0.9% kernel + 0% softirq
E/ActivityManager(  462): CPU usage from 87ms to 589ms later:
E/ActivityManager(  462):   1.8% 58/adbd: 0% user + 1.8% kernel / faults: 30 minor
E/ActivityManager(  462):     1.8% 58/adbd: 0% user + 1.8% kernel
E/ActivityManager(  462): 4% TOTAL: 0% user + 4% kernel
W/ActivityManager(  462): Killing ProcessRecord{5326d418 4109:com.example.androidyue.bitmapdemo/u0a10063}: background ANR
I/ActivityManager(  462): Process com.example.androidyue.bitmapdemo (pid 4109) has died.
```

提问:可以更容易了解background ANR么？

回答:当然可以，**在Android开发者选项—>高级—>显示所有”应用程序无响应“勾选即可对后台ANR也进行弹窗显示，方便查看了解程序运行情况**。

## 定位分析

#### 1.main.log信息

```log
08-13 14:41:59.588  1901  1929 E ANRManager: ANR in com.okayprovision.splash (com.okayprovision.splash/.pages.ContentNewActivity), time=5050222
08-13 14:41:59.588  1901  1929 E ANRManager: Reason: Input dispatching timed out (Waiting to send non-key event because the touched window has not finished processing certain input events that were delivered to it over 500.0ms ago.  Wait queue length: 7.  Wait queue head age: 8900.8ms.)
08-13 14:41:59.588  1901  1929 E ANRManager: Load: 12.08 / 12.19 / 12.37
08-13 14:41:59.588  1901  1929 E ANRManager: Android time :[2020-08-13 14:41:59.55] [5060.263]
08-13 14:41:59.588  1901  1929 E ANRManager: CPU usage from 44514ms to 1641ms ago:
08-13 14:41:59.588  1901  1929 E ANRManager:   105% 2796/com.okayprovision.splash: 104% user + 0.6% kernel / faults: 6592 minor
08-13 14:41:59.588  1901  1929 E ANRManager:   4% 1901/system_server: 2.6% user + 1.3% kernel / faults: 13503 minor
08-13 14:41:59.588  1901  1929 E ANRManager: 1.1% TOTAL: 1.1% user + 0% kernel
 08-13 14:41:59.591  1901  1929 E ActivityManager: get crashInfo fail.

```

##### Reason: Input dispatching timed out

出现这种问题意味着主线程正在执行其他的事件但是比较耗时导致输入事件无法及时处理

出现ANR的一般有以下几种类型：
1:**KeyDispatchTimeout**（常见）
input事件在`5S`内没有处理完成发生了ANR。
logcat日志关键字：`Input  dispatching timed out`

2:**BroadcastTimeout**
前台Broadcast：onReceiver在`10S`内没有处理完成发生ANR。
后台Broadcast：onReceiver在`60s`内没有处理完成发生ANR。
logcat日志关键字：`Timeout of broadcast BroadcastRecord`

3:**ServiceTimeout**
前台Service：`onCreate`，`onStart`，`onBind`等生命周期在`20s`内没有处理完成发生ANR。
后台Service：`onCreate`，`onStart`，`onBind`等生命周期在`200s`内没有处理完成发生ANR
logcat日志关键字：`Timeout executing service`

4：**ContentProviderTimeout**
ContentProvider 在`10S`内没有处理完成发生ANR。 logcat日志关键字：timeout publishing content providers



#### 2. CPU负载

##### Load: 12.08 / 12.19 / 12.37

表示CPU负载，CPU负载是指某一时刻系统中运行队列长度之和加上当前正在CPU上运行的进程数，而CPU平均负载可以理解为一段时间内正在使用和等待使用CPU的活动进程的平均数量。

以上代表某一时刻的前1分钟、5分钟、15分钟的CPU平均负载。



##### CPU usage from

表示CPU使用率

- user： CPU在用户态的运行时间，不包括nice值为负数的进程运行的时间

- nice： CPU在用户态并且nice值为负数的进程运行的时间

- system：CPU在内核态运行的时间

- idle： CPU空闲时间，不包括iowait时间

- iowait： CPU等待I/O操作的时间

- irq： CPU硬中断的时间

- softirq：CPU软中断的时间

- faults:内存缺页，minor——轻微的，major——重度，需要从磁盘拿数据

  ###### iowait占比很高，意味着有很大可能，是io耗时导致ANR，具体进一步查看有没有进程faults major比较多。

  ###### 单进程CPU的负载并不是以100%为上限，而是有几个核，就有百分之几百，如4核上限为400%。

####  

#### 2.内存信息

```
Total number of allocations 476778　　进程创建到现在一共创建了多少对象

Total bytes allocated 52MB　进程创建到现在一共申请了多少内存

Total bytes freed 52MB　　　进程创建到现在一共释放了多少内存

Free memory 777KB　　　 不扩展堆的情况下可用的内存

Free memory until GC 777KB　　GC前的可用内存

Free memory until OOME 383MB　　OOM之前的可用内存

Total memory 当前总内存（已用+可用）

Max memory 384MB  进程最多能申请的内存
```

从含义可以得出结论：**Free memory until OOME **的值很小的时候，已经处于内存紧张状态。应用可能是占用了过多内存。

除了trace文件中有内存信息，普通的eventlog日志中，也有内存信息（不一定打印）

```
04-02 22:00:08.195  1531  1544 I am_meminfo: [350937088,41086976,492830720,427937792,291887104]
```

以上四个值分别指的是：

- Cached
- Free,
- Zram,
- Kernel,Native

Cached+Free的内存代表着当前整个手机的可用内存，如果值很小，意味着处于内存紧张状态。一般低内存的判定阈值为：4G 内存手机以下阀值：350MB，以上阀值则为：450MB

**ps:如果ANR时间点前后，日志里有打印onTrimMemory，也可以作为内存紧张的一个参考判断**




#### 3.Trace堆栈分析

> adb shell kill -3 pid

生成trace.txt文件

```java
DALVIK THREADS (18):
"main" prio=5 tid=1 Suspended
  | group="main" sCount=2 dsCount=0 obj=0x75844fb8 self=0x7f9e8af800
  | sysTid=2796 nice=0 cgrp=default sched=0/0 handle=0x7fa2acdeb0
  | state=S schedstat=( 1713035252809 102960560218 765402 ) utm=167472 stm=3831 core=0 HZ=100
  | stack=0x7fe1e16000-0x7fe1e18000 stackSize=8MB
  | held mutexes=
  at java.lang.String.hashCode(String.java:841)
  at java.util.Collections.secondaryHash(Collections.java:3405)
  at java.util.HashMap.put(HashMap.java:385)
  at android.animation.ValueAnimator.setValues(ValueAnimator.java:467)
  at android.animation.ValueAnimator.setIntValues(ValueAnimator.java:384)
  at android.animation.ValueAnimator.ofInt(ValueAnimator.java:288)
  at com.okayprovision.splash.view.SiriWaveView.initAnimator(SiriWaveView.java:226)
  at com.okayprovision.splash.view.SiriWaveView.access$400(SiriWaveView.java:32)
  at com.okayprovision.splash.view.SiriWaveView$3.onAnimationEnd(SiriWaveView.java:247)
  at android.animation.ValueAnimator.endAnimation(ValueAnimator.java:1171)
  at android.animation.ValueAnimator$AnimationHandler.doAnimationFrame(ValueAnimator.java:722)
  at android.animation.ValueAnimator$AnimationHandler.run(ValueAnimator.java:738)
  at android.view.Choreographer$CallbackRecord.run(Choreographer.java:800)
  at android.view.Choreographer.doCallbacks(Choreographer.java:603)
  at android.view.Choreographer.doFrame(Choreographer.java:571)
  at android.view.Choreographer$FrameDisplayEventReceiver.run(Choreographer.java:786)
  at android.os.Handler.handleCallback(Handler.java:815)
  at android.os.Handler.dispatchMessage(Handler.java:104)
  at android.os.Looper.loop(Looper.java:194)
  at android.app.ActivityThread.main(ActivityThread.java:5650)
  at java.lang.reflect.Method.invoke!(Native method)
  at java.lang.reflect.Method.invoke(Method.java:372)
  at com.android.internal.os.ZygoteInit$MethodAndArgsCaller.run(ZygoteInit.java:960)
  at com.android.internal.os.ZygoteInit.main(ZygoteInit.java:755)

```

**main**：main标识是主线程，如果是线程，那么命名成“Thread-X”的格式,x表示线程id,逐步递增。
**prio**：线程优先级,默认是5
**tid**：tid不是线程的id，是线程唯一标识ID
**group**：是线程组名称
**sCount**：该线程被挂起的次数
**dsCount**：是线程被调试器挂起的次数
**obj**：当前线程关联的java线程对象
**self**：该线程Native的地址

**sysTid**：是线程号(主线程的线程号和进程号相同)
**nice**：调度优先级 nice值越小则优先级越高
**sched**：分别标志了线程的调度策略和优先级
**cgrp**：调度归属组
**handle**：线程处理函数的地址。

**state**：是调度状态
**schedstat**：从 `/proc/[pid]/task/[tid]/schedstat`读出，CPU调度时间统计 括号中的3个数字依次是Running、Runable、Switch

- Running时间：CPU运行的时间，单位ns
- Runable时间：RQ队列的等待时间，单位ns
- Switch次数：CPU调度切换次数

**utm**：该线程在用户态所执行的时间，单位是jiffies，jiffies定义为sysconf(_SC_CLK_TCK)，默认等于10ms。

**stm**：该线程在内核态所执行的时间，单位是jiffies，默认等于10ms。 utm + stm = schedstat第一个参数值

**core**：是最后执行这个线程的cpu核的序号。

**stack**：线程栈的地址区间

**stackSize**：栈的大小

**mutex:** 所持有mutex类型，有独占锁exclusive和共享锁shared两类



![img](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/55ea536a4b3f4108abe5214f8ec15f0d~tplv-k3u1fbpfcp-zoom-1.image)





##### main线程处于 BLOCK、WAITING、TIMEWAITING状态，那基本上是函数阻塞导致ANR；如果main线程无异常，则应该排查CPU负载和内存环境。





### 案例分析



```
"main" prio=5 tid=1 Native
  | group="main" sCount=1 dsCount=0 flags=1 obj=0x74374ee8 self=0x149d8c3a00
  | sysTid=8720 nice=0 cgrp=default sched=0/0 handle=0x15226569a8
  | state=S schedstat=( 0 0 0 ) utm=7673 stm=891 core=0 HZ=100
  | stack=0x46803c3000-0x46803c5000 stackSize=8MB
  | held mutexes=
  kernel: (couldn't read /proc/self/task/8720/stack)
  native: #00 pc 000000000006a660  /system/lib64/libc.so (__epoll_pwait+8)
  native: #01 pc 000000000001fca4  /system/lib64/libc.so (epoll_pwait+52)
  native: #02 pc 0000000000015d08  /system/lib64/libutils.so (android::Looper::pollInner(int)+144)
  native: #03 pc 0000000000015bf0  /system/lib64/libutils.so (android::Looper::pollOnce(int, int*, int*, void**)+108)
  native: #04 pc 00000000001112e0  /system/lib64/libandroid_runtime.so (???)
  native: #05 pc 00000000001e166c  /system/framework/arm64/boot-framework.oat (Java_android_os_MessageQueue_nativePollOnce__JI+140)
  at android.os.MessageQueue.nativePollOnce(Native method)
  at android.os.MessageQueue.next(MessageQueue.java:325)
  at android.os.Looper.loop(Looper.java:142)
  at android.app.ActivityThread.main(ActivityThread.java:6558)
  at java.lang.reflect.Method.invoke(Native method)
  at com.android.internal.os.RuntimeInit$MethodAndArgsCaller.run(RuntimeInit.java:469)
  at com.android.internal.os.ZygoteInit.main(ZygoteInit.java:826)

```

如果没有明显异常，先搜索关键字“Binder:**8720**_”（这个8720是当前ANR进程的主进程号，系统一般都是按Binder:进程号_，进行拼接binger线程名）



---

[干货：ANR日志分析全面解析](https://juejin.cn/post/6971327652468621326)

[Android应用ANR分析]()

[Android ANR日志分析指南](https://zhuanlan.zhihu.com/p/50107397)




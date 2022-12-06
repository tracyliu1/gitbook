# 统计方法

按照 Android 官方文档：[android_developer: 应用启动时间](https://developer.android.com/topic/performance/vitals/launch-time) ，activity 启动时间的统计方法主要有下面几种：

## logcat: “Displayed”

在启动 activity 之后抓 logcat，在 log 里面搜 Displayed 关键字，会打印一个启动时间：

```
ActivityTaskManager: Displayed com.android.calculator2/.Calculator: +710ms
```

## am start -W xx

am start 命令加参数 -W，可以统计 activity 启动时间和启动类型，例如说：

```
C:\Users\mingming>adb shell "am start -W com.android.calculator2/.Calculator"
Starting: Intent { act=android.intent.action.MAIN cat=[android.intent.category.LAUNCHER] cmp=com.android.calculator2/.Calculator }
Status: ok
LaunchState: WARM
Activity: com.android.calculator2/.Calculator
TotalTime: 710
WaitTime: 731
```

有2个时间 TotalTime 和 WaitTime。

## reportFullyDrawn()

这是 sdk Activity 的一个接口，由应用主动调用，用于来告诉系统你自己的 activity 什么时候完全绘制完成了。官方的意思是说：由于系统统计的启动时间结束的时候，应该可能并没有准备好（例如说还要去联网取数据，再显示之类的），所以就留了个接口，让应用自己决定什么时候界面准备好了，再调用这个接口通知系统。应用调用后，logcat 里面会有下面的打印：

```
ActivityTaskManager: Fully drawn com.android.settings/.Settings: +836ms
```

## Trace: “launching:xx”

除了官方介绍的3钟方法以外，如果在 activity 启动的过程抓 systrace（要勾选 Activity Manager 和 System Server），在 system_server 进程中有一个标记启动 activity 的时间条：

![systrace launching](https://mingming-killer.github.io/img/pics/android/perf-activity-start/systrace_launching.png)

也可以看到统计的启动时间。

按照官方的说法，统计的启动时间包括下面几个流程：

1. 启动进程。
2. 初始化对象。
3. 创建并初始化 Activity。
4. 扩充布局。
5. 首次绘制应用。

上面几种方法的打印都是我同一个时间启动同一个应用同时得到的（我启动的是 AOSP 自带的 Calculator，reportFullDrawn 是 Settings，因为自带的应该我发现就只有这个调用了 reportFullDrawn），然而这几种方法统计出来的数值并不一样。这其中的时间差异在什么地方，应该以哪一个为准。下面将通过分析 activity 启动源码的方法来找到答案：

# activity 启动流程分析

源码分析基于 Android 10。activity 的启动流程非常复杂，完成的功能也很多（官方总结了5点，然而细节一大堆），这里也是说一个大致流程。不详细的罗列代码，目的是为了参照这个大纲，再去看代码，能很快定位到自己想要找的流程在代码哪个地方。

[点击这里看大图](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow.png)
![activity start flow](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow.png)

图中有一些图示先说明一下：

1. 不同的进程空间，用不同颜色的圈块表示，具体的可以看右上角的图标说明。图中以在桌面启动 Settings 为例子（App1 为 Launcher3，App2 为 Settings）。
2. **黑色加粗**的地方是一些流程中创建关键性变量的地方，**标红**的是涉及到统计时间和一些应用流程中的回调。
3. **绿色**的是一些辅助性说明：// 是注释；logcat 表示会打印 log；TraceBegin/End 表示 systrace 中抓到的时间条对应的函数路径。
4. 为了让图简洁一些，有一些流程中很浅的函数嵌套调用我就省略了。图中的一些虚线连接，并不是直接调用，而是一些异步操作，基本上都是 Message Handle，为了图简洁一些，我直接用虚线连接了，但是我还是会把具体发送到哪个线程处理给表现出来。
5. 冷/温/热 分支路线用不同颜色标志：**冷：蓝色**；**温：普通黑色**；**热：深红色**。
6. 启动 activity 的途径有很多，例如常见的调用 Context 的 startActivity 接口（例如说：点击桌面的图标），PendingIntent，还有上面说的 am start 命令。虽然调用的接口不太一样，但是最终都会汇聚到一个统一的入口函数：**ActivityStarter#startActivityMayWait()**。所以上图只是从这个统一的入口点开始绘制，前面不同途径的流程最后再补充。

官方虽然把启动流程分了5个部分，但是我并没有按照这个来分，我是根据我画的时序图部分来分的：

## Part1. SystemService startActivity

[点击这里看大图](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow_part1.png)
![activity start flow part1](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow_part1.png)

这一部分工作主要在 SystemService 中进行，由 AMS（ActivityManagerService） 和 WMS（WindowManagerService） 承担。android 不知道从哪个版本开始把以前很多 AMS 的代码挪到 WMS 里面去了，然后还多了一个 ATMS（ActivityTaskManagerService）。

主要干的事情是：

**1. 给要启动的 activity 创建 ActivityRecord 和 ActivityTask：**
  **(1).** ActivityStarter#startActivityMayWait() 一开始调用 ActivityMetricsLogger#.notifyActivityLaunching() 记录一个开始时间。**注意这个开始时间，它就是后面统计启动时间的开始时间**。同时这个时间点，会有一个 MetricsLogger:launchObserverNotifyIntentStarted 的 Trace 记录。

  **(2).** 经常在 logcat 中看到的类似下面的打印：

```
ActivityTaskManager: START u0 {act=android.intent.action.MAIN cat=[android.intent.category.LAUNCHER] flg=0x10000000 cmp=com.android.calculator2/.Calculator} from uid 0
```

也是在 startActivityMayWait 开始的地方打的。

  **(3).** 这里有一个分支，涉及到 冷/温/热启动 的不同流程。冷/温/热启动 的区分方式，我们先看流程，然后最后再总结。这里会去检查**有没有能复用的 ActivityRecord**，如果有就是 热启动 分支，如果没有就是 温/冷启动 分支。温/冷启动 分支的话，需要创建 ActivityTask 并且用的是前面新创建的 ActivityRecord；热启动 分支的话，直接拿之前的 ActivityRecord 和 ActivityTask。然后会调用 showStartingWindow 开始一段启动动画（温/冷 和 热启动 的启动动画是不一样的）。

**2 . 对上一个处于焦点的 activity 发起 pause 请求：**
  **(1).** 有了 ActivityRecord 和 ActivityStack 之后，冷/温/热启动 的分支就统一了：RootActivityContainer#resumeFocusedStacksTopActivities()。这个函数里面会就会通过 ClientLifecycleManager#scheduleTransaction() IPC(Binder) 到 App(ActivityThread) activity 的生命周期函数（就是我们熟悉的 activity 的 onCreate、onStart、onResume 这些）。这个设计有点意思的，但是这部分我省略了，后面有一个部分我画出相关的流程。这里知道**这是一个 IPC 跨进程调用，而且是异步的消息处理**就行了。这里是对上一个处于 Resumed 状态的 ActivityRecord 发的（我们例子中的是 Launcher3），发的是 PauseActivityItem，也就是 onPause 。因为是异步的，发完了消息请求就返回了。这里如果有可以 pause 的 ActivityRecord ，返回就是 true，然后 resumeFocusedStacksTopActivities() 就会中止，注释里写的是：”Skip resume: need to start pausing”。

  **(2).** 然后一路返回到 温/冷，热启动 分支那，不同的分支的返回值不一样：温/冷启动 分支返回的是 **START_SUCCESS**，热启动 分支返回的是 **START_TASK_TO_FRONT**。

  **(3).** 在 ActivityStarter#startActivityMayWait() 收到不同的返回值之后，会调用 ActivityMetricsLogger#notifyActivityLaunched()。从上面可以看得出这个 ActivityMetricsLogger 就是负责记录 activity 的各种性能指标数据的，分别由系统在不同的阶段插桩调用，可以看到官方系统里面其实就已经带了不少性能指标的数据了。notifyActivityLaunched() 这个函数里面会：
    a. 先在 AMS 保存的进程记录列表里面找有没有对应启动 activity 的进程记录；
    b. 保存这次启动的返回值（就是上面的 SUCCESS 还是 TASK_TO_FRONT）；
    c. 把本次的记录数据保存起来；
    d. 开始记录 Trace: “Launching: xx”。
**进程记录是否存在 和 启动返回值 是后面判断启动类型的重要数值；Trace 里面的 Launching:xx 是在这里才开始记录的，注意和 startActivityMayWait() 开始时候 记录的开始时间 对比一下， Trace 是在 startActivity() 返回之后才开始的，所以少了整个 startActivity() 函数的处理时间**。

  **(4).** 如果是 outResult == null ，那么 startActivityMayWait() 就直接返回了，apk 调用 activity#startActivity() 接口就完成调用了。但是其实这里 activity 还没启动起来，这也就是为什么 apk 调用 startActivity 很快就返回了，不会阻塞 UI线程，但是并不确定 activity 什么时候真正启动。但是如果 outResult != null ，就会把要填充启动数据的数据结构加到一个列表里面，并等待一个锁，等待后面启动完成，填充启动数据（这里填充启动数据结构虽然 温/冷启动 和 热启动 有区分，但是其实本质上没什么区别，我没太明白为什么还要单独区分一下）。

## Part2. App1 Pause 处理

[点击这里看大图](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow_part2.png)
![activity start flow part2](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow_part2.png)

这一部分工作先是在 App1 进程进行 Pause 的处理，然后继续回到 SystemService 中进行 App2 的 Resume 处理。

主要干的事情是：

**1 . App1 处理 pause 请求：**
  **(1).** Part1 中发送的 PauseActivityItem 是在 App1 的进程空间执行的，通过对 App1 的 UIThread（ActivityThread）发送一个 Message ，实现异步处理。在 UIThread 的 handleMessage() 中执行 PauseActivityItem#execute()。这个里面调用到了 ActivityThread#handlePauseActivity()，里面就会调用我们熟悉的 **Activity#OnPause()** 回调，并且把 activity 的状态设置为 **ON_PAUSE**（这个状态是用于配置 activity 生命周期流程调用的）。
  **(2).** PauseActivityItem#execute() 执行完之后，会执行 postExecute()，就会 IPC 到 ATMS 里面通知 App1 完成了 pause 处理。

**2 . SystemService 继续 App2 Resume 处理：**
  **(1).** ATMS 收到 App1 的 completePause 之后，会继续调用 Part1 中的 RootActivityContainer#resumeFocusedStacksTopActivities()，这里就不会 Skip resume 了，因为已经没有需要 pause 的 ActivityRecord。

  **(2).** 可以看到这里就开始区分 冷/温/热启动 的3条分支路线了：
    (a). 首选 ActivityRecrod#attachedToProcess()：false 是 温/冷启动，true 是 热启动。attachedToProcess() 的判断代码是：

```
final class ActivityRecord {

    WindowProcessController app;      // if non-null, hosting application
    
	boolean attachedToProcess() {
        return hasProcess() && app.hasThread();
    }

    boolean hasProcess() {
        return app != null;
    }
}

public class WindowProcessController {
    
    // The actual proc...  may be null only if 'persistent' is true (in which case we are in the
    // process of launching the app)
    private IApplicationThread mThread;
    
    boolean hasThread() {
        return mThread != null;
    }
}
```

看注释就能知道，true 的条件是 **目标进程存在 并且 目标进程的 ActivityThread 绑定到 WMS 的 ActivityRecord 上了**。WindowProcessController 虽然不直接是 ProcessRecord，但从后面的代码能看到只有在创建进程对象的时候才会给 ActivityRecord 的 app 对象赋值的。而 IApplicationThread 则是 ActivityThread 里面一个内部类实现的，所以本质上 IApplicationThread 是 ActivityThread（应用） 在 SS(System Service) 这边的代理。如果是 热启动 分支的话，则是和 Part1 中类似，通过 ClientLifecycleManager 向 App2 发送 ResumeActivityItem 的请求。

​    (b). 如果 attachedToProcess() 是 false 的话，接下来又会继续分是 温启动 还是 冷启动，判断代码是：

```
void startSpecificActivityLocked(ActivityRecord r, boolean andResume, boolean checkConfig) {
    // Is this activity's application already running?
    final WindowProcessController wpc =
            mService.getProcessController(r.processName, r.info.applicationInfo.uid);

    if (wpc != null && wpc.hasThread()) {
        // warn launch ...
    } else {
        // cold launch ...
    }
}
```

这里看上去判断条件和上面的 ActivityRecrod#attachedToProcess() 一样。但是需要注意的是 ActivityRecrod 的 app 的值就是在 startSpecificActivityLocked() 函数的 温启动 流程赋的（可以看图中黑色加粗的地方）。所以上面热启动流程的进入条件可以升级为：**Activity 对象存在，才能进入到 热启动 流程**（温启动后面的流程是一定会创建 Activity 对象的）。温启动流程向 App2 发送的同时有 LaunchActivityItem 和 ResumeActivityItem。LaunchActivityItem 是设置 callback 的方式，而 ResumeActivityItem 则是和 热启动 一样，是设置 LifecycleState。简单来说，就是先执行 callback，再执行 LifecycleState（我们在 Part3 再来具体解释下这套 activity 生命周期机制）。

​    **(c).** 然后剩下冷启动的判断条件就很简单了：**目标进程不存在**，就进入 冷启动 流程。冷启动的话需要通过 local socket 和 zygote 通信，让 zygote fork 出新的进程，然后创建 Application 对象并初始化。然后再跑 温启动 那套启动 activity 的流程。**冷启动 相对 温启动 来说多了 fork 子进程和创建 Application 对象和初始化 的过程**。zygote socket 的通信协议可以看我以前写的一篇文章：[工作小笔记——Android 动态切换系统字体](http://light3moon.com/2015/01/31/工作小笔记——Android 动态切换系统字体/)（虽然以前那篇是 4.4 的，但是大体没什么大变化）。冷启动流程会创建 ProcessRecord，并且保存起来（后面判断进程是否存的逻辑也是基于这个）；并且注意 entryPoint 是 “android.app.ActivityThread”，这个类名就是 fork 出来的子进程要跑的 main 函数所在的地方（java 的函数入口也是 main 函数）。

## Part3. App2 Activity 生命周期处理

[点击这里看大图](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow_part3.png)
![activity start flow part3](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow_part3.png)

在分析这部分流程前，先介绍一下 ClientLifecycleManager 机制：

### ClientLifecycleManager 简介

先简单看下使用代码：

```
// Create activity launch transaction.
final ClientTransaction clientTransaction = ClientTransaction.obtain(
        proc.getThread(), r.appToken);

final DisplayContent dc = r.getDisplay().mDisplayContent;
clientTransaction.addCallback(LaunchActivityItem.obtain(new Intent(r.intent),
        System.identityHashCode(r), r.info,
        // TODO: Have this take the merged configuration instead of separate global
        // and override configs.
        mergedConfiguration.getGlobalConfiguration(),
        mergedConfiguration.getOverrideConfiguration(), r.compat,
        r.launchedFromPackage, task.voiceInteractor, proc.getReportedProcState(),
        r.icicle, r.persistentState, results, newIntents,
        dc.isNextTransitionForward(), proc.createProfilerInfoIfNeeded(),
                r.assistToken));

// Set desired final state.
final ActivityLifecycleItem lifecycleItem;
if (andResume) {
    lifecycleItem = ResumeActivityItem.obtain(dc.isNextTransitionForward());
} else {
    lifecycleItem = PauseActivityItem.obtain();
}
clientTransaction.setLifecycleStateRequest(lifecycleItem);

// Schedule transaction.
mService.getLifecycleManager().scheduleTransaction(clientTransaction);
```

1. 上面代码可以看到，先是创建 ClientTransaction，并且把 LaunchActivityItem 添加到 mActivityCallbacks，ResumeActivityItem 添加到 mLifecycleStateRequest。LaunchActivityItem 和 ResumeActivityItem 的继承关系是： extends ActivityLifecycleItem extends ClientTransactionItem implements Parcelable，ClientTransaction 也是实现了 Parcelable。也就是说 **SS 可以把 ClientTransaction 带上 mActivityCallbacks 和 mLifecycleStateRequest 通过 Binder 跨进程传递给 App**。如果对这块不熟的可以看我以前写的 Binder 相关文章：[Android Binder 分析——数据传递者（Parcel）](http://light3moon.com/2015/01/28/Android Binder 分析——数据传递者[Parcel]/) 。
2. 然后 scheduleTransaction 调用关系是： ClientLifecycleManager #scheduleTransaction() —> ClientTransaction#schedule() —> mClient.scheduleTransaction(this)。ClientTransaction 里的 mClient 就是 App 的 IApplicationThread 的 Bp 端；参数是 this 指针，把 ClientTransaction 自己传了过去，前面说了 ClientTransaction 带 mActivityCallbacks和 mLifecycleStateRequest 都可以 Binder 传递给 App。如果对 Bp、Bn 之类不清楚的，可以看我以前写的 Binder 相关文章：[Android Binder 分析——原理](http://light3moon.com/2015/01/28/Android Binder 分析——原理/) 。
3. 到了 App 这边，ActivityThread 里面 IApplicationThread#scheduleTransaction() —> ActivityThread#scheduleTransaction()。然而 ActivityThread#scheduleTransaction() 的实现是在 ActivityThread 的父类 ClientTransactionHandler 里面的：就是对 UIThread 发了个 EXECUTE_TRANSACTION 进行异步转发处理的。
4. ActivityThread 中的对 EXECUTE_TRANSACTION 的处理，是调用 TransactionExecutor#execute()：先会执行 executeCallbacks()：如果调用者设置了 callback，则会先后调用对应的 ActivityLifecycleItem（上面例子中的是 LaunchActivityItem）的 execute() 和 postExecute()；然后执行 executeLifecycleState()：如果调用者设置了 LifecycleState，会先调用 cycleToPath() 进行生命周期路径补全（下面具体说），然后先后调用对应的 ActivityLifecycleItem（上面例子中的是 ResumeActivityItem）的 execute() 和 postExecute() 。
5. cycleToPath() 会根据当前 Activity 的状态（Part2 中 App1 handlePauseActivity() 中把状态设置为 ON_PAUSE，设置的就是这个状态），以及目标状态计算出中间需要补全的状态，输出一个列表，把这个列表传递给 performLifecycleSequence() 循环执行列表中状态对应要进行的处理。计算的代码在 TransactionExecutorHelper#getLifecyclePath，感兴趣的可以自己看一下，基本上就是把官网那张 Activity 的生命周期的逻辑用代码实现了一次。例如说：温启动 设置了 callback 是 LaunchActivityItem，执行 callback 结束后当前状态是 ON_CREATE，然后 LifeCycleState 的目标状态是 ON_RESUME（ResumeActivityItem），那么计算中间的状态为 ON_START，需要执行 ON_START 对应的逻辑处理：mTransactionHandler.handleStartActivity() （ActivityThread 继承自 ClientTransactionHandler，所以本质 performLifecycleSequence 调用的逻辑处理函数就是子类 ActivityThread 的）。所以图中那个 “ON_CRATE —> ON_RESUME: ON_START” 的公式就是这么来的。类似的 热启动 只设置了 LifecycleState ResumeItemActivity，走 热启动 分支的，之前的 activity 是处于 ON_STOP 状态的，所以计算补全的状态路径为：”ON_STOP —> ON_RESUME: ON_RESTART, ON_START” 。

总结一下：这套机制可以让 SS 端自由的组合 activity 生命周期逻辑处理，让 App 端进行响应（当然得按设计的 activity 生命周期逻辑组合）。比以前直接在 SS 调用 IApplicationThread 暴露的接口设计上好了很多，而且能从代码上反映设计的逻辑（我记得 7.1 的时候还是没这套机制的）。不过最后我觉得让 TransactionExecutor 来调用处理路径状态的函数还是差点意思。另外注意一下，这里处理也是对 UIThread 发消息处理的（IApplicationThread 响应的 Binder 函数处理，是另外的线程来的，这块不清楚的可以看我以前写的 Binder 相关文章：[Android Binder 分析——多线程支持](http://light3moon.com/2015/01/28/Android Binder 分析——多线程支持/)），后面可以看到和界面相关的操作都是发消息给 UIThread 处理的。

### 流程分析

这一部分工作是 冷启动在 zygote 进程中 fork 出目标子进程，然后再在 App2 进程中创建 Application 对象并初始化。温/热启动 在 App2 进程中处理 LaunchActivityItem 和 ResumeActivityItem。

主要干的事情是：

**1 . Zygote 处理 fork 请求：**
  **(1).** fork() 是 unix 的一个系统函数，调用之后，返回值 >0 是父进程空间（这里就是 Zygote），=0 就是子进程空间（这里就是 App2 的进程），所以这里代码里面同一份代码会根据返回值不同进行不同的代码处理。Zygote 进程会把 App2 的 pid 通过 socket 发送给 SS 保存起来。
  **(2).** App2 进程空间会去找前面 entryPoint 的类中找 main 方法并调用 （就是执行了 ActivityThread#main()）。ActivityThread#main() 会创建 ActivityThread 对象，并且调用 ActivityThread#attach() 进行一些初始化：
    (a). 调用 AMS#attachApplication()，然后有 IApplicationThread 倒腾回 App2 进程向 UIThread 发送一个 BIND_APPLICATION 的消息。然而这个时候由于 ActivityThread 的 MessageQueue 的 Loop 并没有准备好，所有暂时无法处理。
    (b). 然后后面某个初始化流程的时候会调用 **WindowProcessController#setThread()**，这之后，前面调用过的 hasThread() 就能返回 true 了。所以 hasThread 表示 ActivityThread 已经初始化完了。
    (c). 调用 ATMS#attachApplication()，调用到 ActivityStackSupervisor#realStartActivityLocked()，后面的流程就和 温启动 的是一样的了。待 ATMS 和 AMS 的 attachApplication() 返回，ActivityThread#main() 就会 Looper.loop() 。这个时候，MessageQueue 就能处理消息了。至于 ActivityThread 的 main() 所在的线程为什么叫 UIThread，是因为 UI 的相关处理都是通过发送 msg 到这个消息队列的 Handler 处理的；那为什么 UIThread 叫 主线程，是因为它是跑在 main 函数里面的。
    (d). 这个时候上面发送的 BIND_APPLICATION 就能被处理了：会创建 Application 对象，如果你在 AndroidManifest.xml 有声明自定义的 Application 的 class name 的话，就会创建 manifest 声明的对象，如果没有的话，就创建 android.app.Application 这个默认的 class 的对象。之后调用我们应用开发熟悉的 **Application#onCreate()** 回调（所以这个回调是在主线程里面调用的）。

**2 . App2 处理 LaunchActivityItem 和 ResumeActivityItem 请求：**
  **(1).** 有了前面的 ClientLifecycleManager 机制的知识，就能很好理解 LaunchActivityItem 和 ResumeActivityItem 的执行过程了。**温/冷启动 需要经过 ON_CREATE —> ON_START —> ON_RESUME**；**热启动 需要经过 ON_RESTART —> ON_START —> ON_RESUME**。
  **(2).** Lifecycle 状态执行过程：
    (a). **ON_CREATE:** 这个过程会 **创建 Activity 对象**，class name 会从 Intent 中获取。attach() 的时候（初始化）会创建一个 PhoneWindow 对象（继承自 WIndow，PhoneWindow 代表手机上的一些窗口策略）。然后会调用我们应用开发熟悉的 **Activity#OnCreate** 回调。在这个回调中应用必须要调用 **setContentView** 给 activity 设置一个布局文件，如果不调用的话，会报错。setContentView 的本质是创建一个 DecorView（是一个 FrameLayout），这个是整个 activity（window） 的 根View。然后还会继续创建一个 mContentParent（也是一个 ViewGroup，根据 com.android.internal.R.content.xml 这个布局文件创建），mContentParent 会作为 childView 挂载到 DecorView 下面；而应用设置的布局文件创建出来的 View 会挂载到 mContentParent 下面。android 搞嵌套的目的是为了给应用添加一些系统视图组件，例如说 ActionBar 之类的（所以叫 DecorView，装饰用的么）。**这之后 activity 的状态会变成 ON_CREATE**。
    (b). **ON_RESTART:** 这个状态处理没什么特殊的，主要就是调用了应用的 **Activity#onRestart()** 回调而已。另外这个状态处理完之后，并没有把状态变成 ON_RESTART。
    (c). **ON_START:** 这个状态处理也没什么特殊的，主要就是调用了应用的 **Activity#onStart()** 回调而已。**这个状态处理完之后，状态变成 ON_START**。
    (d). **ON_RESUME:** 这个状态处理先调用了应用的 **Activity#onResme()** 回调。**这个状态处理完之后，状态变成 ON_RESUME**。 然后后面的处理就是绘制 activity 的第一帧图像，这个处理就比较复杂了，留到下一个部分单独说。

## Part4. App2 绘制第一帧——渲染初始化

[点击这里看大图](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow_part4.png)
![activity start flow part4](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow_part4.png)

在分析这部分流程前，先介绍一下 android 的窗口系统中的一些对应关系：

### android 窗口系统简介

![android window system](https://mingming-killer.github.io/img/pics/android/perf-activity-start/android_window_system.png)

不少人可能不是分得清楚 android 中 activity、window、view、surface 之间的对应关系。例如说一个 activity 是不是对应一个 window，一个 view 是不是一个 surface，surface 又是什么。首先官方有一些解释：[android_source: 图形框架介绍](https://source.android.com/devices/graphics?hl=zh-cn)， 但是这个有点偏向底层（因为是 source 的官网，不是 developer 的，面向的是系统开发者），上层的没怎么说。

我结合源码，根据官网以及一些网上的介绍，以及自己的开发经验，总结画出了上面的关系对应图，总结一下：

**App 端**：

1. **apk:** android 是一个多进程的操作系统，一个系统可以有多个 apk（进程） 运行（一个 apk 其实也可以有多个进程，这里不展开说了）。对应图中的 App1、App2。
2. **activity:** 一个 apk 里面有多个 activity。对应图中的 Activity1、Activity2。
3. **window:** 一个 activity 里面可以有多个 window，但是必须要有一个主窗口。图中这个 main window 不是官方的概念，是我的理解。例如说正常 startActivity 都会启动一个界面，这个就是 main window，一般 main window 都是全屏的，但是也可是悬浮的窗口。在代码里面一个 main window 对应的是 **PhoneWindow**，它是抽象类 Window 在手机上的策略的实现（以前还有 TabletWindow 的，但是现在好像没了）。**一般来说一个 activity 也就一个 PhoneWindow（main window 那个）**，但是如果你弹 Dialog 出来的话，**那么一个 Dialog 也包含了一个 PhoneWIndow**。所以**一个 activity 可以有多个 window**。
4. **DecorView:** 前面有介绍，它是顶层 View，是所有 View 的 Parent，是 andrid view 框架的起始部分。**一个 PhoneWindow 都有一个 DecorView**。但是 PopupMenu 比较特殊，它没有 PhoneWindow，取而代之的是自己的 PopupWindow，这个类没有继承 Window，而是自己实现了一些逻辑，在 PopupWindow 里面也有一个 DecorView（PopupDecorView 和 DecorView 是类似的功能）。
5. **ViewRootImp:** 看名字就知道 ViewRootImp 很重要，它有2个主要作用：**(1). 实现 android 的 View 系统的逻辑，发起布局、绘制等操作；(2). 连接 应用窗口 和 服务端 WMS 的桥梁**。它里面有一个内部类 H 实现了 IWindow 接口（Bn端）。对应就是 WMS 里面 WindowState 当中的 mClient（Bp端）。它是应用把自己的 Window 挂载到 WMS 的时候创建的，一个 Window 有一个 ViewRootImp，严格来说它不隶属于 DecorView，WindowMangerGlobal 保存着所有的 ViewRootImp，只不过 DecorView 也持有了 ViewRootImp ，而且会调用它的一些接口而已。
6. **Surface:** 熟悉 GUI 框架的应该对这个名词不陌生，在 android 里面 Surface 和其他 GUI 的类似，提供一块内存（Buffer）给应用绘制图像（为什么不叫画布，因为在 android 里面画布叫 Canvas，相比 Surface，Canvas 提供的是绘制图形的操作，例如说画线、画点），然后再把绘制好图像的 Buffer 发送给 SurfaceFlinger（SF） 进行合成显示。ViewRootImp 持有 Surface 的引用，Surface 是在 SF 端创建的，通过 Binder 传递给应用端（ViewRootImp）使用。所以说 ViewRootImp 可以发起绘制操作，因为它有 Surface。SurfaceControl 是对 Surface 的封装，提供一些访问 Surface 的操作。可以说**一个 ViewRootImp 对应一个 Surface**。
7. **BufferQueue:** 前面的官方里面有介绍这个，它提供一个生产者、消费者模型：生产者（**BufferQueueProducer**）生产图像，消费者（**BufferQueueConsumer**）消费图像。BufferQueue 提供一组 Buffer （三重缓冲）在这个模型里面流转：生产者需要绘制图像了就请求 Buffer（**dequeueBuffer**），拿到后绘制图像（生产图像），然后再把这块 Buffer 还给 BufferQueue（**queueBuffer**），BufferQueue 通知消费者有新图像 Buffer 来了，消费者就会取这块 Buffer（**acquireBuffer**）拿去使用（例如说 SF 做显示）。我们这里生产者就是 ViewRootImp，消费者是 SF 里面的 Layer。android 提供这套模型的目的是：生产者、消费者模型不仅仅只适用于系统图形系统，例如编解码也可以适用，例如说录像的时候，camera 是生产者，编码器就是消费者。这里细节挺复杂的，这里只是简单罗列一下原理，网上有不少分析的，这里提供一个参考：[Android 图形架构 之四——图形缓冲区的申请和消费流程及核心类](https://blog.csdn.net/xx326664162/article/details/109029695)。BufferQueue 的生产者，消费者的接口都是 Binder 接口，可以跨进程的。顺带说一句上面流转的 Buffer 都是用共享内存实现的，进程间来回传递的是文件句柄，不需要 copy 数据。**一个 Surface 会有一个 IGraphicBufferProducer 接口的引用（Bp端），和它对应的是 SF 里面 Layer 的 BufferQueueProducer（Bn端）**。BufferQueue 是 SF 里面的 Layer 创建的，传了一个 IGraphicBufferProducer 给 Surface，ViewRootImp 通过 Surface 访问 IGraphicBufferProducer 接口就可以申请绘制需要的 buffer，和把 buffer 送给显示。
8. **View:** View 可以是 android GUI 的基本元素单位，它是有层级的，层层嵌套组成图形界面。前面说了 DecorView 是顶级 View，应用创建的 View 都是挂载在 DecorView 下面的（其实是 DecorView 下面的某个View）。也就是说**一个 DecorView 可以对应多个 View**。但是前面说了送给显示的是 ViewRootImp 下面的 Surface，View 绘制的 Buffer 是什么呢？ 有2个选择，可以使用 ViewRootImp 的 Surface 的 Buffer，这个是 View 的常规操作，每个 View 会被限制在自己的区域内绘制（measure 的时候确定的 View 大小），影响不到其他 View（因为大家用的都是同一块 Buffer）。也可以单独给 View 创建 Buffer 使用，最后 ViewRootImp 绘制操作的时候，会把所有 View 单独创建的 Buffer draw 到 Surface 的 Buffer 上（这个有点像 SF Layer 的合成操作）。然后再把 Buffer 送给 SF 合成显示。这里涉及到 android 的 View 系统，里面也是细节也是挺复杂的（和上面的图形系统都是 android 的几个核心框架），这里也是简单罗列一下原理，具体的实现可以网上找找。
9. **WindowManagerGlobal:** 这是一个单例模式，也就是说一个进程就只有一个。里面有一个 **WindowSession，也是单例的**，这个 WindowSession 是应用连接 WMS 的接口，通过这个接口可以访问到 WMS （这个接口主要是对内的，对外的是 WindowManager）。 对应 WMS 中有一个数组 mSessions，保存了所有客户端的 WindowSession 连接（应用端的 Session 是 Bp端，WMS 里面的是 Bn端）。本进程中所有 ViewRootImp 使用的 WindowSession 都是 WindowManagerGlobal 里面这个。
10. **SurfaceView:** 前面介绍的，一个 PhoneWindow 有一个 DecorView，一个 DecorView 有一个 ViewRootImp，一个 ViewRootImp 有一个 Surface（适用于 activity 的 main window、Dialog、PopupMenu）。但是看图会发现有一个特殊，那就是 SurfaceView。SurfaceView 没有 PhoneWindow，也没有 ViewRootImp， 甚至都没有使用全局的 sWindowSession。它是自己直接打开了和 SF 的连接创建了自己的 SurfaceSession（后面会介绍，WindowSession 会创建 SurfaceSession 连接 SF），然后通过 SurfaceSession 创建了自己的 Surface。所以官方说 SurfaceView 可以用单独的线程渲染，因为它基本脱离了 android 的 View 系统，给应用提供了可以绘制的 Buffer（有自己的 Surface 就可以 dequeue/queueBuffer），让应用自由发挥。而其他的 View 的绘制必须在主线程（也就是前面提到的 UIThread），因为后面会介绍 ViewRootImpl 的绘制操作是在 UIThread 发起的，而所有的 ChildView 的绘制都是在 ViewRootImp 的绘制中调用的。上面之所以说 SurfaceView 没有完全脱离 android View 的系统，是因为虽然绘制可以应用自己操控，但是 SurfaceView 还是受到 View 的区域大小限制（创建的 Surface 大小是 SurfaceView 区域的大小），而且 SurfaceView 也是挂载在 View tree 上的。

**WindowManagerService 端**：

1. **WindowSession:** 前面已经说过这个是对应用的 IWindowSession，普通 Window 用的是进程全局的 WindowSession，也就是**一个 Apk 一个 WindowSession**（这里假设 Apk 是单进程的）。 WMS 里面的 WindowSession 会去打开和 SF 的连接，创建一个 SurfaceSession，而一个 SurfaceSession 包含了一个 SurfaceComposerClient。SurfaceComposerClient 是 libgui 的一个 native 接口，SF 的 Client 类实现了这个接口。一个 SurfaceComposerClient 对应 SF 里面一个 Client 实例。在我们启动流程分析里面，这个 Client 主要是提供创建 Surface 的接口。前面说 SurfaceView 有自己的 SufraceSession，就是有自己的 SurfaceComposerClient，所以它可以创建自己的 Surface。
2. **WindowState:** 可以说**应用端一个 Window 在 WMS 就对应一个 WindowState**。在 WindowState 中主要有一个 mClient，对应是应用端 ViewRootImp 的内部类 H（IWindow）。然后 SurfaceControl 是在创建 Surface 的时候，WMS 这边也存了一个 SurfaceControl，后续一些功能会需要操作到。这个 SurfaceControl 和应用端的 SurfaceControl 是对应的。

**SurfaceFlinger 端**：

1. **Client：** 前面有介绍，这个就是和 SurfaceComposeClient 一一对应的（上层必须会有 SurfaceSession）。因为应用普通 Window 的 WindowSession 是全局的，也就导致了没有 SurfaceView 的应用就只有 一个 SurfaceSession，所以**一个 SurfaceSession 可以创建多个 Surface**。
2. **Layer:** 这个是 SF 中的基本单位，应用端（WMS 端）通过 SurfaceComposeClient（SurfaceSessison）调用创建 Surface 的接口，在 SF 里面本质是创建一个 Layer。一个 Layer 会创建一个 BufferQueue（BufferQueueCore），一个 BufferQueue 会有一个 BufferQueueProducer 和 BufferQueueConsumer。然后返回的时候会把 BufferQueueProducer 返回回去（BufferQueueProducer 是可以 Binder 传递的，反而 Surface 不行）。然后应用这边再通过 BufferQueueProducer 重新 new 了一个 Surface。所以 Surface 其实只是一个壳，Surface 提供 Buffer 的功能本质是上 BufferQueueProducer 提供的。SF 合成的时候，会遍历每个 Layer，能用 HWC 合成的（这个策略由具体的硬件决定，例如说某些硬件不支持合成带 aphla 的 Layer；或者是某些场景下 Layer 数量超过 HWC 支持的数量了；或者上层强制标记为 GPU 合成了，Settings 的开发者选项”强制GPU合成”，就是把所有 Layer 标记为 GPU 合成），就跳过，否则就标记为需要 GPU 合成；然后把需要 GPU 合成的 Layer 全部用 OpenGL draw 到另外一个单独的 Layer 上，最后把这个绘制好的 Layer 送给 HWC。所以 GPU 合成（在 SF 代码里面叫 Client 方式）是指用 OpenGL（GPU）把 Layer 绘制（混合）到一个单独的 Layer，再把这个 Layer 送给 HWC。而 HWC 合成是指省去了 SF 用 OpenGL 混合 Layer 的过程，直接把 Layer 送给 HWC，由 HWC 混合显示到屏幕上。所以每一帧显示，如果是 GPU 合成的话，需要额外的 GPU 运算能力，同时增加 ddr 带宽访问量（每个 Layer 需要一次 读+写 Layer Buffer 的 ddr 数据量）；导致功耗上升和 ddr 带宽需求上升。所以一些需要用到 GPU 合成的场景可能就会引发性能问题。

经过上面的解说，我们可以再精简总结一下：

1. 一个 activity 可以有多个 window
2. 一个 window 对应一个 DecorView，一个 DecorView 下面可以挂载多个 View；一个 window 对应一个 ViewRootImpl，一个 ViewRootImp 对应一个 Surface。一个 window 对应一个 WindowState。
3. 一个 Surface 对应一个 Layer；一个 Layer 对应一个 BufferQueue

可以用 dumpsys surfaceflinger 看当前 Layer 的情况，用 dumpsys window windows 看当前 WindowState 的情况（dumpsys 会打印 SS 一些内部状态，我以前写过一篇文档介绍这个小工具：[Android 一些有意思的命令小工具 —— dumpsys](http://light3moon.com/2015/01/30/Android 一些有意思的命令小工具 —— dumpsys "Android 一些有意思的命令小工具 —— dumpsys)）。大多数时候 WMS 里面 WindowState 数量是比 SF 的 Layer 多的，那是因为有很多 Window 是隐藏的，只有显示的 Window（isVisible=true）才有 Surface，在 SF 那才有 Layer。

上面介绍的 BufferQueue 和 Layer 的合成官方也有几张图解释：

BufferQueue 的生产者、消费者模型：
![bufferqueue](https://mingming-killer.github.io/img/pics/android/perf-activity-start/aosp_bufferqueue.png)

Layer 的合成（图中的例子就是 GPU + HWC 合成：其中的 status_bar、system_bar 是 GPU 合成成一个单独的 Layer，然后再和 background、icons/widgets 的 Layer 一起送 HWC 合成）:
![graphcis pipeline](https://mingming-killer.github.io/img/pics/android/perf-activity-start/aosp_graphics_pipeline.png)

为什么要花这么多篇幅介绍 android 的窗口系统呢，因为 activity 启动流程 涉及到了第一帧的绘制，如果你不清楚 android 的窗口系统以及 view 系统，可能就会在这个过程中卡壳。所以现在我们接着看启动流程：

### 流程分析

这一部分其实包含在 Resume 流程里面的，因为涉及到了图形系统，也是启动流程里面最复杂的一个流程，所以我拆分了几个部分说明。这部分说的是绘制前的准备工作，主要是： 初始化 ViewRootImp、 初始化渲染线程、请求布局、创建 SurfaceSession 连接、发送 idle。

主要干的事情是：

**1 . 创建 ViewRootImp：**
  **(1).** 内部调用的 WindowManager 其实是上面介绍的 WindowManagerGlobal，addView 添加的 View 是 PhoneWindow 的 DecorView，一般添加的都是这个 Window 的顶层 View。这里还没那快正真的向 WMS 添加 View。
  **(2).** 调用 addView 会创建一个 ViewRootImp （所以 addView 不能多次调用，因为 ViewRootImp 不能有多个）。然后会调用 ViewRootImp#setView() 来初始化。

**2. 创建渲染线程：**
  **(1).** 这里简单介绍一下渲染线程（RenderThread）是什么。官方介绍：[android_developer: 硬件加速](https://developer.android.com/guide/topics/graphics/hardware-accel)。从 4.4 开始 android 在图形系统里面加入了硬件加速功能，就是使用 OpenGL（现在支持 Vulka 了）绘制界面。开启了硬件加速，会额外创建一个线程进行 OpenGL 的绘制操作（这个线程就是 GL 上下文线程，OpenGL 是单线程的，所有的 GL 操作必须要在 GL 上下文线程进行）（ps -T pid 可以看到应用进程中这个 RenderThread 的线程，抓 systrace 也能看到）。在 UI线程 中执行的 View#onDraw() 中的各种绘图指令，并不会真正执行图形绘制命令，而是记录到 DisplayList 中；然后在渲染线程里面再统一执行 DisplayList 里面的绘制命令（就是 OpenGL 指令），渲染到 Surface 上。这样 UI线程 的响应速度就快了很多（只是记录绘制命令而已），也充分利用了现代多核 cpu 的多线程能力，而且 渲染线程 批量处理渲染指令还能进行优化。相比硬件渲染通路，软件渲染通路则是直接在 UI线程 执行 View#onDraw() 中的绘图指令，就是 skia api，而且是使用 CPU 执行的。所以开启了硬件加速，View 的一个遍历绘制周期耗费的时间会大大减少，基本上可以满足 16ms 的要求，所以会流畅很多（但是硬件加速会额外占用一些内存）。这里面细节同样也是挺复杂的，网上这篇分析得不错：[Android 重学系列 View的绘制流程(六) 硬件渲染(上)](https://yjy239.github.io/2020/06/30/android-chong-xue-xi-lie-view-de-hui-zhi-liu-cheng-liu-ying-jian-xuan-ran-shang/)，另外 OpenGL 其实也有点门槛，可以看看我写的入门文章：[OpenGLES 入门学习](http://light3moon.com/2019/12/30/OpenGLES 入门学习)。**硬件加速是有一个开关的，AndroidMainfest.xml 的 Application 字段可以配置，如果不配置的话，在 4.4 以上的版本默认是开启的**：

```
// PackageParser#parseBaseApplication()
owner.baseHardwareAccelerated = sa.getBoolean(
        com.android.internal.R.styleable.AndroidManifestApplication_hardwareAccelerated,
                owner.applicationInfo.targetSdkVersion >= Build.VERSION_CODES.ICE_CREAM_SANDWICH);
        if (owner.baseHardwareAccelerated) {
            ai.flags |= ApplicationInfo.FLAG_HARDWARE_ACCELERATED;
        }
```

另外这里配置的是全局硬件加速的开关，View 还有单独的硬件加速的开关（setLayerType），这个可以单独配置 View 的硬件加速。而且 View 的 Layer Type 和全局的硬件加速渲染是有区别的，不是一回事。一个是可以看官方的介绍：[android_developer: 硬件加速#视图层](https://developer.android.com/guide/topics/graphics/hardware-accel#layers)，另外一个可以看这篇文章：[硬件加速与软件加速](https://androidperformance.com/2019/07/27/Android-Hardware-Layer/)：

- **LAYER_TYPE_NOE:** 默认模式，View 没有离屏buffer，根据全局渲染模式，选择走硬件渲染通路还是软件渲染通路。
- **LAYER_TYPE_HARDWARE:** View 有离屏buffer（应该最后硬件渲染管线会把这个离屏buffer贴到 Surface 的 Buffer 上）。必须开启全局硬件加速才有效，否则就是和 LAYER_TYPE_SOFTWARE 一样。离屏buffer 是 OpenGL 的 纹理（Texture）。适用于加速 alpha\translation\scale\rotation\pivot 等属性动画（具体用法见官方说明），但是注意不要用在动画过程中 View 有更新的情况（触发 invalidate），这会频繁导致纹理缓存无效（离屏buffer无效），需要重新 upload 新的纹理，这个操作是很耗时的。推荐的文章里有反例。还能通过 Paint 很方便的实现一些视觉图像效果。
- **LAYER_TYPE_SOFTWARE:** View 有离屏buffer（应该最后硬件渲染管线会把这个离屏buffer贴到 Surface 的 Buffer 上）。即便是开了全局加速，依赖可以把某个 View 的 Layer Type 设成 Software 的。离屏的buffer 是 Bitmap。TYPE_SOFTWARE 的作用除了 HARDWARE 的那2个以外，还有一个重要的作用：当遇到硬件渲染不支持的 skia 绘图 api 的时候（具体的可以看官方硬件加速介绍里面，有张表的；但是某些低端芯片平台的 GPU 可能会有更多不支持的绘制 api），可以单独设置 View 的 LAYER_TYPE，避免 View 变成黑色（OpenGL 一般遇到不支持的操作就是黑色色块）。

  **(2).** 这里我们参照默认的开启硬件加速流程，会创建 RenderThread。这是一个 native 的 thread（java 是代理马甲），**而且也是一个单例模式，也就是说整个 App 进程空间只有一个 RenderThread**。简单介绍一下 native RenderThread 的结构：RenderThread 也是用消息队列的，线程跑起来后，线程函数一个循环阻塞在等消息发送过来（android 上很多都是这个模型）。DrawFrameTask 是处理绘制任务请求的（在 RenderThread 里面执行任务）。CanvasContext 和应用层的 Canvas 类似。SkiaOpenGLPipeline 是用 OpenGL 实现绘制命令。RenderProxy 是对接上层的调用接口。另外说一下代码是支持了 Vulka 了的（有一个 Vulka 实现的 Pipeline 的），因为我工作的平台还是用 OpenGL 的，所以这些用 SkiaOpenGLPipeline 分析。

**3 . 请求布局：**
  ViewRootImp 创建完了渲染线程之后，会请求一次布局（requestLayout）。其实代码知道请求布局，实际上就是遍历整个 View tree 的操作。但是这里注意，它只是对 Choreographer post 了一个回调就返回了。这个回调最后的执行还是发送到 UIThread 里面处理的（Choreographer 我们后面再介绍）。我们前面知道 handleResume 其实也是在 UIThread 的 msg handle 里面处理的，所以这个 遍历请求 一定是会在处理完这次 handleResume 操作之后才会执行的（至于为什么强调这点，看后面就知道了）。

**4. 创建 SurfaceSession 连接：**
  **(1).** 直到这里才调用 WindowSession 接口去添加 Window。而且注意一下 android 的”偷换概念”：前面是 addView(DecorView)，但是这里却是 addWindow(mWindow)（mWindow 是前面介绍的 ViewRootImp 里面的内部类 H）。**所以对于 WMS 来说，最基本的单位是 window，View 只是应用端的概念**（应用把所有 View 的图像”合成”到 Window 的 Surface 上）。然后这里 WMS 去连 SF 创建一个 SurfaceSesion（SurfaceComposeClient），这个 SurfaceSession 就保存在 WindowSession 中。其实可以看到所谓的addWindow 只不过是在 WMS 里保存了一个 Client 接口而已。

**6. 发送 idle 消息：**
  在 UIThread 的 idle handlers 里面添加 ActivitThread 的 Idler。简单的说就是在 UIThread 空闲的时候（没有消息需要处理的时候：1. 消息队列为空，2. 或者要处理的消息还没到达指定时间），会执行这段代码。这个和 App1 的 Stop 处理有关，后面再说。

## Part5. App2 绘制第一帧——渲染

[点击这里看大图](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow_part5.png)
![activity start flow part5](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow_part5.png)

在分析这部分流程前，先介绍一下 android 图形系统里面另外一个很重要的概念：

### Vysnc 简介

Vysnc 的细节也是挺复杂的，同样这里只是罗列一下，具体的分析可以看这篇：[Android 重学系列 Vsync同步信号原理](https://yjy239.github.io/2020/02/25/android-chong-xue-xi-lie-vsync-tong-bu-xin-hao-yuan-li/) 。

1. LCD 的屏幕刷新是需要一段时间来一行一行扫描的更新的。在扫描的过程不能对屏幕 Buffer 区域进行更新，否则屏幕显示就会出现异常。很好理解，因为 LCD 正在拿 Buffer 里面的像素点在刷新，这个时候如果 Buffer 里面的像素点被改了，那么前面刷新的图像和后半截就不是一帧图像了，这个就是我们常说的图像撕裂。为了避免这个问题，就需要在 LCD 扫描刷新的间隔内完成图像更新。那也就是说，在这个时间段内，需要完成 应用界面绘制 + SF 合成送显。这个时间间隔就叫 Vysnc（垂直同步，因为早期 LCD 刷新是竖直扫描的）。一般 LCD 是 60Hz 的刷新率，也就是 1s 刷新60次，那么 Vysnc 间隔就是 16.6ms，这也就是网上常说的应用渲染速度要小于 16.6ms 的原因（当然现在有 90Hz，120Hz 的屏幕出现了）。
2. 如果系统渲染图像按照 Vysnc 节奏进行，就引出一个问题：如果渲染速度够快，就没问题，如果渲染时间超过 16.6ms ，那么这次的帧就不能更新到屏幕上了，系统只能等下一个 Vysnc 再投递给 LCD 显示，这个时候应用其实就闲置了。如果下一帧渲染还是超过 16.6ms，那么又有一帧显示不了。如果一直这样，那么其实变相于显示帧率就低了一半。如果没按照 Vysnc 节奏的话，显示帧率不会低一半（只是时高时低不稳定而已）。为了缓解这个问题，android 就引入了 三重缓冲（Triple Buffer，就是前面介绍 BufferQueue 的那一组 Buffer 的个数）。目的是一个 BufferQueue 有 3个 Buffer 的话，应用绘制完一帧，可以把用完的 Buffer 存在 BufferQueue 里面，系统再到 BufferQueue 里面拿 Buffer 显示。在这个模型下，刚刚那种情况，应用没来得及绘制，在第二帧的时间段画完第一帧后就给 BufferQueue 缓存，然后应用可以继续从 BufferQueue 里面拿另外一个 Buffer 接着画第二帧，而不必等第一帧送出去显示了，第二帧画完了同样放回 BufferQueue 缓存。如果当第三帧应用还没得来画完，那么系统还可以从 BufferQueue 里面拿缓存的第二帧送显。所以可以看得出来有了三重缓冲，能有效降低丢帧概率（注意只是降低，并不是消除）。但是由于缓存队列的存在，当前应用渲染的帧，会等到下一个 Vysnc 或是下2个 Vysnc 才能被 SF 送去显示，会造成一定的显示延迟。这个问题在普通的 android 应用场景没关系，但是在某些要求低延迟的场景就不行了。例如说 VR，所以 VR 又弄了一个 SingleRender（又叫 FrontRender，翻译成直接渲染） 的概念，其实就是把三重缓冲去掉了，只用一个 Buffer 渲染。但是这个对性能要求极高，必须要在 Vysnc 周期完成 应用渲染 + SF 合成送帧（不过 VR 一般都玩 ATW，这里就不展开说了）。上面说的缓存以及丢帧可以结合官方给出的图理解一下：

![vysnc jank 1](https://mingming-killer.github.io/img/pics/android/perf-activity-start/aosp_vysnc_jank1.png)
![vysnc jank 2](https://mingming-killer.github.io/img/pics/android/perf-activity-start/aosp_vysnc_jank2.png)

如果看官方的图还不理解的话，可以看看这篇文章，三重缓冲解释得很到位：[Android Systrace 基础知识 - Triple Buffer 解读](https://androidperformance.com/2019/12/15/Android-Systrace-Triple-Buffer/)。其实 Vsync 爷不是啥新鲜东西，很早在 PC 上就有了，很有 PC 游戏用这个，只不过从 4.0 开始 google 把它搬到 android 上了。以前我转了一篇老外从游戏的就角度说 Vysnc：[[转\] 什么是 VSync](http://light3moon.com/2015/01/31/[转] 什么是 VSync)。

介绍 Vsync，是因为我们现在要绘制的第一帧，是要按照 Vsync 的节奏来启动绘制的。如果你不清楚的话，可能会不理解代码上的某些操作。所以现在我们接着看启动流程：

### 流程分析

在前面创建的 SurfaceSession 的连接之后，接下来主要是： 请求 Vsync、ViewRootImp 遍历操作（measure、layout、draw）、发送第一帧绘制完成通知。

主要干的事情是：

**1 . 请求 Vsync：**
  **(1).** 上一部分说 ViewRootImp 是把请求布局的回调 post 到了 Choreographer 。简单说一下 Choreographer ：前面有介绍 Vsync 说，应用要按照 Vsync 的节奏来绘制图像。那么怎么按按照节奏呢？其实就是接收到 Vsync 的回调，触发绘制操作就可以了。Choreographer 就是干这个事的。android 里面的 Vsync 是 SF 的一个线程产生的。对，你没看错，它是软件产生的（软件 Vsync 有它的好处，我推荐的文章里有介绍），只不过它会定时和硬件 Vysnc 同步时间差而已。看我图上紫色的部分，SF 初始化的时候会创建 2个 EventThread 来产生**2个 Vsync 信号，一个是 Vsync-sf: 给 SF 给 HWC 送显用的；一个是 Vsync-app: 给应用渲染界面用的**。而给 Choreographer post 回调，就会打开 Vsync-app 信号，并且 Choreographer 会注册 Vsync-app 的回调函数。

  **(2).** **当到达下一个 Vysnc 周期后，Choreographer 的 onVsync 回调被触发**，它会对 UIThread 发送一个消息来处理。**所以从这里可以看到为什么叫 UIThread，因为所有的 UI 都是发送到这个线程来处理的**。这个消息处理就会最后会调用到 ViewRootImp 的遍历操作。

**2 . ViewRootImp 遍历操作：**
  **(1).** 在进行 View 的遍历操作前，会调用 WMS 的 relayoutWindow 操作。这个是根据 Window 的大小，检测 Surface 是否需要重新创建。第一次是肯定需要创建的（如果 Window 大小变了，也会重新创建）。这里可以看到因为应用的 SurfaceSession 是在 WMS 这边的，所以 Surface 创建只能在 WMS 这边发起（和 SurfaceView 的对比）。根据前面的介绍，最后在 SF 那边是创建了一个 Layer（Layer 创建 BufferQueue）。Android 10 SF 里面分了好几种 Layer，普通的 Window 的是 BufferQueueLayer。从图中可以看到其实最关键的 Binder 传递是 BufferQueueProducer，让应用端能通过 Surface 申请到绘制用的 Buffer。

  **(2).** ViewRootImp 拿到 Surface 后，让渲染线程根据 Surface 创建了一个 EglSurface。至于 Egl 和 OpenGL 的区别，网上也能搜得到。简单来说 Egl 是本地窗口系统的一个接口（在 android 上是芯片厂实现的），负责给 OpenGL 提供 Buffer 的，有了 Buffer OpenGL 才能渲染。

  **(3).** 接下就是遍历执行 Measure 和 Layout 操作，对应的会调用到 View onMeasure 和 onLayout 方法。这个又涉及到 android 的 View 系统，细说也能说很多，网上也有分析说明，可以看看官网的说明：[android_developer: 自定义视图组件](https://developer.android.com/guide/topics/ui/custom-components)。这里也是简单介绍一下（我图上也是省略没画具体流程了）：measure 的作用是确定 View 的大小。例如 View 的 width、height（确定大小有一定的策略的，需要 View 自己实现，例如说 MATCH_PARENT, WRAP_CONTENT，这里不细说了）。layout 的作用是确定 view 里面元素的布局。例如说一个 LinearLayout 里面的 ChildView 是横着摆，还是竖着摆。当然这个只是文档规定，在自定义 View 里面你也可以在 onMeasure 里面把 onLayout 的事也干了；甚至你在 onDraw 里面干 onLayout 的事都是可以的。当然这个是可以，但是一个是不规范，另外一个是性能不好（特别是在 onDraw 里面干 onLayout 的事）。sdk 自带的 View 的实现都是规范的。以前写应用的时候记过一次笔记：[Android 布局笔记](http://light3moon.com/2015/01/25/Android 布局笔记) 。

  **(4).** Measure 和 Layout 操作完成之后，就是 draw 绘制操作了。在开始 draw 之前，ViewRootImpl 向 RenderThread 设置了一个 FrameCompleteCallback 。

  **(5).** 接下来的应用的 draw 操作也是被我省略了的，一个是网上有分析，另外一个，硬件渲染引擎这块我还不是特别熟，就先跳过了。但是这里会调用到 View 的 onDraw 函数，这个函数里面不同的 View 就开始绘制各自的内容了。

  **(6).** 应用的 View 渲染完之后，ViewRootImpl 会对 RenderThread post 一个 DrawFrameTask，但是这里是同步的，虽然对线程 post，但是等待信号。DrawFrameTask 回调用 CanvasContext#draw(): (1). 通过 SkiaOpenGLPipeline dequeueBuffer 获取到 Buffer（这个 buffer 是在 SF 通过 Gralloc 申请的，Gralloc 是一个 hal（Graphic Allocator），是芯片原厂实现 ion 内存分配的，这个网上也能查得到，也可以看看官网的简单介绍：[android_source: BufferQueue 和 Gralloc](https://source.android.com/devices/graphics/arch-bq-gralloc)。BufferQueue 也不是每次 dequeuBuffer 都是 Gralloc 申请，只有第一次会，后面 queueBuffer 还回来后就入队列缓存了）；(2). SkiaOpenGLPipe#draw() 执行 OpenGL指令绘制；(3). 执行 queueBuffer 把绘制好的 Buffer 送给 SF（Layer 的 BufferQueueProcedure 的 Bn 端）。这里 queueBuffer 其实还触发了 SF 的合成机制的，这个下一个部分再说。 **queueBuffer 后，SF 并不是合成完之后才返回的，而且开启了 Vsync-sf 信号后就返回了**。另外 SF BufferQueue 申请的 Gralloc 内存可以用 dumpsys SurfaceFlinger 看到，具体的可以看我以前写的文章： [Android 内存优化方法#ion](http://light3moon.com/2020/12/07/Android 内存优化方法/#ion)。

  **(7).** **queueBuffer 返回之后，就会调用第一帧绘制完成的回调**。这个就是下一个部分的内容了。

### 补充

上面的流程图，ViewRootImpl 在第一绘制执行 performTraversals 的时候，有些应用其实是分2次 performTraversals 执行的：第一次做 performMeause 和 performLayout，第二次才是 performDraw。我为了简化合并在一次画了。而且第二次 performTraversals 的请求也是 post 给 Choreographer 的，也就是说**第二次 performTraversals 也是需要等 Vysnc 信号到来的**。而有些应用就一次 performTraversals 就跑完了 measure、layout、draw 流程，一次 traversals 就把第一帧画出来了（我图上画的是一次跑完的）。主要的区别在于 performTraversals 中的这个判断：

```
boolean cancelDraw = mAttachInfo.mTreeObserver.dispatchOnPreDraw() || !isViewVisible;

if (!cancelDraw) {
    if (mPendingTransitions != null && mPendingTransitions.size() > 0) {
        for (int i = 0; i < mPendingTransitions.size(); ++i) {
            mPendingTransitions.get(i).startChangingAnimations();
        }
        mPendingTransitions.clear();
    }

    performDraw();
} else {
    if (isViewVisible) {
        // Try again
        scheduleTraversals();
    } else if (mPendingTransitions != null && mPendingTransitions.size() > 0) {
        for (int i = 0; i < mPendingTransitions.size(); ++i) {
            mPendingTransitions.get(i).endChangingAnimations();
        }
        mPendingTransitions.clear();
    }
}
```

ViewTreeObserver#dispatchOnPreDraw() 就是遍历应用中注册了 OnPreDrawListener 监听的回调，只要有一个监听在 onPreDraw() 中返回 false 就需要第二次 performTraversals 遍历。这个就完全是应用决定的了（当然也有一些是 androidx 组件决定的）。例如说 AOSP 里面 Settings 就是遍历1次的，而 Calculator 就是遍历2次的。抓 systrace 可以看得出来（第一张 Calculator ，第二张 Settings）：

![first performTraversals](https://mingming-killer.github.io/img/pics/android/perf-activity-start/first_performTraversals1.png)
![first performTraversals](https://mingming-killer.github.io/img/pics/android/perf-activity-start/first_performTraversals2.png)

## Part6. App2 绘制第一帧——Buffer 投递 SF

[点击这里看大图](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow_part6.png)
![activity start flow part6](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow_part6.png)

这部分为2部分：应用渲染线程把绘制好的 Buffer queueBuffer 给 SF；SF 更新图层，并合成送显：

**1 . RenderThread queueBuffer：**这个部分 Part6 有提到过，这里稍微把 SF 这边的流程再具体一下：
  (1). 渲染线程通过 mGraphicBufferProducer#queueBuffer()：—> SF 这边的 Bn（BufferQueueLayer） 会收到一个 onFrameAvailable() 的回调（onFrameAvailable 是 GraphicBufferConsumer 的回调，BufferQueueLayer 实现了这个回调）：—> 回调里面会去调用 SurfaceFlinger#signalLayerUpdate()：—> 里面最后会去调用 EventThread#requestNextVsync() 开启 Vysnc-sf 信号。 前面介绍过了，Vysnc 信号分2个，Vysnc-sf 是给 SF 刷新、合成用的，这里就能体现出来了。还有注意一点：**这里请求 Vysnc 信号后，queueBuffer 函数调用就返回了，也就是说这个时间点，就能触发应用那边的 FrameComplete 的回调了**。
  (2). Vysnc-sf 触发的回调是： MessageQueue#eventReceiver()：—> 里面会对 SurfaceFlinger 的主线程发一个 INVALIDATE 的消息。然后下面的处理，其实和 activity 启动流程是并行的，因为前面说过了，queueBuffer 已经返回了。但是经过下面的步骤才能让图像显示到 LCD 上，让用户看到，所以我们还是简单介绍一下。

**2 . SurfaceFlinger 刷新、合成、送显：**
  (1). SF#handleMessageInvalidate()：—> 主要更新操作是在 handlePageFlip()： —> 会循环遍历每一个 Layer，挨个调用 latchBuffer()：—> 检测是否需要更新，如果需要就调用 updateTexImage()： —> 这个函数很关键，它会去调用 **mConusmer->acquireBuffer() 获取 应用渲染线程 queueBuffer 过来的 Buffer**，然后更新到 Layer 的纹理上。每个 Layer 都更新完后，调用 SF#signalRefresh()：—> 对 SF 主线程发一个 REFRESH 消息。
  (2). SF#handleMessageRefresh()：—> doComposeSurfaces(): —> 前面介绍的根据一定策略，把需要 GPU 合成的 Layer 挨个画到另外一个 Layer（就是下面的 FrameBuffer） 上去（这里不具体介绍策略了）。然后调用 SF#postFrameBuffer()，如果有 GPU 合成就把 FrameBuffer（专门用来合成的 Layer Buffer）送给 HWC。最后的 SF#postComposition() 使用完了 Buffer，调用 **releasePendingBuffer()** 把 Buffer 重新放回 BufferQueue。

这里 SF 就把新的一帧送给 HWC 了，当然了 HWC 更新到 LCD 上面也是有一定时序的，但是这里我们就默认已经更新到 LCD 上了。到目前为止，我们能发现：

1. **触发 FrameComplete 的回调的时候，LCD 上并没有显示最新的一帧，只是应用把新的一帧送到了 SF 而已**。
2. 从上面的流程可以大致体会到 BufferQueue 的流转机制：app RenderThread dequeueBuffer —> app RenderThread draw —> app RenderThread queueBuffer —> SF acquireBuffer updateTexImage & compose —> SF reeaseBuffer。
3. 整个图像绘制流程，系统添加了很多 systrace，我在图中标了一些关键的出来，后续抓 systrace 的时候，可以参照一下看看 trace 对应的是哪一截函数路径。

## Part7. App2 绘制第一帧——绘制完成回调

[点击这里看大图](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow_part7.png)
![activity start flow part7](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow_part7.png)

这部分就是前面介绍的 ViewRootImpl 里面响应 RenderThread FrameComplete 回调的处理：我们主要关心的就是 启动信息的统计 和 通知等待 WaitResult。

**1 . 统计启动信息**

ViewRootImpl 里面的回调是对 UIThread post 了一个 lamba 表达式（这个东西的介绍网上有很多），实质上就是在 UIThread 跑了一段代码，调用了 ViewRootImp#reportDrawFinished()。最重要的就是：**获取当前的时间**，传递给了 ActivityMetricsLogger#notifyWindowsDrawn()。前面介绍我们知道在最开始的 startActivityMayWait 的地方就是通知了标记了一次时间。那么我们现在来看看能统计了哪些信息：

  (1). **windowsDrawnDelayMs:** 这个时间是：当前时间（reportDrawFinished 传进来的）- mCurrentTransisitonStartTime（这个就是 startActivityMayWait 最开始调用 notifyActivityLaunching 记录的时间），单位是 ms。这个也就是后面的 TotalTime。

  (2). **type:** 这个是本次的启动类型，判断代码如下：

```
private int getTransitionType(WindowingModeTransitionInfo info) {
    if (info.currentTransitionProcessRunning) {
        if (info.startResult == START_SUCCESS) {
            return TYPE_TRANSITION_WARM_LAUNCH;
        } else if (info.startResult == START_TASK_TO_FRONT) {
            return TYPE_TRANSITION_HOT_LAUNCH;
        }
    } else if (info.startResult == START_SUCCESS
            || (info.startResult == START_TASK_TO_FRONT)) {
        // TaskRecord may still exist when cold launching an activity and the start
        // result will be set to START_TASK_TO_FRONT. Treat this as a COLD launch.
        return TYPE_TRANSITION_COLD_LAUNCH;
    }
    return INVALID_TRANSITION_TYPE;
}
```

从这个代码来看，其实前面的流程就已经能判断出启动类型了：
    **COLD_LAUNCH:** 冷启动，没有进程记录（进程不存在）。
    **WARN_LAUNCH:** 温启动，有进程记录并且绑定了 ActivityThread（有进程并且 UI 线程在运行），没有Activity 记录（没有 Activity 对象）。
    **HOT_LAUNCH:** 热启动，有进程记录并且绑定了 ActivityThread，并且有 Activity 对象。

  (3). **logcat: “Displayed xx: +1s356ms”:** logcat 格式化输出上面 windowDrawnDelayMs 的统计时间。但是这里有个判断：**如果是热启动就不打印**（难道 google 认为 热启动 性能就一定没问题？），怪不得以前好像有些时候又没看到这个打印。

  (4). **TraceEnd: “laucning: xx”**: 结束 “launching: xx” 的 systrace 统计。这个统计也是在 startActivityMayWait 里面调用 notifyActivityLaunched 开始的，到这里结束。这里注意一点（前面也说过）：notifyActivityLaunched 比 notifyActivityLaunching 少了一个 startActivity() 函数的调用的流程。

**2 . 通知等待 WaitResult**
  Part1 startActivity() 结束后，如果是需要等待的话（am start -W），那么统计完启动系统后，就会对等待的锁发一个唤醒通知。

## Part8. App1 Stop 处理

[点击这里看大图](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow_part8.png)
![activity start flow part8](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_flow_part8.png)

这部分虽然是 Activity 生命周期的一部分（前一个 Activity 的），但是它并不影响 Activity 的启动速度，因为它是在当前 Activity 完成了第一帧的绘制之后才执行的。但是作为生命周期的一部分，还是简单说说吧。

**1 .Message Queue idle：**
  (1). Part4 提到过，当启动的 Activity 的 UIThread 的消息队列里面没有消息需要处理（消息队列为空，或者消息处理时间还没到），在启动的流程中，典型的表现就是**第一帧绘制结束了**。因为前面可以看到所有的 UI 处理都是发消息到 UIThread 的消息队列里面处理的，如果消息队列为空，就说明这些消息都处理完了。这个时候就会执行 idle 消息的处理（Part4 有介绍，ViewRootImpl 在给 Choreographer 发送完回调后，会把自己的 Idle Handler 添加到 UIThread 的消息队列的 idle 消息中）。
  (2). ViewRootImp 的 idle Handler 是调用了 ATMS#activityIdle()： —> 使用 ClientLifecycleManger 给前一个 Activity 发 StopActivityItem 请求。

**2 . App1 执行 Stop 处理:**
  Stop 处理其实比较简单，主要是回调了应用的 **Activity#OnStop**，在这之后 activity 状态变成 **ON_STOP** 状态。

## 启动入口流程

![pre activity start flow](https://mingming-killer.github.io/img/pics/android/perf-activity-start/pre_activity_start_flow.png)

前面有提到不同的 activity 启动方式，入口流程有点不一样（但是最后都会汇集到 ActivityStarter#startActivityMayWait）。这里就来简单看看：

### Context#startActivity

这个是调用 Context 的 startActivity 接口启动 activity，典型场景：点击桌面图标启动 Activity。这个流程不需要等待 WaitResult。**当 ActivityStarter#startActivity() 返回的时候，它的调用就结束了。所以调用结束后，Activity 并没有真正启动起来**。

### am start -W

这个和上面的流程主要的差异在于：**它会等待 WaitResult 结果，需要等第一帧绘制完成，启动数据统计完毕后，才会被唤醒继续执行**。这个命令是专门测试用的，用户场景应该用不到，但是它提供了一个方法：让调用者等待 Activity 完成启动（第一帧绘制完成），并且能得到启动数据。这个命令用来自动化测试并且统计启动数据很有用。

WaitResult 等待结束后，通过上面的 Part1-Part7 的分析，就能得到启动数据了，这个时候就会打印出来。这里注意2点：

1. TotalTime 和 WaitTime 的区别：TotalTime 是从发起 ActivityStarter#startActivity() 到 第一帧绘制完毕（完成 queueBuffer）。而 WaitTime 则是从调用 AMS#startActivityMayWait 直到这个函数返回，WaitTime 一般都会比 TotalTime 多一点，但是差别不大，因为从流程来看大头都一样，WaitTime 就是多了几个不怎么耗时的函数调用而已。
2. am start -W -S：还能加一个 -S 的参数，加了这个参数会在调用 startActivityMayWait 之前调用 AMS#forceStopPackage 强制终止进程，意思是**本次强制执行冷启动**。forceStopPackage 的威力可以看我以前写的这篇文章：[forceStopPackage 的副作用](http://light3moon.com/2015/01/28/forceStopPackage 的副作用 "forceStopPackage 的副作用)。

# 统计方法小结

## 统计方法差异

activity 启动流程分析完了，我们可以来总结一下最开始说的那几种统计方法的差异了：

![activity start time](https://mingming-killer.github.io/img/pics/android/perf-activity-start/activity_start_time.png)

### logcat: “Displayed” & am start -W xx

这2个时间是一样的：从 **ActivityStarter#startActivityMayWait()** 到 **第一帧 queueBuffer 结束**。然而热启动logcat 不打印 Displayed，再加上 am start -W 会等待启动完成，输出的信息也更全面（启动类型+启动时间），所以**建议测试启动性能的时候采用 am start -W**。时间用 TotalTime 就行了，WaitTime 我觉得可以忽略了。

### Trace: “launching: xx”

这个时间是：从 **ActivityStarter#startActivityMayWait() 中的 startActivity() 结束** 到 **第一帧 queueBuffer 结束**。它和 1 相比，少了 startActivity() 的流程，这个差不多正好是 Context#startActivity 的调用时间。所以 Trace 上面的 launching 总是会比 Displayed & am start -W 少的。开头的例子同一次启动，Displayed 和 am start -W 都是 710ms，而 Trace: launching 则是 643ms。如果用 systrace 来分析启动期间的瓶颈的话，**如果要框选应用启动时间段的话，建议开始时间可以选 launching 的，结束时间可以选第一帧完成的 Trace 节点**。

### reportFullyDrawn()

这个时间是：从 **ActivityStarter#startActivityMayWait()** 到 **应用调用 reportFullyDrawn**。它的开始时间和 Displayed & am start -W 是一样的，但是结束时间就不固定了，因为是由应用决定的。而有些应用调用的时机很早，例如说：android 10 上 aosp 的 Settings:

![settings reportFullyDrawn](https://mingming-killer.github.io/img/pics/android/perf-activity-start/settings_reportFullyDrawn.png)

在 Activity#onCreate 就调用了，所以从这个 Settings 来看，使用这个指标统计出来的启动时间都很短：

```
Starting: Intent { act=android.intent.action.MAIN cat=[android.intent.category.LAUNCHER] cmp=com.android.settings/.Settings }
Status: ok
LaunchState: WARM
Activity: com.android.settings/.Settings
TotalTime: 351

ActivityTaskManager: Fully drawn com.android.settings/.Settings: +351ms

ActivityTaskManager: Displayed com.android.settings/.Settings: +1s45ms
```

另外在 Android 10 上，如果调用 reprotFullyDrawn()，那么 am start -W 统计出来的时间也会变成和 reportFullyDrawn() 的一样。因为在代码里面，reprotFullyDrawn 里面去通知 ActivityMetricsLogger 统计时间的时候，顺带把 am start -W 的数据也给统计了。但是 Displayed 不会。不过这个问题在 Android 11 上修复了。

一个是并不是所有应都会调用 reportFullyDrawn()，另外一个应用调用的时机也各种各样。所以**如果是系统分析启动性能，并不建议采用这个方式**。

### 补充

看本章节启动时间图可以发现，其实上面的统计方法都没有包含下面2个部分：

1. 用户点击触屏 input 系统响应输入事件，然后 inputflinger 分发给应用，应用响应 onTouch/onClick 的这段时间。
2. SF 把第一帧合成，送给 HWC，最后到 LCD 更新显示这段时间。

上面这2个时间段，其实并不是很好统计（am start -W 就直接跳过1了），但是从用户感知的角度，加上这一头、一尾才是真正 activity 的启动时间。所以我在图上把这2段也加上去了。不过如果真要优化这2段的话，估计要自己加点打印之类的来统计了或者抓 systrace 应该也是可以的。

## 启动类型差异

在 Android 10（从哪个版本开始的我不太确定，反正 7.1 的时候还是没有的）上正式给 activity 启动的类型进行了划分。从前面的分析也能知道区别了，这里归纳总结一下：

### COLD_LAUNCH:

**判断条件：**
  没有进程记录（进程不存在）。典型场景：第一次启动 或者 后台进程被 lmk 回收。

**启动路径：**

1. fork 进程
2. 创建 Applicaton 对象并初始化
3. 创建 ActivityThread 对象并绑定到 Application
4. 前一个焦点 Activity：onPause
5. 创建 Activity 对象：onCreate -> onStart -> onResume
6. onMeasure -> onLayout
7. 绘制第一帧

### WARN_LAUNCH:

**判断条件：**
  有进程记录并且绑定了 ActivityThread（有进程并且 UI 线程在运行），没有 Activity 对象。典型场景：activity 按 back 键退出后，在没被 lmk 回收的情况下，再次启动 activity。

**启动路径：**

1. 前一个焦点 Activity：onPause
2. 创建 Activity 对象：onCreate -> onStart -> onResume
3. onMeasure -> onLayout
4. 绘制第一帧

### HOT_LAUNCH:

**判断条件：**
  有 Activity 对象（进程 和 ActivityThread 必定存在）。典型场景：activity 按 home 键切到后台，在没被 lmk 回收的情况下，再次启动 activity。

**启动路径：**

1. 前一个焦点 Activity：onPause
2. Activity 对象：onRestart -> onStart -> onResume
3. onMeasure -> onLayout
4. 绘制第一帧

## 系统流程分析心得

分析系统的流程、框架，除了直接看代码外，还可以辅助一些调试手段，能更快速的掌握和理解系统的框架和结构。目前我使用到的方法有下面几种：

### AndroidStudio 打断点单步调试

具体方法见我的这篇文章：[Android Studio 如何调试 Framework](http://light3moon.com/2020/06/10/Android Studio 如何调试 Framework)。注意需要是 eng 或是 userdebug 的固件才可以。

### Method and function traces

AndroidStudio 3.0 之后一个叫 Profiler 工具带的功能，使用方法见官网介绍：[android_developer: 使用 CPU 性能剖析器检查 CPU 活动](https://developer.android.com/studio/profile/cpu-profiler)。可以收集 java 和 native 方法的调用堆栈，上面的断点只能打 java 代码。也是需要 eng 或是 userdebug 才行。

### Systrace

通过 systrace 也能看得出一些执行流程。但是效果没上面2钟方法好。systrace 的用法官网有：[android_developer: 系统跟踪概览](https://developer.android.com/topic/performance/tracing) 。不过从 Android 10 之后官方推的就是 Perfetto 了，这个东西需要翻墙联网才能浏览，我没用过，反正现在我还是用 systrace 的。抓 systrace 很简单，在 sdk 的 tools 下，点开 monitor.bat，再点 “capture system wide trace using Android systrace” 就能抓了。

### 打印函数调用堆栈

俗称 “加打印”，适用性最广，但是效率最低（需要重新编译模块，然后 push；某些模块好像不好 push 的只能打包整个固件）。android 打堆栈的方法，见我的这篇文章：[Android 打印函数调用堆栈调试](http://light3moon.com/2015/01/26/Android 打印函数调用堆栈调试)。

### 补充

15年那会我在 4.4 上分析过一次 activity 的启动流程，见我以前的文章：[AMS小分析](http://light3moon.com/2015/01/31/工作小笔记——Android 自带的应用统计服务[UsageStatsService]#AMS_小分析)。和 Android 10 的比较起来，其实大体流程还是一致的，只是不少细节变了，一些代码重构整合成新的框架了。还有就是以前那篇文章没有分析第一帧绘制的流程（因为以前这块还没摸清楚），现在算是补全了。

# 优化思路

上面 activity 启动流程分析完了，启动统计时间也介绍完了。费这么大劲研究这个的目的最终还是为了优化启动速度，提高用户体验。下面仅仅提供一些思路而已，具体实现要自己去看代码或是 抓 systrace 研究：

## 压榨硬件性能类

### 场景控制

这个是通过一个叫 PowerHal 的 hal 层，来主动调节 cpu、gpu、ddr 的资源配置。PowerHal 能够自己定义一些场景模式，然后给不同的场景配置不同的 cpu、gpu、ddr 等硬件的频率，再通过 powerHit 接口切换不同的场景。例如：在 启动 activity 的时候，切换到启动模式，把 cpu、gpu、ddr 频率锁到某个比较高的数值，主动提升硬件能力，加快启动速度；启动完成后再切换回正常模式。一般 soc 的实现都有动态调频，但是由于动态调频策略一般都会兼顾功耗，不会很激进，所以会存在一定的延迟，通过主动切换场景模式的手段，其实只是缩小这个延迟而已。PowerHal 的具体说明可以看我的这篇文章：[VR 性能模式介绍#场景模式](http://light3moon.com/2019/06/25/VR 性能模式介绍#场景模式) 。

## 精简流程类

### 关闭 StartingWindow

根据前面的启动流程分析：在 ActivityStarter#startActivity() 的时候会启动一个 StartingWindow（showStartingWindow()）。启动这个窗口的目的是为了在应用还没渲染好第一帧的时候展示一个启动动画，就是类似 IOS 那种窗口缩放动画。如果在硬件好的设备上能提升用户体验，但是在某些低端设备上，这些动画效果反而会拖慢启动速度。可以结合实体使用场景去掉这个启动窗口。

### 减少不必要的 Vysnc 等待

根据前面的启动流程分析：ViewRootImpl 发起第一帧的绘制操作，是向 Choreographer post doFrame 回调。这个是需要等待 Vysnc 信号到来才能触发的。而且有些应用第一次绘制需要 post 2次，也就是说应用完成第一次绘制至少需要等待 1个 Vysnc 时间。前面也分析过，android 弄 Vsync 机制是为了防止画面撕裂。但是由于 android 是采用三重缓冲的，也就是离屏渲染，只要 SF 送显的时候按 Vysnc 送就不会有撕裂问题。所以第一帧绘制其实是可以不用等 Vsync 的，可以让应用提前绘制，减少 Vsync 等待。

## 缓存类

### 优化 lmk 回收策略

根据前面的启动流程分析：温启动比冷启动要快很多（因为少了进程 fork、Application、ActivityThread、RenderThread 的创建绑定等）。而温启动的出现场景也是比较多的（热启动不一定多，因为不是所有用户都习惯按 home 退出的）。如果应用切到后台被 lmk 回收了的话，下次启动就变成冷启动了。所以加快启动的一个方法就是：在内存允许的情况下，尽量多的保留后台应用进程，减少冷启动的次数。可以结合具体的使用场景合理的调节 lmk 的策略（或者是参数、阀值），在不影响前台应用资源使用的情况下，尽可能多的保持后台应用进程存活。

### 优化 PGO

PGO（Profile-Guided Optimization）是 android art 虚拟机的一个预编译优化机制。android 在 art 之初将应用采用全编译的方式（将应用的所有 java 字节码转化为本地字节码，节省 java 解释器的运行时间），虽然提升了运行性能，然而带来的负面影响是：占用大量存储空间；apk 安装时间大大加长。所以后续改进，增加 JIT，采用了混合编译模式：只是提前编译一小部分，后续根据应用的运行情况在后台编译部分 java 字节码，逐步提升应用性能。只是原生调度 PGO 的策略比较苛刻，对应用性能提升有限，所以可以根据自己的理解或是时间使用场景，调整 PGO 的触发策略，加快 PGO 的执行，提升应用性能（这个也会加快启动时间）。官网有一些介绍：[android_source: 使用配置文件引导的优化 (PGO)](https://source.android.com/devices/tech/perf/pgo)

### 优化 IORAP

IORAP（I/O prefetching）是 Android 11 新加入的一项优化机制。官方的博客有它的介绍：[Improving app startup with I/O prefetching](https://medium.com/androiddevelopers/improving-app-startup-with-i-o-prefetching-62fbdb9c9020)。它的作用是：在应用运行的时候收集应用启动时候的一些信息，得到应用启动时候需要加载的磁盘的内容，提前把这些数据加载到内存 cahce 里面，从而达到加快冷启动的目的。冷启动的时候读取磁盘的数据，IO 操作是很耗时的，例如下面这次 Settings 的冷启动：

![cold launch io block](https://mingming-killer.github.io/img/pics/android/perf-activity-start/cold_launch_io_block.png)

整个冷启动 2.3s（这个时间段是根据前面的分析，手动从 “launchObserverNotifyIntentStarted” 选到 “frameComplete 1”），io block 占了 840ms（618ms+222ms），比重还是很大的（systrace 图示的可以看官网的说明：[android_source: 了解 Systrace](https://source.android.com/devices/tech/debug/systrace)）。

IORAP 的触发机制，以前抓取的机制目前同样存在一些问题，导致提升效果打折扣（例如说抓 trace 的时候，是所有进程都抓的，如果在 启动activity 的时候，后台正好在运行某些服务，例如说 GMS，那么抓取的内容就并不纯粹是该应用启动需要的数据了）。大家可以自行去研究下源码实现：源码位置在：

1. java service：android/frameworks/base/startop/iorap
2. native lib: android/system/iorap/

# 参考资料

(1). [Android developer](https://developer.android.com/)
(2). [Android source](https://source.android.com/)
(3). [medium: androiddevelopers](https://medium.com/androiddevelopers)
(4). [githubpage: Android Tech And Perf](https://androidperformance.com/)
(5). [githubpage: yjy239的博客](https://yjy239.github.io/)
(6). [csdn: 薛瑄的博客](https://blog.csdn.net/xx326664162)
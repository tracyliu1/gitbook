## AMS 内存回收

### 1.内存回收

当 Android 应用程序退出时，并不清理其所占用的内存，Linux 内核进程也相应的继续存在，所谓“退出但不关闭”。从而使得用户调用程序时能够在第一时间得到响应。

当系统内存不足时，系统将激活内存回收过程。为了不因内存回收影响用户体验（如杀死当前的活动进程），

####  Android 基于进程中运行的组件及其状态规定了默认的五个回收优先级：

- IMPORTANCE_FOREGROUND:

- IMPORTANCE_VISIBLE:

- IMPORTANCE_SERVICE:

- IMPORTANCE_BACKGROUND；

- IMPORTANCE_EMPTY:

 ####   ActivityManagerService 中涉及到内存回收的几个重要的成员方法如下：

- activityIdleInternal() 

- trimApplications()

- updateOomAdjLocked()

  这几个成员方法主要负责 Android 默认的内存回收机制，若 Linux 内核中的内存回收机制没有被禁用，则跳过默认回收。

### 2.流程分析

#### 2.1 回收动作入口：ActivityStackSupervisor:activityIdleInternalLocked

##### Android 系统中内存回收的触发点大致可分为三种情况：

1. 用户程序调用 StartActivity(), 使当前活动的 Activity 被覆盖；  在ActivityThread的handleResumeActivity中在looper中加入一个Idler，idler内部调用AMS中activityIdleInternal()
2. 用户按 back 键，退出当前应用程序；对应在AMS removeStask()等一些列调用
3. 启动一个新的应用程序。这些能够触发内存回收的事件最终调用的函数接口就是 activityIdleInternal()。

当 ActivityStackSupervisor接收到异步消息 IDLE_TIMEOUT_MSG 或者 IDLE_NOW_MSG 时，activityIdleInternal() 将会被调用。代码如下：

```java
case IDLE_NOW_MSG: {
    activityIdleInternal((ActivityRecord)msg.obj);
} break;
```

```java
case IDLE_TIMEOUT_MSG: {
    activityIdleInternal((ActivityRecord)msg.obj);
} break;
```

IDLE_NOW_MSG 由 Activity 的切换以及 Activiy 焦点的改变等事件引发，IDLE_TIMEOUT_MS在 Activity 启动超时的情况下引发，一般这个超时时间设为 10s，如果 10s 之内一个 Activity 依然没有成功启动，那么将发送异步消息 IDLE_TIMEOUT_MSG 进行资源回收。

activityIdleInternal() 的主要任务是改变系统中 Activity 的状态信息，并将其添加到不同状态列表中。

```java
final ActivityRecord  activityIdleInternalLocked(final IBinder token, boolean fromTimeout,
        Configuration config) {
 
    ActivityRecord r = ActivityRecord.forTokenLocked(token);  
    if (allResumedActivitiesIdle()) {
            if (r != null) {
                mService.scheduleAppGcsLocked();  //scheduleAppGcsLocked       
            }
        }

		//处理需要finish的Activity
    for (int i = 0; i < NF; i++) {
        r = finishes.get(i);
        final ActivityStack stack = r.task.stack;
        if (stack != null) {//
            activityRemoved |= stack.destroyActivityLocked(r, true, "finish-idle");
        }
    }
    mService.trimApplications(); //实际处理内存 trimApplications 最终会调到udateOomAdjLocked
    if (activityRemoved) {
        resumeFocusedStackTopActivityLocked();
    }
    return r;
}
```

ActivityStackSupervisor：activityIdleInternalLocked其主要工作如下：

调用 scheduleAppGcsLocked() 方法通知所有进行中的任务进行垃圾回收。scheduleAppGcsLocked() 将进行调度 JVM 的 garbage collect，回收一部分内存空间，这里仅仅是通知每个进程自行进程垃圾检查并调度回收时间，而非同步回收。处理需要finish 和需要stop的Activity 对应NS NF。

####   scheduleAppGcsLocked 该方法分别在以下情况被调用

- ActivityStackSupervisor：activityIdleInternalLocked每次会调用scheduleAppGcsLocked；

- AMS：doLowMemReportIfNeededLocked lowmemory时候

- ActivityRecord：windowsVisibleLocked  window可见变化
- BroadcastQueue：processNextBroadcast 处理完广播 size = 0

####   调用scheduleAppGcsLocked流程 最终走向 ActivityThread handleLowMemory()调用各级onLowMemory()，以及AT中的GCIdler。

判断mProcessesToGc数量大于0，发送GC_BACKGROUND_PROCESSES_MSG

```java
   final void scheduleAppGcsLocked() {
       if (mProcessesToGc.size() > 0) {
           ProcessRecord proc = mProcessesToGc.get(0);
         //判断mProcessesToGc数量大于0，发送GC_BACKGROUND_PROCESSES_MSG
           Message msg = mHandler.obtainMessage(GC_BACKGROUND_PROCESSES_MSG);
           long when = proc.lastRequestedGc + GC_MIN_INTERVAL;
           long now = SystemClock.uptimeMillis();
           if (when < (now+GC_TIMEOUT)) {
               when = now + GC_TIMEOUT;
           }
           mHandler.sendMessageAtTime(msg, when);
       }
   }
```

```java
 final void performAppGcsIfAppropriateLocked() {
     if (canGcNowLocked()) { //判断是否可以GC，根据广播 sleep 等判断
         performAppGcsLocked();
         return;
     }
     // Still not idle, wait some more.
     scheduleAppGcsLocked();  //不可以则等待
 }
```

performAppGcsLocked()，根据时间判断当前时间和上次时间+GC默认间隔做判断

```java
final void performAppGcsLocked() { 
      if (canGcNowLocked()) {
          while (mProcessesToGc.size() > 0) {
              ProcessRecord proc = mProcessesToGc.remove(0);
              if (proc.curRawAdj > ProcessList.PERCEPTIBLE_APP_ADJ || proc.reportLowMemory){
              //如果上次GC时间 + 最小GC间隔 小于等于 现在时间
                  if ((proc.lastRequestedGc+GC_MIN_INTERVAL)<= SystemClock.uptimeMillis()) {
                      // To avoid spamming the system, we will GC processes one
                      // at a time, waiting a few seconds between each.
                      performAppGcLocked(proc); //准备GC 这里最终会调到AT中的GCIdler
                      scheduleAppGcsLocked();//等待
                      return;
                  }
              }
          }
      }
  }
```

performAppGcLocked中会判断当前进程是否LowMemory，如果是则会走ActivityThread handleLowMemory() ,否则对应ActivityThread中scheduleGcIdler()

```java
 final void performAppGcLocked(ProcessRecord app) {
     try {
         app.lastRequestedGc = SystemClock.uptimeMillis();
         if (app.thread != null) {
             if (app.reportLowMemory) {
                 app.reportLowMemory = false;
                 app.thread.scheduleLowMemory();   //ActivityThread的 handleLowMemory()            
             } else {
                 app.thread.processInBackground(); 
             }
         }
     } catch (Exception e) {
     }
 }
```

##### AT#handleLowMemory()  最终调用到各级执行onLowMemory回调

处理了各级onLowMemory的回调，释放非system的sqlite 释放service，调用GC

```java
final void handleLowMemory() {
     ArrayList<ComponentCallbacks2> callbacks = collectComponentCallbacks(true, null);
     final int N = callbacks.size();
     for (int i=0; i<N; i++) {
         callbacks.get(i).onLowMemory();//各级执行onLowMemory回调
     }
     // Ask SQLite to free up as much memory as it can, mostly from its page caches.
     if (Process.myUid() != Process.SYSTEM_UID) { //释放sqlite
         int sqliteReleased = SQLiteDatabase.releaseMemory();
         EventLog.writeEvent(SQLITE_MEM_RELEASED_EVENT_LOG_TAG, sqliteReleased);
     }
     // Ask graphics to free up as much as possible (font/image caches)
     Canvas.freeCaches();//释放canvas
     // Ask text layout engine to free also as much as possible
     Canvas.freeTextLayoutCaches();
     BinderInternal.forceGc("mem"); // 注意这里
 }
```

上面performAppGcLocked(proc)最终会调到AT#scheduleGcIdler(),再消息队列里添加一个mGcIdler，mGcIdler是一个IdleHandler

```java
void scheduleGcIdler() {
    if (!mGcIdlerScheduled) {
        mGcIdlerScheduled = true;
        Looper.myQueue().addIdleHandler(mGcIdler);
    }
}
```

接下来可以看下doGcIfNeeded  根据上次GC的时间加上两次GC间隔的最小时间5s，判断当前是否要GC

```java
void doGcIfNeeded() {
    mGcIdlerScheduled = false;
    final long now = SystemClock.uptimeMillis();
    if ((BinderInternal.getLastGcTime()+MIN_TIME_BETWEEN_GCS) < now) {
        BinderInternal.forceGc("bg");
    }
}
```



### 2.2. 回收过程函数 trimApplications()

trimApplications()在系统中调用地方

1. ActivityStackSupervisor: activityIdleInternalLocked
2. AMS:activityStopped
3. AMS:setProcessLimit
4. AMS:unregisterReceiver
5. AMS:finishReceiver 

trimApplications() 函数的结构如下 :

mRemovedProcesses 列表中主要包含了 crash 的进程、5 秒内没有响应并被用户选在强制关闭的进程、以及应用开发这调用 killBackgroundProcess 想要杀死的进程。调用 Process.killProcess 将所有此类进程全部杀死。

```java
final void trimApplications() {
    synchronized (this) {
        int i;
        // First remove any unused application processes whose package has been removed.     
      for (i=mRemovedProcesses.size()-1; i>=0; i--) {
            final ProcessRecord app = mRemovedProcesses.get(i);
            if (app.activities.size() == 0 && app.curReceiver == null && app.services.size() == 0) {             
                if (app.pid > 0 && app.pid != MY_PID) {
                    app.kill("empty", false);
                } else {         
                        app.thread.scheduleExit();                
                }
                cleanUpApplicationRecordLocked(app, false, true, -1, false/*replacingPid*/);
                mRemovedProcesses.remove(i);
                if (app.persistent) {
                    addAppLocked(app.info, false, null /* ABI override */);
                }
            }
        }
        // Now update the oom adj for all processes.
        updateOomAdjLocked();
    }
}
```

 从上面代码中可以看出，进程被杀死的条件是：

1. 必须是非 persistent 进程，即非系统进程；

2. 必须是空进程，即进程中没有任何 activity 存在。如果杀死存在 Activity 的进程，有可能关闭用户正在使用的程序，或者使应用程序恢复的时延变大，从而影响用户体验；

3. 必须无 broadcast receiver。运行 broadcast receiver 一般都在等待一个事件的发生，用户并不希望此类程序被系统强制关闭；

4. 进程中 service 的数量必须为 0。存在 service 的进程很有可能在为一个或者多个程序提供某种服务，如GPS 定位服务。杀死此类进程将使其他进程无法正常服务。 

### 2.3 updateOomAdjLocked

AMS相关各种操作都会碰到这个调用，主要在做了两个事情 一个就是更新各个进程adj， 另一个是最终调用到onTrimMemory；

### ADJ级别

| **ADJ****级别**        | **取值** | **含义**                     |
| ---------------------- | -------- | ---------------------------- |
| NATIVE_ADJ             | -1000    | native进程                   |
| SYSTEM_ADJ             | -900     | 仅指system_server进程        |
| PERSISTENT_PROC_ADJ    | -800     | 系统persistent进程           |
| PERSISTENT_SERVICE_ADJ | -700     | 关联着系统或persistent进程   |
| `FOREGROUND_APP_ADJ`   | 0        | 前台进程                     |
| `VISIBLE_APP_ADJ`      | 100      | 可见进程                     |
| `PERCEPTIBLE_APP_ADJ`  | 200      | 可感知进程，比如后台音乐播放 |
| BACKUP_APP_ADJ         | 300      | 备份进程                     |
| HEAVY_WEIGHT_APP_ADJ   | 400      | 重量级进程                   |
| `SERVICE_ADJ`          | 500      | 服务进程                     |
| HOME_APP_ADJ           | 600      | Home进程                     |
| PREVIOUS_APP_ADJ       | 700      | 上一个进程                   |
| `SERVICE_B_ADJ`        | 800      | B List中的Service            |
| `CACHED_APP_MIN_ADJ`   | 900      | 不可见进程的adj最小值        |
| CACHED_APP_MAX_ADJ     | 906      | 不可见进程的adj最大值        |

 

```java
final boolean updateOomAdjLocked(ProcessRecord app) {
  
    final int cachedAdj = app.curRawAdj >= ProcessList.CACHED_APP_MIN_ADJ
            ? app.curRawAdj : ProcessList.UNKNOWN_ADJ;
  //判断是否updateOomAdj成功 当需要杀掉目标进程则返回false；否则返回true。 
    boolean success = updateOomAdjLocked(app, cachedAdj, TOP_APP, false，SystemClock.uptimeMillis());
    if (wasCached != app.cached || app.curRawAdj == ProcessList.UNKNOWN_ADJ) {
        // Changed to/from cached state, so apps after it in the LRU list may also be changed.
        updateOomAdjLocked();
    }
    return success;
}
```

app.thread.scheduleTrimMemory

```java
final void updateOomAdjLocked() {
   
    
    } else {
        if (mLowRamStartTime != 0) {
            mLowRamTimeSinceLastIdle += now - mLowRamStartTime;
            mLowRamStartTime = 0;
        }
        for (int i=N-1; i>=0; i--) {
            ProcessRecord app = mLruProcesses.get(i);
            if (allChanged || app.procStateChanged) {
                setProcessTrackerStateLocked(app, trackerMemFactor, now);
                app.procStateChanged = false;
            }
            if ((app.curProcState >= ActivityManager.PROCESS_STATE_IMPORTANT_BACKGROUND
                    || app.systemNoUi) && app.pendingUiClean) {
                if (app.trimMemoryLevel < ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN
                        && app.thread != null) {
                    try {
                        if (DEBUG_SWITCH || DEBUG_OOM_ADJ) Slog.v(TAG_OOM_ADJ,
                                "Trimming memory of ui hidden " + app.processName
                                + " to " + ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN);
                        app.thread.scheduleTrimMemory(
                                ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN);
                    } catch (RemoteException e) {
                    }
                }
                app.pendingUiClean = false;
            }
            app.trimMemoryLevel = 0;
        }
    }  
}
```

#### 3.onLowMemory、 onTrimMemory优化

##### OnTrimMemory的主要作用就是指导应用程序在不同的情况下进行自身的内存释放，以避免被系统直接杀掉，提高应用程序的用户体验

OnTrimMemory：Android 4.0之后提供的API，系统会根据不同的内存状态来回调。根据不同的内存状态，来响应不同的内存释放策略。

##### onLowMemory()方法在使用过程只要低内存状态下,就会回调.

OnLowMemory：Android提供的API，在系统内存不足，所有后台程序（优先级为background的进程，不是指后台运行的进程）都被杀死时，系统会调用OnLowMemory。


##### onTrimMemory传入的几个内存级别释放内存：

- TRIM_MEMORY_RUNNING_MODERATE
  你的应用正在运行，并且不会被杀死，但设备已经处于低内存状态，并且开始杀死LRU缓存里的内存。(后台进程超过5个)，并且该进程优先级比较高，需要清理内存 

- TRIM_MEMORY_RUNNING_LOW
  你的应用正在运行，并且不会被杀死，但设备处于内存更低的状态，所以你应该释放无用资源以提高系统性能(直接影响app性能)

- TRIM_MEMORY_RUNNING_CRITICAL
  你的应用还在运行，但系统已经杀死了LRU缓存里的大多数进程，所以你应该在此时释放所有非关键的资源。如果系统无法回收足够的内存，它会清理掉所有LRU缓存，并且开始杀死之前优先保持的进程，像那些运行着service的。(后台进程不足3个)，并且该进程优先级比较高，需要清理内存

- TRIM_MEMORY_BACKGROUND
  系统运行在低内存状态，并且你的进程已经接近LRU列表的顶端(即将被清理).虽然你的app进程还没有很高的被杀死风险，系统可能已经清理LRU里的进程，你应该释放那些容易被恢复的资源，如此可以让你的进程留在缓存里，并且当用户回到app时快速恢复.该进程是后台进程。

- TRIM_MEMORY_MODERATE
  系统运行在低内存状态，你的进程在LRU列表中间附近。如果系统变得内存紧张，可能会导致你的进程被杀死。并且该进程在后台进程列表的中部。

- TRIM_MEMORY_COMPLETE
  系统运行在低内存状态，如果系统没有恢复内存，你的进程是首先被杀死的进程之一。你应该释放所有不重要的资源来恢复你的app状态。该进程在后台进程列表最后一个，马上就要被清

- TRIM_MEMORY_UI_HIDDEN：内存不足，并且该进程的UI已经不可见了。 

  

  ##### onLowMemory、 onTrimMemory优化，需要释放什么资源？

  在内存紧张的时候，会回调OnLowMemory/OnTrimMemory，需要在回调方法中编写释放资源的代码。
  可以在资源紧张的时候，释放UI 使用的资源资：Bitmap、数组、控件资源。
  注意回调时刻：
  OnLowMemory被回调时，已经没有后台进程；而onTrimMemory被回调时，还有后台进程。
  OnLowMemory是在最后一个后台进程被杀时调用，一般情况是low memory killer 杀进程后触发；而OnTrimMemory的触发更频繁，每次计算进程优先级时，只要满足条件，都会触发。
  在Application、 Activity、Fragement、Service、ContentProvider中都可以重写回调方法，对OnLowMemory/OnTrimMemory进行回调，在回调方法中实现资源释放的实现。
  以Activity为例，在Activity源码中能够看到对于onTrimMemory的定义，因此在回调的时候重写方法即可。



### 4.BinderInternal

BinderInternal内部有sGcWatchers对应一个runnable list，BinderInternal重写了finalize()方法。

##### 根据JVM的原理，JVM垃圾回收器准备释放内存前，会先调用该对象finalize。

当执行GC的时候，会依次执行每个runnabe的run()方法，

并根据具体内存情况（3/4 davilk memory）进行操作。

```java
public class BinderInternal {
    static WeakReference<GcWatcher> sGcWatcher
            = new WeakReference<GcWatcher>(new GcWatcher());
    static ArrayList<Runnable> sGcWatchers = new ArrayList<>(); //
    static Runnable[] sTmpWatchers = new Runnable[1]; //数组
    static long sLastGcTime;

    static final class GcWatcher {
        @Override
        protected void finalize() throws Throwable {
            handleGc();
            sLastGcTime = SystemClock.uptimeMillis();
            synchronized (sGcWatchers) {
                sTmpWatchers = sGcWatchers.toArray(sTmpWatchers);
            }
            for (int i=0; i<sTmpWatchers.length; i++) {
                if (sTmpWatchers[i] != null) {
                    sTmpWatchers[i].run();
                }
            }
            sGcWatcher = new WeakReference<GcWatcher>(new GcWatcher());
            /*finallize方法最后重新创建了一个GcWatcher的弱引用。sGcWatcher是一个静态对象，
            如果它是一个强引用，那么他就会存在静态引用方法区，就会导致这个强引用的GC线程无法回收。
            所以作为弱引用，引用对象在被回收时就会触发sGcWatcher的finalize方法，执行结束时仔new一个弱引用出来，以保证下次的调用。*/
        }
    }

    public static void forceGc(String reason) {
        EventLog.writeEvent(2741, reason);
        VMRuntime.getRuntime().requestConcurrentGC();
    }
    
```



### 5. 单个应用内存限制

Android 内存 - 获取单个应用内存限制

- adb shell getprop | grep dalvik.vm.heapgrowthlimit

```java
ActivityManager activityManager =(ActivityManager)context.getSystemService(Context.ACTIVITY_SERVICE);
``activityManager.getMemoryClass();
``activityManager.getLargeMemoryClass();
```

 Runtime.getRuntime().maxMemory()

  

**-dalvik.vm.heapstartsize**       

   堆分配的初始大小，调整这个值会影响到应用的流畅性和整体ram消耗。这个值越小，系统ram消耗越慢，

 但是由于初始值较小，一些较大的应用需要扩张这个堆，从而引发gc和堆调整的策略，会应用反应更慢。

 相反，这个值越大系统ram消耗越快，但是程序更流畅。

 **-dalvik.vm.heapgrowthlimit**    

   受控情况下的极限堆（仅仅针对dalvik堆，不包括native堆）大小，dvm heap是可增长的，但是正常情况下

 dvm heap的大小是不会超过dalvik.vm.heapgrowthlimit的值（非正常情况下面会详细说明）。这个值控制那

 些受控应用的极限堆大小，如果受控的应用dvm heap size超过该值，则将引发oom（out of memory）。

 **-dalvik.vm.heapsize** 

  不受控情况下的极限堆大小，这个就是堆的最大值。不管它是不是受控的。这个值会影响非受控应用的dalvik

 heap size。一旦dalvik heap size超过这个值，直接引发oom。

 在android开发中，如果要使用大堆。需要在manifest中指定android:largeHeap为true。这样dvm heap最大可达dalvik.vm.heapsize。


# Android内存回收机制

#### 1.回收机制简述

当 Android 应用程序退出时，并不清理其所占用的内存，Linux 内核进程也相应的继续存在，所谓“退出但不关闭”。从而使得用户调用程序时能够在第一时间得到响应。

当系统内存不足时，系统将激活内存回收过程。为了不因内存回收影响用户体验（如杀死当前的活动进程），

#### 1.1 Android 基于进程中运行的组件及其状态规定了默认的五个回收优先级：

- IMPORTANCE_FOREGROUND:

- IMPORTANCE_VISIBLE:

- IMPORTANCE_SERVICE:

- IMPORTANCE_BACKGROUND；

- IMPORTANCE_EMPTY:

 ####  1.2 ActivityManagerService 中涉及到内存回收的几个重要的成员方法如下：

- activityIdleInternal() 

- trimApplications()

- updateOomAdjLocked()

   这几个成员方法主要负责 Android 默认的内存回收机制，若 Linux 内核中的内存回收机制没有被禁用，则跳过默认回收。

#### 2.流程分析

#### 2.1 回收动作入口：ActivityStackSupervisor:activityIdleInternalLocked

Android 系统中内存回收的触发点大致可分为三种情况：

1. 用户程序调用 StartActivity(), 使当前活动的 Activity 被覆盖；
2. 用户按 back 键，退出当前应用程序；
3. 启动一个新的应用程序。这些能够触发内存回收的事件最终调用的函数接口就是 activityIdleInternal()。

当 ActivityStackSupervisor接收到异步消息 IDLE_TIMEOUT_MSG 或者 IDLE_NOW_MSG 时，activityIdleInternal() 将会被调用。代码如下：

```java
case IDLE_NOW_MSG: {
    activityIdleInternal((ActivityRecord)msg.obj);
} break;
```

```java
case IDLE_TIMEOUT_MSG: {
    if (mService.mDidDexOpt) {
        mService.mDidDexOpt = false;
        Message nmsg = mHandler.obtainMessage(IDLE_TIMEOUT_MSG);
        nmsg.obj = msg.obj;
        mHandler.sendMessageDelayed(nmsg, IDLE_TIMEOUT);
        return;
    }
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
                mService.scheduleAppGcsLocked();            }
        }

		//处理需要finish的Activity
    for (int i = 0; i < NF; i++) {
        r = finishes.get(i);
        final ActivityStack stack = r.task.stack;
        if (stack != null) {//
            activityRemoved |= stack.destroyActivityLocked(r, true, "finish-idle");
        }
    }
    mService.trimApplications(); //实际处理内存
    if (activityRemoved) {
        resumeFocusedStackTopActivityLocked();
    }
    return r;
}
```

ActivityStackSupervisor：activityIdleInternalLocked其主要工作如下：

调用 scheduleAppGcsLocked() 方法通知所有进行中的任务进行垃圾回收。scheduleAppGcsLocked() 将进行调度 JVM 的 garbage collect，回收一部分内存空间，这里仅仅是通知每个进程自行进程垃圾检查并调度回收时间，而非同步回收。处理需要finish 和需要stop的Activity 对应NS NF。

##### 2.1.1 scheduleAppGcsLocked 该方法分别在以下情况被调用

- ActivityStackSupervisor：activityIdleInternalLocked每次会调用scheduleAppGcsLocked；

- AMS：doLowMemReportIfNeededLocked lowmemory时候

- ActivityRecord：windowsVisibleLocked  window可见变化
- BroadcastQueue：processNextBroadcast 处理完广播 size = 0

#####  2.1.2 调用scheduleAppGcsLocked流程

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
                      performAppGcLocked(proc); //准备GC
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

##### AT#handleLowMemory()

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

AT#scheduleGcIdler(),再消息队列里添加一个mGcIdler，mGcIdler是一个IdleHandler

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

##### 2.1.3 BinderInternal.forceGc("bg")



#### 2.2.回收过程函数 trimApplications()

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

#### 2.3 updateOomAdjLocked

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
    final ActivityRecord TOP_ACT = resumedAppLocked();
    final ProcessRecord TOP_APP = TOP_ACT != null ? TOP_ACT.app : null;
    final boolean wasCached = app.cached;
    mAdjSeq++;

    // This is the desired cached adjusment we want to tell it to use.
    // If our app is currently cached, we know it, and that is it.  Otherwise,
    // we don't know it yet, and it needs to now be cached we will then
    // need to do a complete oom adj.
    final int cachedAdj = app.curRawAdj >= ProcessList.CACHED_APP_MIN_ADJ
            ? app.curRawAdj : ProcessList.UNKNOWN_ADJ;
  //判断是否updateOomAdj成功
    boolean success = updateOomAdjLocked(app, cachedAdj, TOP_APP, false，SystemClock.uptimeMillis());
    if (wasCached != app.cached || app.curRawAdj == ProcessList.UNKNOWN_ADJ) {
        // Changed to/from cached state, so apps after it in the LRU list may also be changed.
        updateOomAdjLocked();
    }
    return success;
}
```

```java
private final boolean updateOomAdjLocked(ProcessRecord app, int cachedAdj,
        ProcessRecord TOP_APP, boolean doingAll, long now) {
// 计算adj，返回计算后RawAdj值;
    computeOomAdjLocked(app, cachedAdj, TOP_APP, doingAll, now);
//应用adj，当需要杀掉目标进程则返回false；否则返回true。
    return applyOomAdjLocked(app, doingAll, now, SystemClock.elapsedRealtime());
}
```

```java
final void updateOomAdjLocked() {
    final ActivityRecord TOP_ACT = resumedAppLocked();
    final ProcessRecord TOP_APP = TOP_ACT != null ? TOP_ACT.app : null;
    final long now = SystemClock.uptimeMillis();
    final long nowElapsed = SystemClock.elapsedRealtime();
    final long oldTime = now - ProcessList.MAX_EMPTY_TIME;
    final int N = mLruProcesses.size();

   
    // Reset state in all uid records.
    for (int i=mActiveUids.size()-1; i>=0; i--) {
        final UidRecord uidRec = mActiveUids.valueAt(i);
        if (false && DEBUG_UID_OBSERVERS) Slog.i(TAG_UID_OBSERVERS,
                "Starting update of " + uidRec);
        uidRec.reset();
    }

    mStackSupervisor.rankTaskLayersIfNeeded();

    mAdjSeq++;
    mNewNumServiceProcs = 0;
    mNewNumAServiceProcs = 0;

    final int emptyProcessLimit;
    final int cachedProcessLimit;
    if (mProcessLimit <= 0) {
        emptyProcessLimit = cachedProcessLimit = 0;
    } else if (mProcessLimit == 1) {
        emptyProcessLimit = 1;
        cachedProcessLimit = 0;
    } else {
        emptyProcessLimit = ProcessList.computeEmptyProcessLimit(mProcessLimit);
        cachedProcessLimit = mProcessLimit - emptyProcessLimit;
    }

    // Let's determine how many processes we have running vs.
    // how many slots we have for background processes; we may want
    // to put multiple processes in a slot of there are enough of
    // them.
    int numSlots = (ProcessList.CACHED_APP_MAX_ADJ
            - ProcessList.CACHED_APP_MIN_ADJ + 1) / 2;
    int numEmptyProcs = N - mNumNonCachedProcs - mNumCachedHiddenProcs;
    if (numEmptyProcs > cachedProcessLimit) {
        // If there are more empty processes than our limit on cached
        // processes, then use the cached process limit for the factor.
        // This ensures that the really old empty processes get pushed
        // down to the bottom, so if we are running low on memory we will
        // have a better chance at keeping around more cached processes
        // instead of a gazillion empty processes.
        numEmptyProcs = cachedProcessLimit;
    }
    int emptyFactor = numEmptyProcs/numSlots;
    if (emptyFactor < 1) emptyFactor = 1;
    int cachedFactor = (mNumCachedHiddenProcs > 0 ? mNumCachedHiddenProcs : 1)/numSlots;
    if (cachedFactor < 1) cachedFactor = 1;
    int stepCached = 0;
    int stepEmpty = 0;
    int numCached = 0;
    int numEmpty = 0;
    int numTrimming = 0;

    mNumNonCachedProcs = 0;
    mNumCachedHiddenProcs = 0;

    // First update the OOM adjustment for each of the
    // application processes based on their current state.
    int curCachedAdj = ProcessList.CACHED_APP_MIN_ADJ;
    int nextCachedAdj = curCachedAdj+1;
    int curEmptyAdj = ProcessList.CACHED_APP_MIN_ADJ;
    int nextEmptyAdj = curEmptyAdj+2;
    ProcessRecord selectedAppRecord = null;
    long serviceLastActivity = 0;
    int numBServices = 0;
    for (int i=N-1; i>=0; i--) {
        ProcessRecord app = mLruProcesses.get(i);
        if (app == null) {
            continue;
        }
        if (mEnableBServicePropagation && app.serviceb
                && (app.curAdj == ProcessList.SERVICE_B_ADJ)) {
            numBServices++;
            for (int s = app.services.size() - 1; s >= 0; s--) {
                ServiceRecord sr = app.services.valueAt(s);
                if (DEBUG_OOM_ADJ) Slog.d(TAG,"app.processName = " + app.processName
                        + " serviceb = " + app.serviceb + " s = " + s + " sr.lastActivity = "
                        + sr.lastActivity + " packageName = " + sr.packageName
                        + " processName = " + sr.processName);
                if (SystemClock.uptimeMillis() - sr.lastActivity
                        < mMinBServiceAgingTime) {
                    if (DEBUG_OOM_ADJ) {
                        Slog.d(TAG,"Not aged enough!!!");
                    }
                    continue;
                }
                if (serviceLastActivity == 0) {
                    serviceLastActivity = sr.lastActivity;
                    selectedAppRecord = app;
                } else if (sr.lastActivity < serviceLastActivity) {
                    serviceLastActivity = sr.lastActivity;
                    selectedAppRecord = app;
                }
            }
        }
        if (DEBUG_OOM_ADJ && selectedAppRecord != null) Slog.d(TAG,
                "Identified app.processName = " + selectedAppRecord.processName
                + " app.pid = " + selectedAppRecord.pid);
        if (!app.killedByAm && app.thread != null) {
            app.procStateChanged = false;
            computeOomAdjLocked(app, ProcessList.UNKNOWN_ADJ, TOP_APP, true, now);

            // If we haven't yet assigned the final cached adj
            // to the process, do that now.
            if (app.curAdj >= ProcessList.UNKNOWN_ADJ) {
                switch (app.curProcState) {
                    case ActivityManager.PROCESS_STATE_CACHED_ACTIVITY:
                    case ActivityManager.PROCESS_STATE_CACHED_ACTIVITY_CLIENT:
                        // This process is a cached process holding activities...
                        // assign it the next cached value for that type, and then
                        // step that cached level.
                        app.curRawAdj = curCachedAdj;
                        app.curAdj = app.modifyRawOomAdj(curCachedAdj);
                        if (DEBUG_LRU && false) Slog.d(TAG_LRU, "Assigning activity LRU #" + i
                                + " adj: " + app.curAdj + " (curCachedAdj=" + curCachedAdj
                                + ")");
                        if (curCachedAdj != nextCachedAdj) {
                            stepCached++;
                            if (stepCached >= cachedFactor) {
                                stepCached = 0;
                                curCachedAdj = nextCachedAdj;
                                nextCachedAdj += 2;
                                if (nextCachedAdj > ProcessList.CACHED_APP_MAX_ADJ) {
                                    nextCachedAdj = ProcessList.CACHED_APP_MAX_ADJ;
                                }
                            }
                        }
                        break;
                    default:
                        // For everything else, assign next empty cached process
                        // level and bump that up.  Note that this means that
                        // long-running services that have dropped down to the
                        // cached level will be treated as empty (since their process
                        // state is still as a service), which is what we want.
                        app.curRawAdj = curEmptyAdj;
                        app.curAdj = app.modifyRawOomAdj(curEmptyAdj);
                        if (DEBUG_LRU && false) Slog.d(TAG_LRU, "Assigning empty LRU #" + i
                                + " adj: " + app.curAdj + " (curEmptyAdj=" + curEmptyAdj
                                + ")");
                        if (curEmptyAdj != nextEmptyAdj) {
                            stepEmpty++;
                            if (stepEmpty >= emptyFactor) {
                                stepEmpty = 0;
                                curEmptyAdj = nextEmptyAdj;
                                nextEmptyAdj += 2;
                                if (nextEmptyAdj > ProcessList.CACHED_APP_MAX_ADJ) {
                                    nextEmptyAdj = ProcessList.CACHED_APP_MAX_ADJ;
                                }
                            }
                        }
                        break;
                }
            }

            applyOomAdjLocked(app, true, now, nowElapsed);

            // Count the number of process types.
            switch (app.curProcState) {
                case ActivityManager.PROCESS_STATE_CACHED_ACTIVITY:
                case ActivityManager.PROCESS_STATE_CACHED_ACTIVITY_CLIENT:
                    mNumCachedHiddenProcs++;
                    numCached++;
                    if (numCached > cachedProcessLimit) {
                        app.kill("cached #" + numCached, true);
                    }
                    break;
                case ActivityManager.PROCESS_STATE_CACHED_EMPTY:
                    if (numEmpty > ProcessList.TRIM_EMPTY_APPS
                            && app.lastActivityTime < oldTime) {
                        app.kill("empty for "
                                + ((oldTime + ProcessList.MAX_EMPTY_TIME - app.lastActivityTime)
                                / 1000) + "s", true);
                    } else {
                        numEmpty++;
                        if (numEmpty > emptyProcessLimit) {
                            app.kill("empty #" + numEmpty, true);
                        }
                    }
                    break;
                default:
                    mNumNonCachedProcs++;
                    break;
            }

            if (app.isolated && app.services.size() <= 0) {
                // If this is an isolated process, and there are no
                // services running in it, then the process is no longer
                // needed.  We agressively kill these because we can by
                // definition not re-use the same process again, and it is
                // good to avoid having whatever code was running in them
                // left sitting around after no longer needed.
                app.kill("isolated not needed", true);
            } else {
                // Keeping this process, update its uid.
                final UidRecord uidRec = app.uidRecord;
                if (uidRec != null && uidRec.curProcState > app.curProcState) {
                    uidRec.curProcState = app.curProcState;
                }
            }

            if (app.curProcState >= ActivityManager.PROCESS_STATE_HOME
                    && !app.killedByAm) {
                numTrimming++;
            }
        }
    }
    if ((numBServices > mBServiceAppThreshold) && (true == mAllowLowerMemLevel)
            && (selectedAppRecord != null)) {
        ProcessList.setOomAdj(selectedAppRecord.pid, selectedAppRecord.info.uid,
                ProcessList.CACHED_APP_MAX_ADJ);
        selectedAppRecord.setAdj = selectedAppRecord.curAdj;
        if (DEBUG_OOM_ADJ) Slog.d(TAG,"app.processName = " + selectedAppRecord.processName
                    + " app.pid = " + selectedAppRecord.pid + " is moved to higher adj");
    }

    mNumServiceProcs = mNewNumServiceProcs;

    // Now determine the memory trimming level of background processes.
    // Unfortunately we need to start at the back of the list to do this
    // properly.  We only do this if the number of background apps we
    // are managing to keep around is less than half the maximum we desire;
    // if we are keeping a good number around, we'll let them use whatever
    // memory they want.
    final int numCachedAndEmpty = numCached + numEmpty;
    int memFactor;
    if (numCached <= ProcessList.TRIM_CACHED_APPS
            && numEmpty <= ProcessList.TRIM_EMPTY_APPS) {
        if (numCachedAndEmpty <= ProcessList.TRIM_CRITICAL_THRESHOLD) {
            memFactor = ProcessStats.ADJ_MEM_FACTOR_CRITICAL;
        } else if (numCachedAndEmpty <= ProcessList.TRIM_LOW_THRESHOLD) {
            memFactor = ProcessStats.ADJ_MEM_FACTOR_LOW;
        } else {
            memFactor = ProcessStats.ADJ_MEM_FACTOR_MODERATE;
        }
    } else {
        memFactor = ProcessStats.ADJ_MEM_FACTOR_NORMAL;
    }
    // We always allow the memory level to go up (better).  We only allow it to go
    // down if we are in a state where that is allowed, *and* the total number of processes
    // has gone down since last time.
    if (DEBUG_OOM_ADJ) Slog.d(TAG_OOM_ADJ, "oom: memFactor=" + memFactor
            + " last=" + mLastMemoryLevel + " allowLow=" + mAllowLowerMemLevel
            + " numProcs=" + mLruProcesses.size() + " last=" + mLastNumProcesses);
    if (memFactor > mLastMemoryLevel) {
        if (!mAllowLowerMemLevel || mLruProcesses.size() >= mLastNumProcesses) {
            memFactor = mLastMemoryLevel;
            if (DEBUG_OOM_ADJ) Slog.d(TAG_OOM_ADJ, "Keeping last mem factor!");
        }
    }
    if (memFactor != mLastMemoryLevel) {
        EventLogTags.writeAmMemFactor(memFactor, mLastMemoryLevel);
    }
    mLastMemoryLevel = memFactor;
    mLastNumProcesses = mLruProcesses.size();
    boolean allChanged = mProcessStats.setMemFactorLocked(memFactor, !isSleepingLocked(), now);
    final int trackerMemFactor = mProcessStats.getMemFactorLocked();
    if (memFactor != ProcessStats.ADJ_MEM_FACTOR_NORMAL) {
        if (mLowRamStartTime == 0) {
            mLowRamStartTime = now;
        }
        int step = 0;
        int fgTrimLevel;
        switch (memFactor) {
            case ProcessStats.ADJ_MEM_FACTOR_CRITICAL:
                fgTrimLevel = ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL;
                break;
            case ProcessStats.ADJ_MEM_FACTOR_LOW:
                fgTrimLevel = ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW;
                break;
            default:
                fgTrimLevel = ComponentCallbacks2.TRIM_MEMORY_RUNNING_MODERATE;
                break;
        }
        int factor = numTrimming/3;
        int minFactor = 2;
        if (mHomeProcess != null) minFactor++;
        if (mPreviousProcess != null) minFactor++;
        if (factor < minFactor) factor = minFactor;
        int curLevel = ComponentCallbacks2.TRIM_MEMORY_COMPLETE;
        for (int i=N-1; i>=0; i--) {
            ProcessRecord app = mLruProcesses.get(i);
            if (app == null) {
                continue;
            }
            if (allChanged || app.procStateChanged) {
                setProcessTrackerStateLocked(app, trackerMemFactor, now);
                app.procStateChanged = false;
            }
            if (app.curProcState >= ActivityManager.PROCESS_STATE_HOME
                    && !app.killedByAm) {
                if (app.trimMemoryLevel < curLevel && app.thread != null) {
                    try {
                        if (DEBUG_SWITCH || DEBUG_OOM_ADJ) Slog.v(TAG_OOM_ADJ,
                                "Trimming memory of " + app.processName + " to " + curLevel);
                        app.thread.scheduleTrimMemory(curLevel);
                    } catch (RemoteException e) {
                    }
                    if (false) {
                        // For now we won't do this; our memory trimming seems
                        // to be good enough at this point that destroying
                        // activities causes more harm than good.
                        if (curLevel >= ComponentCallbacks2.TRIM_MEMORY_COMPLETE
                                && app != mHomeProcess && app != mPreviousProcess) {
                            // Need to do this on its own message because the stack may not
                            // be in a consistent state at this point.
                            // For these apps we will also finish their activities
                            // to help them free memory.
                            mStackSupervisor.scheduleDestroyAllActivities(app, "trim");
                        }
                    }
                }
                app.trimMemoryLevel = curLevel;
                step++;
                if (step >= factor) {
                    step = 0;
                    switch (curLevel) {
                        case ComponentCallbacks2.TRIM_MEMORY_COMPLETE:
                            curLevel = ComponentCallbacks2.TRIM_MEMORY_MODERATE;
                            break;
                        case ComponentCallbacks2.TRIM_MEMORY_MODERATE:
                            curLevel = ComponentCallbacks2.TRIM_MEMORY_BACKGROUND;
                            break;
                    }
                }
            } else if (app.curProcState == ActivityManager.PROCESS_STATE_HEAVY_WEIGHT) {
                if (app.trimMemoryLevel < ComponentCallbacks2.TRIM_MEMORY_BACKGROUND
                        && app.thread != null) {
                    try {
                        if (DEBUG_SWITCH || DEBUG_OOM_ADJ) Slog.v(TAG_OOM_ADJ,
                                "Trimming memory of heavy-weight " + app.processName
                                + " to " + ComponentCallbacks2.TRIM_MEMORY_BACKGROUND);
                        app.thread.scheduleTrimMemory(
                                ComponentCallbacks2.TRIM_MEMORY_BACKGROUND);
                    } catch (RemoteException e) {
                    }
                }
                app.trimMemoryLevel = ComponentCallbacks2.TRIM_MEMORY_BACKGROUND;
            } else {
                if ((app.curProcState >= ActivityManager.PROCESS_STATE_IMPORTANT_BACKGROUND
                        || app.systemNoUi) && app.pendingUiClean) {
                    // If this application is now in the background and it
                    // had done UI, then give it the special trim level to
                    // have it free UI resources.
                    final int level = ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN;
                    if (app.trimMemoryLevel < level && app.thread != null) {
                        try {
                            if (DEBUG_SWITCH || DEBUG_OOM_ADJ) Slog.v(TAG_OOM_ADJ,
                                    "Trimming memory of bg-ui " + app.processName
                                    + " to " + level);
                            app.thread.scheduleTrimMemory(level);
                        } catch (RemoteException e) {
                        }
                    }
                    app.pendingUiClean = false;
                }
                if (app.trimMemoryLevel < fgTrimLevel && app.thread != null) {
                    try {
                        if (DEBUG_SWITCH || DEBUG_OOM_ADJ) Slog.v(TAG_OOM_ADJ,
                                "Trimming memory of fg " + app.processName
                                + " to " + fgTrimLevel);
                        app.thread.scheduleTrimMemory(fgTrimLevel);
                    } catch (RemoteException e) {
                    }
                }
                app.trimMemoryLevel = fgTrimLevel;
            }
        }
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

    if (mAlwaysFinishActivities) {
        // Need to do this on its own message because the stack may not
        // be in a consistent state at this point.
        mStackSupervisor.scheduleDestroyAllActivities(null, "always-finish");
    }

    if (allChanged) {
        requestPssAllProcsLocked(now, false, mProcessStats.isMemFactorLowered());
    }

    // Update from any uid changes.
    for (int i=mActiveUids.size()-1; i>=0; i--) {
        final UidRecord uidRec = mActiveUids.valueAt(i);
        int uidChange = UidRecord.CHANGE_PROCSTATE;
        if (uidRec.setProcState != uidRec.curProcState) {
            if (DEBUG_UID_OBSERVERS) Slog.i(TAG_UID_OBSERVERS,
                    "Changes in " + uidRec + ": proc state from " + uidRec.setProcState
                    + " to " + uidRec.curProcState);
            if (ActivityManager.isProcStateBackground(uidRec.curProcState)) {
                if (!ActivityManager.isProcStateBackground(uidRec.setProcState)) {
                    uidRec.lastBackgroundTime = nowElapsed;
                    if (!mHandler.hasMessages(IDLE_UIDS_MSG)) {
                        // Note: the background settle time is in elapsed realtime, while
                        // the handler time base is uptime.  All this means is that we may
                        // stop background uids later than we had intended, but that only
                        // happens because the device was sleeping so we are okay anyway.
                        mHandler.sendEmptyMessageDelayed(IDLE_UIDS_MSG, BACKGROUND_SETTLE_TIME);
                    }
                }
            } else {
                if (uidRec.idle) {
                    uidChange = UidRecord.CHANGE_ACTIVE;
                    uidRec.idle = false;
                }
                uidRec.lastBackgroundTime = 0;
            }
            uidRec.setProcState = uidRec.curProcState;
            enqueueUidChangeLocked(uidRec, -1, uidChange);
            noteUidProcessState(uidRec.uid, uidRec.curProcState);
        }
    }

    if (mProcessStats.shouldWriteNowLocked(now)) {
        mHandler.post(new Runnable() {
            @Override public void run() {
                synchronized (ActivityManagerService.this) {
                    mProcessStats.writeStateAsyncLocked();
                }
            }
        });
    }

    
    }
```

 

Android 内存 - 获取单个应用内存限制

 

方法一：

 

| 12   | `adb shell getprop | grep dalvik.vm.heapgrowthlimit`` ``[dalvik.vm.heapgrowthlimit]: [64m]` |
| ---- | ------------------------------------------------------------ |
|      |                                                              |

 


方法二：

 

| 123  | `ActivityManager activityManager =(ActivityManager)context.getSystemService(Context.ACTIVITY_SERVICE);``activityManager.getMemoryClass();``activityManager.getLargeMemoryClass();` |
| ---- | ------------------------------------------------------------ |
|      |                                                              |

 


方法三：

 

| 1234 | `adb shell cat /system/build.prop``dalvik.vm.heapstartsize=8m ``dalvik.vm.heapgrowthlimit=64m ``dalvik.vm.heapsize=256m` |
| ---- | ------------------------------------------------------------ |
|      |                                                              |

 


方法四：

| 1    | `Runtime.getRuntime().maxMemory()` |
| ---- | ---------------------------------- |
|      |                                    |

 

 

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
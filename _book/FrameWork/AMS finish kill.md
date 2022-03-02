

# AMS finish()   kill  



## 1. Activity finish流程

- ActivityManagerService.finishActivity--->
- ActivityStack.requestFinishActivityLocked--->
- ActivityStack.finishActivityLocked

```java
final boolean finishActivityLocked(ActivityRecord r, int resultCode, Intent resultData,
        String reason, boolean oomAdj) {
 
    r.makeFinishingLocked();//把当前的Activity修改成 finishing = true状态
   
    r.pauseKeyDispatchingLocked();  //停止key分发

    adjustFocusedActivityLocked(r, "finishActivity");

    finishActivityResultsLocked(r, resultCode, resultData);

    final boolean endTask = index <= 0;
    final int transit = endTask ? TRANSIT_TASK_CLOSE : TRANSIT_ACTIVITY_CLOSE;
    if (mResumedActivity == r) {
        // Tell window manager to prepare for this one to be removed.
        mWindowManager.setAppVisibility(r.appToken, false);

        if (mPausingActivity == null) {
            startPausingLocked(false, false, null, false); //暂停当前Activity
        }

        if (endTask) {
            mStackSupervisor.removeLockedTaskLocked(task);
        }
    } else if (r.state != ActivityState.PAUSING) {
        // If the activity is PAUSING, we will complete the finish once
        // it is done pausing; else we can just directly finish it here.
        if (DEBUG_PAUSE) Slog.v(TAG_PAUSE, "Finish not pausing: " + r);
        if (r.visible) {
            mWindowManager.prepareAppTransition(transit, false);
            mWindowManager.setAppVisibility(r.appToken, false);
            mWindowManager.executeAppTransition();
            if (!mStackSupervisor.mWaitingVisibleActivities.contains(r)) {
                mStackSupervisor.mWaitingVisibleActivities.add(r);
            }
        }
        return finishCurrentActivityLocked(r, (r.visible || r.nowVisible) ?
                FINISH_AFTER_VISIBLE : FINISH_AFTER_PAUSE, oomAdj) == null;
    } else {
        if (DEBUG_PAUSE) Slog.v(TAG_PAUSE, "Finish waiting for pause of: " + r);
    }

    return false;
}
```



```java
private void adjustFocusedActivityLocked(ActivityRecord r, String reason) {
    final ActivityRecord next = topRunningActivityLocked();//获取到就是下一个要启动的Activity
    if (next != r) {//ｒ是当前的Activity，但next 就是下一个要启动的Activity
            mService.setFocusedActivityLocked(next, myReason);
            return;
    }     
         // AMS下一个Activity设置成Focused
        mService.setFocusedActivityLocked(mStackSupervisor.topRunningActivityLocked()
}
```

在setFocusedActivityLocked里面会调用

- ActivityStackSupervisor.moveActivityStackToFront
- ActivityStack.moveToFront，把将要启动Activity对应的task放到最顶端；

ActivityStack.finishActivityLocked方法之后会调用

- ActivityStack.startPausingLocked

- ActivityStack.activityPausedLocked

- ActivityStack.completePauseLocked

- ActivityStack.resumeTopActivityInnerLocked，最后调到resumeTopActivityInnerLocked－－－scheduleResumeActivity显示下一个Activity

  

下一个Activity正常onResume显示时候会调用IdleInternal接口然后执行  这里可以链接一个ondestory执行10s超时的问题，原因是因为idlehandler没有调用。

- ActivityStackSupervisor$ActivityStackSupervisorHandler.activityIdleInternal
- ActivityStackSupervisor.activityIdleInternalLocked－－－》
- ActivityStack.finishCurrentActivityLocked－－》
- ActivityStack.destroyActivityLocked
  这时候正式调用之前上一个Activity的onStop和onDestroy并且将它从系统中finish，移除系统列表；



## 2. kill



### 2.1 killProcess

> frameworks/base/core/java/android/os/Process.java

```java
public static final void killProcess(int pid) {
 ALOGI("Sending signal. PID: %" PRId32 " SIG: %" PRId32, pid, sig);
    sendSignal(pid, SIGNAL_KILL);   // 9
}
```

##### 以下情况会被调用

- AMS: public void restart()  对应am restart命令
- ActivityThread: public final void scheduleSuicide()  对应AMS中killApplicationProcess  backupmanagerservice逻辑
- ViewRootImpl:public void windowFocusChanged()  当硬件绘制遇到OutOfResourcesException 如果windowSeesion没有outOfMemory的时候
- ViewRootImpl:private void handleOutOfResourcesException()   对应performTraversals 和 draw中的异常处理
- Watchdog: run()  
- RuntimeInit:public static void wtf() /UncaughtHandler

### 2.2 killProcessQuiet

```java
public static final void killProcessQuiet(int pid) {
    sendSignalQuiet(pid, SIGNAL_KILL);
}
```

- AMS:removeLruProcessLocked()  

- AMS:appDiedLocked()    处理binder die的情况
- AMS:attachApplicationLocked()     ActivityThread attach的时候判断 pid
- ProcessRecord:kill()             killedByAm = false的情况   对应AMS处理

![process-kill-quiet](http://gityuan.com/images/android-process/process-kill-quiet.jpg)

`sendSignal`和`sendSignalQuiet`的唯一区别就是在于是否有ALOGI()这一行代码。最终杀进程的实现方法都是调用`kill(pid, sig)`方法。

### 2.3 killProcessGroup

> system/core/libprocessgroup/processgroup.cpp

killProcessGroup主要调用了killProcessGroupOnce，设定尝试最多40次杀死进程。

```cpp
int killProcessGroup(uid_t uid, int initialPid, int signal)
{
    int processes;
    const int sleep_us = 5 * 1000;  // 5ms
    int64_t startTime = android::uptimeMillis();
    int retry = 40;
    while ((processes = killProcessGroupOnce(uid, initialPid, signal)) > 0) {
        if (retry > 0) {
            usleep(sleep_us);
            --retry;
        } else {
            break;
        }
    }
    if (processes == 0) {
        return removeProcessGroup(uid, initialPid);
    } else {
        return -1;
    }
}
```



```cpp
static int killProcessGroupOnce(uid_t uid, int initialPid, int signal)
{
    int processes = 0;
    struct ctx ctx;
    pid_t pid;
    ctx.initialized = false;

    while ((pid = getOneAppProcess(uid, initialPid, &ctx)) >= 0) {
        processes++;
        int ret = kill(pid, signal);//挨个杀
        if (ret == -1) {
            SLOGW("failed to kill pid %d: %s", pid, strerror(errno));
        }
    }
    if (ctx.initialized) {
        close(ctx.fd);
    }

    return processes; // 代表总共杀死了进程组中的进程个数
}
```

`killProcessGroupOnce`的功能是杀掉uid下，跟initialPid同一个进程组的所有进程。也就意味着通过`kill <pid>` ，当pid是某个进程的子线程时，那么最终杀的仍是进程

![process-kill-group](http://gityuan.com/images/android-process/process-kill-group.jpg)

#### 总结：

- Process.killProcess(int pid): 杀pid进程
- Process.killProcessQuiet(int pid)：杀pid进程，且不输出log信息
- Process.killProcessGroup(int uid, int pid)：杀同一个uid下同一进程组下的所有进程




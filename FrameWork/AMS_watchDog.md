### WatchDog原理



Watchdog是一个运行在system_server进程的名为”watchdog”的线程,主要有mHandlerCheckers负责进程监测。

主要的工作原理即在watchdog的run方法中不断调用每个checkers的monitor，得到waitState的状态，从而进行不同的处理。

当阻塞时间超过30s打印包括当前进程以及核心native进程的Stacktrace，kernel线程Stacktrace，打印Kernel里面blocked的线程以及所有CPU的backtraces，超过1min时则会触发重启。



- `mHandlerCheckers`记录所有的HandlerChecker对象的列表，包括foreground, main, ui, i/o, display线程的handler;通过mHandler.getLooper().getQueue().isPolling()判断是否超时，
- `mHandlerChecker.mMonitors`记录所有Watchdog目前正在监控Monitor，所有的这些monitors都运行在foreground线程。
- BinderThreadMonitor主要是通过判断Binder线程是否超过了系统最大值来判断是否超时，
- 有两种方式加入Watchdog监控
  - addThread()：用于监测Handler线程，判断消息是否阻塞。默认超时时长为60s.这种超时往往是所对应的handler线程消息处理得慢；
  - addMonitor(): 用于监控实现了Watchdog.Monitor接口的服务.判断是否发生死锁。这种超时可能是”android.fg”线程消息处理得慢，也可能是monitor迟迟拿不到锁；




#### WatchDog 启动

在SystemServer的startOtherService 中 AMS的systemReady启动watchdog ，并且注册REBOOT广播。

```java
mActivityManagerService.systemReady(new Runnable() {

    @Override
    public void run() {
    Watchdog.getInstance().start(); //构造并start
    watchdog.init(context, mActivityManagerService);//注册 ACTION_REBOOT 广播
    }
}   
```

首先 构造器中初始化各种HandlerChecker，分别检测FgThread、mainThread、UIThread、IOThread、DisplayThread。foreground是特别需要提到的，

> frameworks/base/services/core/java/com/android/server/Watchdog.java

```java
private Watchdog() {
 
    mMonitorChecker = new HandlerChecker(FgThread.getHandler(),"foreground thread",DEFAULT_TIMEOUT);
    mHandlerCheckers.add(mMonitorChecker);
    mHandlerCheckers.add(new HandlerChecker(new Handler(Looper.getMainLooper()),
            "main thread", DEFAULT_TIMEOUT));
    mHandlerCheckers.add(new HandlerChecker(UiThread.getHandler(),
            "ui thread", DEFAULT_TIMEOUT));
    mHandlerCheckers.add(new HandlerChecker(IoThread.getHandler(),
            "i/o thread", DEFAULT_TIMEOUT));
    mHandlerCheckers.add(new HandlerChecker(DisplayThread.getHandler(),
            "display thread", DEFAULT_TIMEOUT));

    // Initialize monitor for Binder threads.
    addMonitor(new BinderThreadMonitor()); //通过判断Binder线程是否超过了系统最大值来判断是否超时，
}
```



#### 初始化BinderThreadMonitor

```java
private static final class BinderThreadMonitor implements Watchdog.Monitor {
    @Override
    public void monitor() {
        Binder.blockUntilThreadAvailable();
    }
}
```

```cpp
static void android_os_Binder_blockUntilThreadAvailable(JNIEnv* env, jobject clazz){
    return IPCThreadState::self()->blockUntilThreadAvailable();}
```

> frameworks/native/libs/binder/IPCThreadState.cpp

```cpp
void IPCThreadState::blockUntilThreadAvailable(){
    pthread_mutex_lock(&mProcess->mThreadCountLock);
    while (mProcess->mExecutingThreadsCount >= mProcess->mMaxThreads) {
      //等待正在执行的binder线程小于进程最大binder线程上限(16个)
        pthread_cond_wait(&mProcess->mThreadCountDecrement, &mProcess->mThreadCountLock);
    }
    pthread_mutex_unlock(&mProcess->mThreadCountLock);
}
```

#### WatchDog Run 方法

WatchDog中的run主要做了三件事

1. 执行所有的Checker的监控方法scheduleCheckLocked()
   - 当mMonitor个数为0(除了android.fg线程之外都为0)且处于poll状态,则设置mCompleted = true;
   - 当上次check还没有完成, 则直接返回.
2. 等待30s后, 再调用evaluateCheckerCompletionLocked来评估Checker状态;

3. 根据waitState状态来执行不同的操作:
   - 当COMPLETED或WAITING,则相安无事；
   - 当WAITED_HALF(超过30s)且为首次, 输出trace；
   - 当OVERDUE, 则输出更多信息如dropbox，杀死systemserver 重启系统；

```java
@Override
public void run() {
  			
      for (int i=0; i<mHandlerCheckers.size(); i++) {
                HandlerChecker hc = mHandlerCheckers.get(i);
                hc.scheduleCheckLocked();
      }     
  
  	  	long start = SystemClock.uptimeMillis();
            //通过循环,保证执行30s才会继续往下执行
            while (timeout > 0) {
                try {
                    wait(timeout); //触发中断,直接捕获异常,继续等待.
                } catch (InterruptedException e) {
                    Log.wtf(TAG, e);
                }
                timeout = CHECK_INTERVAL - (SystemClock.uptimeMillis() - start);
            }
  
  	     //评估Checker状态
            final int waitState = evaluateCheckerCompletionLocked();
            if (waitState == COMPLETED) {
                waitedHalf = false;
                continue;
            } else if (waitState == WAITING) {
                continue;
            } else if (waitState == WAITED_HALF) {
                if (!waitedHalf) {
                    //首次进入等待时间过半的状态
                    ArrayList<Integer> pids = new ArrayList<Integer>();
                    pids.add(Process.myPid());
                    //输出system_server和3个native进程的
                    ActivityManagerService.dumpStackTraces(true, pids, null, null,
                            NATIVE_STACKS_OF_INTEREST);
                    waitedHalf = true;
                }
                continue;
            }
  
   					 // something is overdue!
                blockedCheckers = getBlockedCheckersLocked();//得到所有block checker 并且打印
                subject = describeCheckersLocked(blockedCheckers);
                allowRestart = mAllowRestart;//true允许重启 
 
       final File stack = ActivityManagerService.dumpStackTraces(
                    !waitedHalf, pids, null, null, NATIVE_STACKS_OF_INTEREST);

    // deadlock and the watchdog as a whole to be ineffective)
            Thread dropboxThread = new Thread("watchdogWriteToDropbox") {
                    public void run() {
                        mActivity.addErrorToDropBox(
                                "watchdog", null, "system_server", null, null,
                                subject, null, newFd, null);
                    }
                };
            dropboxThread.start();
  
      Process.killProcess(Process.myPid());
                System.exit(10);
}
```



#### HandlerChecker scheduleCheckLocked

```java
public final class HandlerChecker implements Runnable {
    ...
    public void scheduleCheckLocked() {
        if (mMonitors.size() == 0 && mHandler.getLooper().getQueue().isPolling()) {
            mCompleted = true; //说明looper空闲
            return;
        }

        if (!mCompleted) {
            return; //有一个check正在处理中，则无需重复发送
        }
      
        mCompleted = false;
        mCurrentMonitor = null;
        mStartTime = SystemClock.uptimeMillis();  // 记录当下的时间  
        mHandler.postAtFrontOfQueue(this);// //发送消息，插入消息队列最开头， 见下方的run()方法
    }

    public void run() {
        final int size = mMonitors.size();
        for (int i = 0 ; i < size ; i++) {
            synchronized (Watchdog.this) {
                mCurrentMonitor = mMonitors.get(i);
            }
            //回调具体服务的monitor方法、比如在AMS里边就是个synchronize
            mCurrentMonitor.monitor();
        }

        synchronized (Watchdog.this) {
            mCompleted = true;
            mCurrentMonitor = null;
        }
    }
}
```

如果`mCurrentMonitor.monitor();`执行完成，没有等待，那么就会赋值`mCompleted = true;`和`mCurrentMonitor = null;`



##### evaluateCheckerCompletionLocked

根据时间评估所有checker的状态，

```java
private int evaluateCheckerCompletionLocked() {
    int state = COMPLETED; // 0 其他state 都比0大
    for (int i=0; i<mHandlerCheckers.size(); i++) {
        HandlerChecker hc = mHandlerCheckers.get(i);
        state = Math.max(state, hc.getCompletionStateLocked());//选择最坏情况
    }
    return state;
}
```

```java
public int getCompletionStateLocked() {
    if (mCompleted) {
        return COMPLETED;
    } else {
        long latency = SystemClock.uptimeMillis() - mStartTime;
        if (latency < mWaitMax/2) {// 30S
            return WAITING;
        } else if (latency < mWaitMax) { // 60s
            return WAITED_HALF;
        }
    }
    return OVERDUE; // 已经废了
}
```



如果waitState == WAITED_HALF, 超过30s的情况,打印NATIVE_STACKS_OF_INTEREST所有的堆栈信息

```java
ActivityManagerService.dumpStackTraces(true, pids, null, null,
        NATIVE_STACKS_OF_INTEREST);
        
   // Which native processes to dump into dropbox's stack traces
    public static final String[] NATIVE_STACKS_OF_INTEREST = new String[] {
        "/system/bin/audioserver",
        "/system/bin/cameraserver",
        "/system/bin/drmserver",
        "/system/bin/mediadrmserver",
        "/system/bin/mediaserver",
        "/system/bin/sdcard",
        "/system/bin/surfaceflinger",
        "media.codec",     // system/bin/mediacodec
        "media.extractor", // system/bin/mediaextractor
        "com.android.bluetooth",  // Bluetooth service
    };        
```

如果waitState == WAITED_OVERDUE 超过60s,则设置allowRestart = true，并且分别打印阻塞信息

```java
// something is overdue!
blockedCheckers = getBlockedCheckersLocked();
subject = describeCheckersLocked(blockedCheckers);//在这一步骤打印
allowRestart = mAllowRestart;
```

- MonitorChecker 延时：打印`Blocked in monitor + monitor名字 + on + 线程名`。
- HandlerChecker 延时：打印`Blocked in handler on + 名字（比如ui thread） + 线程名`



然后就是继续打印堆栈 dropbox 以及杀死systemserver重启的过程了。







---

http://gityuan.com/2016/06/21/watchdog/
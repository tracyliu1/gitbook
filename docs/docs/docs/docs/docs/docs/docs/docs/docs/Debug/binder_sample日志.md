##  binder_sample日志

#### 日志信息：

```
52004 binder_sample (descriptor|3),(method_num|1|5),(time|1|3),(blocking_package|3),(sample_percent|1|6)
```

而日志的例子是

```
05-15 12:47:06.672 10562 20858 20858 I binder_sample: [android.app.IActivityManager,13,940,com.starbucks.cn,100]
```

##### 参数意义：

| 参数             | 例子                         | 意义                                      | 备注       |
| :--------------- | :--------------------------- | :---------------------------------------- | :--------- |
| descriptor       | android.app.IActivityManager | 表示被卡住的binder调用对应的interface接口 |            |
| method_num       | 13                           | 调用方法的序列号                          |            |
| time             | 940                          | 被delay的时长                             |            |
| blocking_package | com.starbucks.cn             | 从哪个进程发起的调用                      |            |
| sample_percent   | 100                          | 被卡住的百分比                            | 暂时不关注 |

#### 源码信息：

而打印这行log的源码所在[位置](http://androidxref.com/9.0.0_r3/xref/frameworks/base/core/jni/android_util_Binder.cpp#1194)为：

```
//android_util_Binder.cpp
static void conditionally_log_binder_call(int64_t start_millis,
                                          IBinder* target, jint code) {
    int duration_ms = static_cast<int>(uptimeMillis() - start_millis);//获取到时长

    int sample_percent;
    if (duration_ms >= 500) {
        sample_percent = 100;
    } else {
        sample_percent = 100 * duration_ms / 500;
        if (sample_percent == 0) {
            return;
        }
        if (sample_percent < (random() % 100 + 1)) {
            return;
        }
    }

    char process_name[40];
    getprocname(getpid(), process_name, sizeof(process_name));//获取到client的进程名
    String8 desc(target->getInterfaceDescriptor());//这个地方获取到对应的interface调用接口

    char buf[LOGGER_ENTRY_MAX_PAYLOAD];
    buf[0] = EVENT_TYPE_LIST;
    buf[1] = 5;
    char* pos = &buf[2];
    char* end = &buf[LOGGER_ENTRY_MAX_PAYLOAD - 1];  // leave room for final \n
    if (!push_eventlog_string(&pos, end, desc.string())) return;
    if (!push_eventlog_int(&pos, end, code)) return;
    if (!push_eventlog_int(&pos, end, duration_ms)) return;
    if (!push_eventlog_string(&pos, end, process_name)) return;
    if (!push_eventlog_int(&pos, end, sample_percent)) return;
    *(pos++) = '\n';   // conventional with EVENT_TYPE_LIST apparently.
    android_bWriteLog(LOGTAG_BINDER_OPERATION, buf, pos - buf);//Log写入到日志中。
}
```

那这个方法是在什么地方调用的呢，通过查找可以知道：

```CPP
static jboolean android_os_BinderProxy_transact(JNIEnv* env, jobject obj,
        jint code, jobject dataObj, jobject replyObj, jint flags) // throws RemoteException
{
.... //省略部分代码

    bool time_binder_calls;
    int64_t start_millis;
    if (kEnableBinderSample) {//
        // Only log the binder call duration for things on the Java-level main thread.
        // But if we don't
        time_binder_calls = should_time_binder_calls();

        if (time_binder_calls) {
            start_millis = uptimeMillis();
        }
    }

    //printf("Transact from Java code to %p sending: ", target); data->print();
    status_t err = target->transact(code, *data, reply, flags);
    //if (reply) printf("Transact from Java code to %p received: ", target); reply->print();

    if (kEnableBinderSample) {
        if (time_binder_calls) {
            conditionally_log_binder_call(start_millis, target, code);
        }
    }

//省略部分代码
}
```

原来是在proxy代理进行transact的时候进行记录的，注意其中的should_time_binder_calls方法,只会去记录主线程的bindercall。

```CPP
// We only measure binder call durations to potentially log them if
// we're on the main thread.
static bool should_time_binder_calls() {
  return (getpid() == gettid());
}
```

这里就不过多的去讲binder整个框架了。因为和文章内容无关。需要知道的是，java层的binder都是通过jni的方式来调用的native端，所以在native端的proxy，也就是client进行transact的时候，进行判断，就可以拿到真正的时长信息。
而在其中的code，就是我们上面说到的调用方法的序列号，而对应的接口是如何拿到的呢。

```CPP
// target->getInterfaceDescriptor()
```

我们知道，target是server端的binder接口，远端拿到interfacedescriptor其实就是拿到了对应的mdescriptor。 而这个mdescriptor是在

```CPP
    /**
     * Convenience method for associating a specific interface with the Binder.
     * After calling, queryLocalInterface() will be implemented for you
     * to return the given owner IInterface when the corresponding
     * descriptor is requested.
     */
    public void attachInterface(@Nullable IInterface owner, @Nullable String descriptor) {
        mOwner = owner;
        mDescriptor = descriptor;
    }
```

而这个方法会填充mDescriptor,而这个方法是在server端初始化的时候就会进行填充的。这个也是binder框架的内容，暂不在讨论范围。

#### 总结：

从上面的分析可以看到，这个log也只是分析到了java层的binder调用，而native层的binder，采用的接口是BBinder和BpBinder，所以，在jni的这里添加的也就只能拿到java层主线程binder调用耗时的一个情况。而且如果添加了这个log也可以看到，需要首先进行一次getInterfaceDescriptor的操作，这个操作本身就是一个binder操作，所以其实是对性能还是有影响的，但是因为是在native层，不涉及复杂逻辑，所以增加的操作也是可以忽略的。
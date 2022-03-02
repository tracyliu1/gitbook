### Binder IPC 流程





![image-20210311152459753](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210311152459753.png)



#### 从Client端开始

一个aidl生成java文件的transact方法,mRemote是一个IBinder对象

```java
mRemote.transact(Stub.TRANSACTION_stopSmartLedFlashing, _data, _reply, 0);
```

BinderProxy实现IBinder，直接到native层

```java
final class BinderProxy implements IBinder {
    public boolean transact(int code, Parcel data, Parcel reply, int flags) throws RemoteException {
   
        return transactNative(code, data, reply, flags);
    }
```

> frameworks/base/core/jni/android_util_Binder.cpp

```cpp
static jboolean android_os_BinderProxy_transact(JNIEnv* env, jobject obj,
    jint code, jobject dataObj, jobject replyObj, jint flags)
{
    ...
    //将java Parcel转为c++ Parcel
    Parcel* data = parcelForJavaObject(env, dataObj);
    Parcel* reply = parcelForJavaObject(env, replyObj);

    //gBinderProxyOffsets.mObject中保存的是new BpBinder(handle)对象
    IBinder* target = (IBinder*) env->GetLongField(obj, gBinderProxyOffsets.mObject);
    ...

    //此处便是BpBinder::transact()【见小节2.7】
    status_t err = target->transact(code, *data, reply, flags);
    ...

    //最后根据transact执行具体情况，抛出相应的Exception
    signalExceptionForError(env, obj, err, true , data->dataSize());
    return JNI_FALSE;
}
```







![image-20210311172655265](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210311172655265.png)
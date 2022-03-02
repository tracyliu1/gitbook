







##### 对于Android应用开发来说，最好能手绘下面的系统架构图：

![image](https://raw.githubusercontent.com/BeesAndroid/BeesAndroid/master/art/android_system_structure.png)

https://raw.githubusercontent.com/BeesAndroid/BeesAndroid/master/art/android_system_structure.png



![image-20210417145255132](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210417145255132.png)



![image-20210417145629489](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210417145629489.png)



![image-20210417151822039](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210417151822039.png)





![image-20210417162142831](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210417162142831.png)





![image-20210419095921651](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210419095921651.png)



### JNI



frameworks/base/core/jni 代码编译成libandroid_runtime.so 

frameworks/base/media/jni 编译成 libmedia_jni.so

均被放置到system/lib目录





JNI正向调用





```cpp
struct fields_t {

jfieldID context;
jmethodID post_event;
};

static fields_t fields;
/* 获取和调用 */
{
fields.context = env->GetFieldID(clazz, "mNativeContext", "I");
env->SetIntField(thiz, fields.context, (int)context);
fields.post_event = env->GetStaticMethodID(clazz, 
"postEventFromNative", 
"(Ljava/lang/Object;IIILjava/lang/Object;)V");

}
```



```java
public class TestClass {
@SuppressWarnings("unused")
private int mNativeContext;
private EventHandler mEventHandler;
TestClass() {
/* ...... */
test(new WeakReference<TestClass>(this));
}
private class EventHandler extends Handler
{
private TestClass mTestClass;
public EventHandler(TestClass testclass, Looper looper) {
super(looper);
mTestClass = testclass;
}
```



反向调用

```cpp
static jint
test (JNIEnv *env, jobject thiz,jobject weak_this) {
JNIEnv *env = AndroidRuntime::getJNIEnv();
jclass clazz = env->GetObjectClass(thiz);
jobject object = env->NewGlobalRef(weak_thiz);
env->CallStaticVoidMethod(clazz, fields.post_event,
object, msgType, ext1, ext2, NULL);
/* ...... */
}
```



```java
public class TestClass {
@SuppressWarnings("unused")
private int mNativeContext;
private EventHandler mEventHandler;
TestClass() {
/* ...... */
test(new WeakReference<TestClass>(this));
}
private class EventHandler extends Handler
{
private TestClass mTestClass;
public EventHandler(TestClass testclass, Looper looper) {
super(looper);
mTestClass = testclass;
}
```





![image-20210419113346025](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210419113346025.png)









![image-20210419113915015](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210419113915015.png)















![](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210419143441835.png)

![](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210419150401814.png)



![image-20210302170854004](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210302170854004.png)





![image-20210419151225130](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210419151225130.png)







![image-20210419151500290](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210419151500290.png)





![image-20210419152150047](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210419152150047.png)
## Android上的ART虚拟机



本文是Android虚拟机系列文章的最后一篇，会讲解Android上的ART虚拟机。

本系列的相关文章如下：

- [Java虚拟机与垃圾回收算法](https://paul.pub/android-java-vm/)
- [Android上的Dalvik虚拟机](https://paul.pub/android-dalvik-vm/)
- [Android上ART虚拟机](https://paul.pub/android-art-vm/)

从Android 5.0（Lollipop）开始，Android Runtime（下文简称ART）就彻底代替了原先的Dalvik，成为Android系统上新的虚拟机。

这篇文章我们就来详细了解一下ART虚拟机。

# ART VS. Dalvik

Dalvik虚拟机是2008年跟随Android系统一起发布的。当时的移动设备的系统内存只有64M左右，CPU频率在250~500MHz之间。这个硬件水平早已发生了巨大变化。随着智能设备的兴起，这些年移动芯片的性能每年都有大幅提升。如今的智能手机内存已经有6G甚至8G至多。CPU也已经步入了64位的时代，频率高达2.0 GHz甚至更高。硬件的更新，常常也伴随着软件的换代。因此，Dalvik虚拟机被淘汰也是情理之中的事情。

Dalvik之所以要被ART替代包含下面几个原因：

- Dalvik是为32位设计的，不适用于64位CPU。
- 单纯的字节码解释加JIT编译的执行方式，性能要弱于本地机器码的执行。
- 无论是解释执行还是JIT编译都是单次运行过程中发生，每运行一次都可能需要重新做这些工作，这样做太浪费资源。
- 原先的垃圾回收机制不够好，会导致卡顿。

很显然，ART虚拟机对上面提到的这些地方做了改进。除了支持64位不必说，最主要的是下面两项改进：

- **AOT编译**：Ahead-of-time（AOT）是相对于Just-in-time（JIT）而言的。JIT是在运行时进行字节码到本地机器码的编译，这也是为什么Java普遍被认为效率比C++差的原因。无论是解释器的解释还是运行过程中即时编译，都比C++编译出的本地机器码执行多了一个耗费时间的过程。而AOT就是向C++编译过程靠拢的一项技术：当APK在安装的时候，系统会通过一个名称为`dex2oat`的工具将APK中的dex文件编译成包含本地机器码的oat文件存放下来。这样做之后，在程序执行的时候，就可以直接使用已经编译好的机器码以加快效率。

- 垃圾回收的改进

  ：GC（Garbage Collection）是虚拟机非常重要的一个特性，因为它的实现好坏会影响所有在虚拟机上运行的应用。GC实现得不好可能会导致画面跳跃，掉帧，UI响应过慢等问题。ART的垃圾回收机制相较于Dalvik虚拟机有如下改进：

  - 将GC的停顿由2次改成1次
  - 在仅有一次的GC停顿中进行并行处理
  - 在特殊场景下，对于近期创建的具有较短生命的对象消耗更少的时间进行垃圾回收
  - 改进垃圾收集的工效，更频繁的执行并行垃圾收集
  - 对于后台进程的内存在垃圾回收过程进行压缩以解决碎片化的问题

AOT编译是在应用程序安装时就进行的工作，下图描述了Dalvik虚拟机与（Android 5.0上的）ART虚拟机在安装APK时的区别：

![img](http://qiangbo-workspace.oss-cn-shanghai.aliyuncs.com/AndroidNewFeatureBook/Chapter3/art_vs_dalvik.png)

*两种虚拟机上安装APK时的流程*

从这幅图中我们看到：

- 在Dalvik虚拟机上，APK中的Dex文件在安装时会被优化成odex文件，在运行时，会被JIT编译器编译成native代码。
- 而在ART虚拟机上安装时，Dex文件会直接由dex2oat工具翻译成oat格式的文件，oat文件中既包含了dex文件中原先的内容，也包含了已经编译好的native代码。

dex2oat生成的oat文件在设备上位于`/data/dalvik-cache/`目录下。同时，由于32位和64位的机器码有所区别，因此这个目录下还会通过子文件夹对oat文件进行分类。例如，手机上通常会有下面两个目录：

- /data/dalvik-cache/arm/
- /data/dalvik-cache/arm64/

接下来，我们就以oat文件为起点来了解ART虚拟机。

# OAT文件格式

OAT文件遵循ELF格式。ELF是Unix系统上可执行文件，目标文件，共享库和Core dump文件的标准格式。ELF全称是Executable and Linkable Format，该文件格式如下图所示：

![img](http://qiangbo-workspace.oss-cn-shanghai.aliyuncs.com/AndroidNewFeatureBook/Chapter3/ELF_layout.png)

*ELF文件格式*

每个ELF文件包含一个ELF头信息，以及文件数据。

头信息描述了整个文件的基本属性，例如ELF文件版本，目标机器型号，程序入口地址等。

文件数据包含三种类型的数据：

- 程序表（Program header table）：该数据会影响系统加载进程的内存地址空间
- 段表（Section header table）：描述了ELF文件中各个段的（Section）信息
- 若干个段。常见的段包括：
  - 代码段（.text）：程序编译后的指令
  - 只读数据段（.rodata）：只读数据，通常是程序里面的只读变量和字符串常量
  - 数据段：（.data）：初始化了的全局静态变量和局部静态变量
  - BSS端（.bss）：未初始化的全局变量和局部静态变量

关于ELF文件格式的详细说明可以参见维基百科：[Executable and Linkable Format](https://en.wikipedia.org/wiki/Executable_and_Linkable_Format) ，这里不再深入讨论。

下面我们再来看一下OAT文件的格式：

![img](http://qiangbo-workspace.oss-cn-shanghai.aliyuncs.com/AndroidNewFeatureBook/Chapter3/art_oat_file.png)

*OAT文件格式*

从这个图中我们看到，OAT文件中包含的内容有：

- ELF Header：ELF头信息。
- oatdata symbol：oatdata符号，其地址指向了OAT头信息。
- Header：Oat文件的头信息，详细描述了Oat文件中的内容。例如：Oat文件的版本，Dex文件个数，指令集等等信息。Header，Dex File数组以及Class Metadata数组都位于ELF的只读数据段(.rodata)中。
- Dex File数组：生成该Oat文件的Dex文件，可能包含多个。
- Class Metadata数组：Dex中包含的类的基本信息，可能包含多个。通过其中的信息可以索引到编译后的机器码。
- 编译后的方法代码数组：每个方法编译后对应的机器码，可能包含多个。这些内容位于代码段（.text）中。

我们可以通过/art/目录下的这些源码文件来详细了解Oat文件的结构：

- compiler/oat_witer.h
- compiler/oat_writer.cc
- dex2oat/dex2oat.cc
- runtime/oat.h
- runtime/oat.cc
- runtime/oat_file.h
- runtime/oat_file.cc
- runtime/image.h
- runtime/image.cc

Oat文件的主要组成结构如下表所示：

| 字段名称            | 说明                                                    |
| :------------------ | :------------------------------------------------------ |
| OatHeader           | Oat文件头信息                                           |
| OatDexFile数组      | Dex文件的详细信息                                       |
| Dex数组             | .dex文件的拷贝                                          |
| TypeLookupTable数组 | 用来辅助查找Dex文件中的类                               |
| ClassOffsets数组    | OatDexFile中每个类的偏移表                              |
| OatClass数组        | 每个类的详细信息                                        |
| padding             | 如果需要，通过填充padding来让后面的内容进行页面对齐     |
| OatMethodHeader     | Oat文件中描述方法的头信息                               |
| MethodCode          | 类的方法代码，OatMethodHeader和MethodCode会交替出现多次 |

dex文件可以通过`dexdump`工具进行分析。oat文件也有对应的dump工具，这个工具就叫做`oatdump`。

通过adb shell连上设备之后，可以通过输入`oatdump`来查看该命令的帮助：

```
angler:/ # oatdump
No arguments specified
Usage: oatdump [options] ...
    Example: oatdump --image=$ANDROID_PRODUCT_OUT/system/framework/boot.art
    Example: adb shell oatdump --image=/system/framework/boot.art

  --oat-file=<file.oat>: specifies an input oat filename.
      Example: --oat-file=/system/framework/boot.oat

  --image=<file.art>: specifies an input image location.
      Example: --image=/system/framework/boot.art

  --app-image=<file.art>: specifies an input app image. Must also have a specified
 boot image and app oat file.

...
```

例如：可以通过–list-classes命令参数来列出dex文件中的所有类：

```
oatdump --list-classes --oat-file=/data/dalvik-cache/arm64/system@app@Calendar@Calendar.apk@classes.dex
```

# boot.oat 与 boot.art

任何应用程序都不是孤立存在的，几乎所有应用程序都会依赖Android Framework中提供的基础类，例如`Activity`，`Intent`，`Parcel`等类。所以在应用程序的代码中，自然少不了对于这些类的引用。因此，在上图中我们看到，代码（.text）段中的的代码会引用Framework Image和Framrwork Code中的内容。

考虑到几乎所有应用都存在这种引用关系，在运行时都会依赖于Framework中的类，因此系统如何处理这部分逻辑就是非常重要的了，因为这个处理的方法将影响到所有应用程序。

在AOSP编译时，会将所有这些公共类放到专门的一个Oat文件中，这个文件就是：boot.oat。与之配合的还有一个boot.art文件。

我们可以在设备上的/data/dalvik-cache/[platform]/目录下找到这两个文件：

```
-rw-r--r-- 1 root   root      11026432 1970-06-23 01:35 system@framework@boot.art
-rw-r--r-- 1 root   root      31207992 1970-06-23 01:35 system@framework@boot.oat
```

boot.art中包含了指向boot.oat中方法代码的指针，它被称之为启动镜像（Boot Image），并且被加载的位置是固定的。boot.oat被加载的地址紧随着boot.art。

包含在启动镜像中的类是一个很长的列表，它们在这个文件中配置：`frameworks/base/config/preloaded-classes`。从Android L（5.0）之后的版本开始，设备厂商可以在设备的device.mk中通过`PRODUCT_DEX_PREOPT_BOOT_FLAGS`这个变量来添加配置到启动镜像中的类。像这样：

```Makefile
PRODUCT_DEX_PREOPT_BOOT_FLAGS += --image-classes=<filename>
```

系统在初次启动时，会根据配置的列表来生成boot.oat和boot.art两个文件（读者也可以手动将/data/dalvik-cache/目录下文件都删掉来让系统重新生成），生成时的相关日志如下：

```
1249:10-04 04:25:45.700   530   530 I art     : GenerateImage: /system/bin/dex2oat --image=/data/dalvik-cache/arm64/system@framework@boot.art --dex-file=/system/framework/core-oj.jar --dex-file=/system/framework/core-libart.jar --dex-file=/system/framework/conscrypt.jar --dex-file=/system/framework/okhttp.jar --dex-file=/system/framework/core-junit.jar --dex-file=/system/framework/bouncycastle.jar --dex-file=/system/framework/ext.jar --dex-file=/system/framework/framework.jar --dex-file=/system/framework/telephony-common.jar --dex-file=/system/framework/voip-common.jar --dex-file=/system/framework/ims-common.jar --dex-file=/system/framework/apache-xml.jar --dex-file=/system/framework/org.apache.http.legacy.boot.jar --oat-file=/data/dalvik-cache/arm64/system@framework@boot.oat --instruction-set=arm64 --instruction-set-features=smp,a53 --base=0x6f96c000 --runtime-arg -Xms64m --runtime-arg -Xmx64m --compiler-filter=verify-at-runtime --image-classes=/system/etc/preloaded-classes --compiled-classes=/system/etc/compiled-classes -j4 --instruction-set-variant=cor
```

# Dalvik到ART的切换

ART虚拟机是在Android 5.0上正式启用的。实际上在Android 4.4上，就已经内置了ART虚拟机，只不过默认没有启用。但是Android在系统设置中提供了选项让用户可以切换。那么我们可能会很好奇，这里到底是如何进行虚拟机的切换的呢？

要知道这里是如何实现的，我们可以从设置界面的代码入手。Android 4.4上是在开发者选项中提供了切换虚拟机的入口。其实现类是`DevelopmentSettings`。

如果你查看相关代码你就会发现，这里切换的过程其实就是设置了一个属性值，然后将系统直接重启。相关代码如下：

```
// DevelopmentSettings.java

private static final String SELECT_RUNTIME_PROPERTY = "persist.sys.dalvik.vm.lib";
...

SystemProperties.set(SELECT_RUNTIME_PROPERTY, newRuntimeValue);
pokeSystemProperties();
PowerManager pm = (PowerManager)
        context.getSystemService(Context.POWER_SERVICE);
pm.reboot(null);
```

那么接下来我们要关注的自然是`persist.sys.dalvik.vm.lib`这个属性被哪里读取到了。

回顾一下`AndroidRuntime::start`方法，读者可能会发现这个方法中有两行代码我们前面看到了却没有关注过：

```
// AndroidRuntime.cpp

void AndroidRuntime::start(const char* className, const char* options)
{
    ...

    /* start the virtual machine */
    JniInvocation jni_invocation;
    jni_invocation.Init(NULL);
    JNIEnv* env;
    if (startVm(&mJavaVM, &env) != 0) { ①
        return;
    }
```

那就是下面这两行。实际上，它们就是切换虚拟机的关键。

```
JniInvocation jni_invocation;
jni_invocation.Init(NULL);
```

`JniInvocation`这个结构是在/libnativehelper/目录下定义的。对于虚拟机的选择也就是在这里确定的。`persist.sys.dalvik.vm.lib`属性的值实际上是`so`文件的路径，可能是libdvm.so，也可能是libart.so，前者是Dalvik虚拟机的实现，而后者就是ART虚拟机的实现。

`JniInvocation::Init`方法代码如下

```
// JniInvocation.cpp

bool JniInvocation::Init(const char* library) {
#ifdef HAVE_ANDROID_OS
  char default_library[PROPERTY_VALUE_MAX];
  property_get("persist.sys.dalvik.vm.lib", default_library, "libdvm.so"); ①
#else
  const char* default_library = "libdvm.so";
#endif
  if (library == NULL) {
    library = default_library;
  }

  handle_ = dlopen(library, RTLD_NOW); ②
  if (handle_ == NULL) { ③
    ALOGE("Failed to dlopen %s: %s", library, dlerror());
    return false;
  }
  if (!FindSymbol(reinterpret_cast<void**>(&JNI_GetDefaultJavaVMInitArgs_), ④
                  "JNI_GetDefaultJavaVMInitArgs")) {
    return false;
  }
  if (!FindSymbol(reinterpret_cast<void**>(&JNI_CreateJavaVM_),
                  "JNI_CreateJavaVM")) {
    return false;
  }
  if (!FindSymbol(reinterpret_cast<void**>(&JNI_GetCreatedJavaVMs_),
                  "JNI_GetCreatedJavaVMs")) {
    return false;
  }
  return true;
}
```

这段代码的逻辑其实很简单：

1. 获取`persist.sys.dalvik.vm.lib`属性的值（可能是libdvm.so，或者是libart.so）
2. 通过`dlopen`加载这个so库
3. 如果加载失败则报错
4. 确定so中包含了JNI接口需要的三个函数，它们分别是：
   - `JNI_GetDefaultJavaVMInitArgs`
   - `JNI_CreateJavaVM`
   - `JNI_GetCreatedJavaVMs`

而每当用户通过设置修改了`persist.sys.dalvik.vm.lib`属性值之后，便会改变这里加载的so库。由此导致了虚拟机的切换，如下图所示：

![img](http://qiangbo-workspace.oss-cn-shanghai.aliyuncs.com/AndroidNewFeatureBook/Chapter3/dalvik_art_switch.png)

*Dalvik与ART虚拟机的切换*

# ART虚拟机的启动过程

ART虚拟机的代码位于下面这个路径：

```
/art/runtime
```

[前一篇文章](https://paul.pub/android-dalvik-vm/)中我们看到，`JNI_CreateJavaVM`是由Dalvik虚拟机提供的用来创建虚拟机实例的函数。并且在`JniInvocation::Init`方法会检查，ART虚拟机的实现中也要包含这个函数。

实际上，这个函数是由JNI标准接口定义的，提供JNI功能的虚拟机都需要提供这个函数用来从native代码中启动虚拟机。

因此要知道ART虚拟机的启动逻辑，我们需要从ART的`JNI_CreateJavaVM`函数看起。

这个函数代码如下：

```
// java_vm_ext.cc

extern "C" jint JNI_CreateJavaVM(JavaVM** p_vm, JNIEnv** p_env, void* vm_args) {
  ScopedTrace trace(__FUNCTION__);
  const JavaVMInitArgs* args = static_cast<JavaVMInitArgs*>(vm_args);
  if (IsBadJniVersion(args->version)) {
    LOG(ERROR) << "Bad JNI version passed to CreateJavaVM: " << args->version;
    return JNI_EVERSION;
  }
  RuntimeOptions options;
  for (int i = 0; i < args->nOptions; ++i) {
    JavaVMOption* option = &args->options[i];
    options.push_back(std::make_pair(std::string(option->optionString), option->extraInfo));
  }
  bool ignore_unrecognized = args->ignoreUnrecognized;
  if (!Runtime::Create(options, ignore_unrecognized)) {
    return JNI_ERR;
  }

  // Initialize native loader. This step makes sure we have
  // everything set up before we start using JNI.
  android::InitializeNativeLoader();

  Runtime* runtime = Runtime::Current();
  bool started = runtime->Start();
  if (!started) {
    delete Thread::Current()->GetJniEnv();
    delete runtime->GetJavaVM();
    LOG(WARNING) << "CreateJavaVM failed";
    return JNI_ERR;
  }

  *p_env = Thread::Current()->GetJniEnv();
  *p_vm = runtime->GetJavaVM();
  return JNI_OK;
}
```

这段代码中牵涉的逻辑较多，这里就不贴出更多的代码了。下图总结了ART虚拟机的启动过程：

![img](http://qiangbo-workspace.oss-cn-shanghai.aliyuncs.com/AndroidNewFeatureBook/Chapter3/JNI_CreateJavaVM_Detail.png)

*ART虚拟机的启动过程*

图中的步骤说明如下：

- Runtime::Create： 创建Runtime实例

  - Runtime::Init：对Runtime进行初始化

    - runtime_options.GetOrDefault： 读取启动参数

    - new gc::Heap： 创建虚拟机的堆，Java语言中通过

      ```plaintext
      new
      ```

      创建的对象都位于Heap中。

      - ImageSpace::CreateBootImage：初次启动会创建Boot Image，即`boot.art`
      - garbage_collectors_.push_back： 创建若干个垃圾回收器并添加到列表中，见下文垃圾回收部分

    - Thread::Startup： 标记线程为启动状态

    - Thread::Attach： 设置当前线程为虚拟机主线程

    - LoadNativeBridge： 通过`dlopen`加载native bridge，见下文。

- android::InitializeNativeLoader： 初始化native loader，见下文。

- runtime = Runtime::Current： 获取当前Runtime实例

- runtime->Start： 通过

  ```plaintext
  Start
  ```

  接口启动虚拟机

  - InitNativeMethods： 初始化native方法

    - RegisterRuntimeNativeMethods： 注册dalvik.system，java.lang，libcore.util，org.apache.harmony以及sun.misc几个包下类的native方法
    - WellKnownClasses::Init： 预先缓存一些常用的类，方法和字段。
    - java_vm_->LoadNativeLibrary：加载`libjavacore.so`以及`libopenjdk.so`两个库
    - WellKnownClasses::LateInit： 预先缓存一些前面无法缓存的方法和字段

  - Thread::FinishStartup： 完成初始化

  - CreateSystemClassLoader： 创建系统类加载器

  - StartDaemonThreads： 调用

    ```plaintext
    java.lang.Daemons.start
    ```

    方法启动守护线程

    - java.lang.Daemons.start： 启动了下面四个Daemon：
      - ReferenceQueueDaemon
      - FinalizerDaemon
      - FinalizerWatchdogDaemon
      - HeapTaskDaemon

从这个过程中我们看到，ART虚拟机的启动，牵涉到了：创建堆；设置线程；加载基础类；创建系统类加载器；以及启动虚拟机需要的daemon等工作。

除此之外，这里再对native bridge以及native loader做一些说明。这两个模块的源码位于下面这个路径：

```
/system/core/libnativebridge/
/system/core/libnativeloader/
```

- **native bridge**：我们知道，Android系统主要是为ARM架构的CPU为开发的。因此，很多的库都是为ARM架构的CPU编译的。但是如果将Android系统移植到其他平台（例如：Intel的x86平台），就会出现很多的兼容性问题（ARM的指令无法在x86 CPU上执行）。而这个模块的作用就是：在运行时动态的进行native指令的转译，即：将ARM的指令转译成其他平台（例如x86）的指令，这也是为什么这个模块的名字叫做“Bridge”。
- **native loader**：顾名思义，这个模块专门负责native库的加载。一旦应用程序使用JNI调用，就会牵涉到native库的加载。Android系统自Android 7.0开始，加强了应用程序对于native库链接的限制：只有系统明确公开的库才允许应用程序链接。这么做的目的是为了减少因为系统升级导致了二进制库不兼容（例如：某个库没有了，或者函数符号变了），从而导致应用程序crash的问题。而这个限制的工作就是在这个模块中完成的。系统公开的二进制库在这个文件（设备上的路径）中列了出来：`/etc/public.libraries.txt`。除此之外，厂商也可能会公开一些扩展的二进制库，厂商需要将这些库放在vendor/lib（或者/vendor/lib64）目录下，同时将它们列在`/vendor/etc/public.libraries.txt`中。

# 内存分配

应用程序在任何时候都可能会创建对象，因此虚拟机对于内存分配的实现方式会严重影响应用程序的性能。

原先Davlik虚拟机使用的是传统的 [dlmalloc](http://gee.cs.oswego.edu/dl/html/malloc.html) 内存分配器进行内存分配。这个内存分配器是Linux上很常用的，但是它没有为多线程环境做过优化，因此Google为ART虚拟机开发了一个新的内存分配器：RoSalloc，它的全称是Rows of Slots allocator。RoSalloc相较于dlmalloc来说，在多线程环境下有更好的支持：在dlmalloc中，分配内存时使用了全局的内存锁，这就很容易造成性能不佳。而在RoSalloc中，允许在线程本地区域存储小对象，这就是避免了全局锁的等待时间。ART虚拟机中，这两种内存分配器都有使用。

要了解ART虚拟机对于内存的分配和回收，我们需要从Heap入手，`/art/runtime/gc/` 目录下的代码对应了这部分逻辑的实现。

在前面讲解ART虚拟机的启动过程中，我们已经看到过，ART虚拟机启动中便会创建Heap对象。其实在Heap的构造函数，还会创建下面两类对象：

- 若干个`Space`对象：Space用来响应应用程序对于内存分配的请求
- 若干个`GarbageCollector`对象：`GarbageCollector`用来进行垃圾收集，不同的`GarbageCollector`执行的策略不一样，见下文“垃圾回收”

`Space`有下面几种类型：

```
enum SpaceType {
  kSpaceTypeImageSpace,
  kSpaceTypeMallocSpace,
  kSpaceTypeZygoteSpace,
  kSpaceTypeBumpPointerSpace,
  kSpaceTypeLargeObjectSpace,
  kSpaceTypeRegionSpace,
};
```

下面一幅图是Space的具体实现类。从这幅图中我们看到， Space主要分为两类：

- 一类是内存地址连续的，它们是`ContinuousSpace`的子类
- 还有一类是内存地址不连续的，它们是`DiscontinuousSpace`的子类

![img](http://qiangbo-workspace.oss-cn-shanghai.aliyuncs.com/AndroidNewFeatureBook/Chapter3/art_space.png)

*ART虚拟机中的Space*

在一个运行的ART的虚拟机中，上面这些Space未必都会创建。有哪些Space会创建由ART虚拟机的启动参数决定。Heap对象中会记录所有创建的Space，如下所示：

```
// heap.h

// All-known continuous spaces, where objects lie within fixed bounds.
std::vector<space::ContinuousSpace*> continuous_spaces_ GUARDED_BY(Locks::mutator_lock_);

// All-known discontinuous spaces, where objects may be placed throughout virtual memory.
std::vector<space::DiscontinuousSpace*> discontinuous_spaces_ GUARDED_BY(Locks::mutator_lock_);

// All-known alloc spaces, where objects may be or have been allocated.
std::vector<space::AllocSpace*> alloc_spaces_;

// A space where non-movable objects are allocated, when compaction is enabled it contains
// Classes, ArtMethods, ArtFields, and non moving objects.
space::MallocSpace* non_moving_space_;

// Space which we use for the kAllocatorTypeROSAlloc.
space::RosAllocSpace* rosalloc_space_;

// Space which we use for the kAllocatorTypeDlMalloc.
space::DlMallocSpace* dlmalloc_space_;

// The main space is the space which the GC copies to and from on process state updates. This
// space is typically either the dlmalloc_space_ or the rosalloc_space_.
space::MallocSpace* main_space_;

// The large object space we are currently allocating into.
space::LargeObjectSpace* large_object_space_;
```

Heap类的`AllocObject`是为对象分配内存的入口，这是一个模板方法，该方法代码如下：

```
// heap.h

// Allocates and initializes storage for an object instance.
template <bool kInstrumented, typename PreFenceVisitor>
mirror::Object* AllocObject(Thread* self,
                         mirror::Class* klass,
                         size_t num_bytes,
                         const PreFenceVisitor& pre_fence_visitor)
 SHARED_REQUIRES(Locks::mutator_lock_)
 REQUIRES(!*gc_complete_lock_, !*pending_task_lock_, !*backtrace_lock_,
          !Roles::uninterruptible_) {
return AllocObjectWithAllocator<kInstrumented, true>(
   self, klass, num_bytes, GetCurrentAllocator(), pre_fence_visitor);
}
```

在这个方法的实现中，会首先通过`Heap::TryToAllocate`尝试进行内存的分配。在`Heap::TryToAllocate`方法，会根据AllocatorType，选择不同的Space进行内存的分配，下面是部分代码片段：

```
// heap-inl.h

case kAllocatorTypeRosAlloc: {
  if (kInstrumented && UNLIKELY(is_running_on_memory_tool_)) {
    ...
  } else {
    DCHECK(!is_running_on_memory_tool_);
    size_t max_bytes_tl_bulk_allocated =
        rosalloc_space_->MaxBytesBulkAllocatedForNonvirtual(alloc_size);
    if (UNLIKELY(IsOutOfMemoryOnAllocation<kGrow>(allocator_type,
                                                  max_bytes_tl_bulk_allocated))) {
      return nullptr;
    }
    if (!kInstrumented) {
      DCHECK(!rosalloc_space_->CanAllocThreadLocal(self, alloc_size));
    }
    ret = rosalloc_space_->AllocNonvirtual(self, alloc_size, bytes_allocated, usable_size,
                                           bytes_tl_bulk_allocated);
  }
  break;
}
case kAllocatorTypeDlMalloc: {
  if (kInstrumented && UNLIKELY(is_running_on_memory_tool_)) {
    // If running on valgrind, we should be using the instrumented path.
    ret = dlmalloc_space_->Alloc(self, alloc_size, bytes_allocated, usable_size,
                                 bytes_tl_bulk_allocated);
  } else {
    DCHECK(!is_running_on_memory_tool_);
    ret = dlmalloc_space_->AllocNonvirtual(self, alloc_size, bytes_allocated, usable_size,
                                           bytes_tl_bulk_allocated);
  }
  break;
}
...
case kAllocatorTypeLOS: {
  ret = large_object_space_->Alloc(self, alloc_size, bytes_allocated, usable_size,
                                   bytes_tl_bulk_allocated);
  // Note that the bump pointer spaces aren't necessarily next to
  // the other continuous spaces like the non-moving alloc space or
  // the zygote space.
  DCHECK(ret == nullptr || large_object_space_->Contains(ret));
  break;
}
case kAllocatorTypeTLAB: {
  ...
}
case kAllocatorTypeRegion: {
  DCHECK(region_space_ != nullptr);
  alloc_size = RoundUp(alloc_size, space::RegionSpace::kAlignment);
  ret = region_space_->AllocNonvirtual<false>(alloc_size, bytes_allocated, usable_size,
                                              bytes_tl_bulk_allocated);
  break;
}
case kAllocatorTypeRegionTLAB: {
  ...
  // The allocation can't fail.
  ret = self->AllocTlab(alloc_size);
  DCHECK(ret != nullptr);
  *bytes_allocated = alloc_size;
  *usable_size = alloc_size;
  break;
}
```

AllocatorType的类型有如下一些：

```
enum AllocatorType {
  kAllocatorTypeBumpPointer,  // Use BumpPointer allocator, has entrypoints.
  kAllocatorTypeTLAB,  // Use TLAB allocator, has entrypoints.
  kAllocatorTypeRosAlloc,  // Use RosAlloc allocator, has entrypoints.
  kAllocatorTypeDlMalloc,  // Use dlmalloc allocator, has entrypoints.
  kAllocatorTypeNonMoving,  // Special allocator for non moving objects, doesn't have entrypoints.
  kAllocatorTypeLOS,  // Large object space, also doesn't have entrypoints.
  kAllocatorTypeRegion,
  kAllocatorTypeRegionTLAB,
};
```

如果`Heap::TryToAllocate`失败（返回nullptr），会尝试进行垃圾回收，然后再进行内存的分配：

```
obj = TryToAllocate<kInstrumented, false>(self, allocator, byte_count, &bytes_allocated,
                                              &usable_size, &bytes_tl_bulk_allocated);
    if (UNLIKELY(obj == nullptr)) {
      obj = AllocateInternalWithGc(self,
                                   allocator,
                                   kInstrumented,
                                   byte_count,
                                   &bytes_allocated,
                                   &usable_size,
                                   &bytes_tl_bulk_allocated, &klass);
...
```

在`AllocateInternalWithGc`方法中，会先尝试进行内存回收，然后再进行内存的分配。

# 垃圾回收

在Dalvik虚拟机上，垃圾回收会造成两次停顿，第一次需要3~4毫秒，第二次需要5~6毫秒，虽然两次停顿累计也只有约10毫秒的时间，但是即便这样也是不能接受的。因为对于60FPS的渲染要求来说，每秒钟需要更新60次画面，那么留给每一帧的时间最多也就只有16毫秒。如果垃圾回收就造成的10毫秒的停顿，那么就必然造成丢帧卡顿的现象。

因此垃圾回收机制是ART虚拟机重点改进的内容之一。

## ART虚拟机垃圾回收概述

ART 有多个不同的 GC 方案，这些方案包括运行不同垃圾回收器。默认方案是 CMS（Concurrent Mark Sweep，并发标记清除）方案，主要使用粘性（sticky）CMS 和部分（partial）CMS。粘性CMS是ART的不移动（non-moving ）分代垃圾回收器。它仅扫描堆中自上次 GC 后修改的部分，并且只能回收自上次GC后分配的对象。除CMS方案外，当应用将进程状态更改为察觉不到卡顿的进程状态（例如，后台或缓存）时，ART 将执行堆压缩。

除了新的垃圾回收器之外，ART 还引入了一种基于位图的新内存分配程序，称为 RosAlloc（插槽运行分配器）。此新分配器具有分片锁，当分配规模较小时可添加线程的本地缓冲区，因而性能优于 DlMalloc。

与 Dalvik 相比，ART CMS垃圾回收计划在很多方面都有一定的改善：

- 与Dalvik相比，暂停次数2次减少到1次。Dalvik的第一次暂停主要是为了进行根标记。而在ART中，标记过程是并发进行的，它让线程标记自己的根，然后马上就恢复运行。
- 与Dalvik类似，ART GC在清除过程开始之前也会暂停1次。两者在这方面的主要差异在于：在此暂停期间，某些Dalvik的处理阶段在ART中以并发的方式进行。这些阶段包括 java.lang.ref.Reference处理、系统弱引用清除（例如，jni全局弱引用等）、重新标记非线程根和卡片预清理。在ART暂停期间仍进行的阶段包括扫描脏卡片以及重新标记线程根，这些操作有助于缩短暂停时间。
- 相对于Dalvik，ART GC改进的最后一个方面是粘性 CMS回收器增加了GC吞吐量。不同于普通的分代GC，粘性 CMS 不会移动。年轻对象被保存在一个分配堆栈（基本上是 java.lang. Object 数组）中，而非为其设置一个专用区域。这样可以避免移动所需的对象以维持低暂停次数，但缺点是容易在堆栈中加入大量复杂对象图像而使堆栈变长。

ART GC与Dalvik的另一个主要区别在于 ART GC引入了移动垃圾回收器。使用移动 GC的目的在于通过堆压缩来减少后台应用使用的内存。目前，触发堆压缩的事件是 ActivityManager 进程状态的改变（参见第2章第3节）。当应用转到后台运行时，它会通知ART已进入不再“感知”卡顿的进程状态。此时ART会进行一些操作（例如，压缩和监视器压缩），从而导致应用线程长时间暂停。目前正在使用的两个移动GC是同构空间压缩（Homogeneous Space Compact）和半空间（Semispace Compact）压缩。

- 半空间压缩将对象在两个紧密排列的碰撞指针空间之间进行移动。这种移动 GC 适用于小内存设备，因为它可以比同构空间压缩稍微多节省一点内存。额外节省出的空间主要来自紧密排列的对象，这样可以避免 RosAlloc/DlMalloc 分配器占用开销。由于 CMS 仍在前台使用，且不能从碰撞指针空间中进行收集，因此当应用在前台使用时，半空间还要再进行一次转换。这种情况并不理想，因为它可能引起较长时间的暂停。
- 同构空间压缩通过将对象从一个 RosAlloc 空间复制到另一个 RosAlloc 空间来实现。这有助于通过减少堆碎片来减少内存使用量。这是目前非低内存设备的默认压缩模式。相比半空间压缩，同构空间压缩的主要优势在于应用从后台切换到前台时无需进行堆转换。

## GC 验证和性能选项

你可以采用多种方法来更改ART使用的GC计划。更改前台GC计划的主要方法是更改 `dalvik.vm.gctype` 属性或传递 `-Xgc:` 选项。你可以通过以逗号分隔的格式传递多个 GC 选项。

为了导出可用 `-Xgc` 设置的完整列表，可以键入 `adb shell dalvikvm -help` 来输出各种运行时命令行选项。

以下是将 GC 更改为半空间并打开 GC 前堆验证的一个示例： `adb shell setprop dalvik.vm.gctype SS,preverify`

- `CMS` 这也是默认值，指定并发标记清除 GC 计划。该计划包括运行粘性分代 CMS、部分 CMS 和完整 CMS。该计划的分配器是适用于可移动对象的 RosAlloc 和适用于不可移动对象的 DlMalloc。
- `SS` 指定半空间 GC 计划。该计划有两个适用于可移动对象的半空间和一个适用于不可移动对象的 DlMalloc 空间。可移动对象分配器默认设置为使用原子操作的共享碰撞指针分配器。但是，如果 `-XX:UseTLAB` 标记也被传入，则分配器使用线程局部碰撞指针分配。
- `GSS` 指定分代半空间计划。该计划与半空间计划非常相似，但区别在于其会将存留期较长的对象提升到大型 RosAlloc 空间中。这样就可明显减少典型用例中需复制的对象。

## 内部实现

在ART虚拟机中，很多场景都会触发垃圾回收的执行。ART代码中通过GcCause这个枚举进行描述，包括下面这些事件：

| 常量                            | 说明                                        |
| :------------------------------ | :------------------------------------------ |
| kGcCauseForAlloc                | 内存分配失败                                |
| kGcCauseBackground              | 后台进程的垃圾回收，为了确保内存的充足      |
| kGcCauseExplicit                | 明确的System.gc()调用                       |
| kGcCauseForNativeAlloc          | 由于native的内存分配                        |
| kGcCauseCollectorTransition     | 垃圾收集器发生了切换                        |
| kGcCauseHomogeneousSpaceCompact | 当前景和后台收集器都是CMS时，发生了后台切换 |
| kGcCauseClassLinker             | ClassLinker导致                             |

另外，垃圾回收策略有三种类型：

- Sticky 仅仅释放上次GC之后创建的对象
- Partial 仅仅对应用程序的堆进行垃圾回收，但是不处理Zygote的堆
- Full 会对应用程序和Zygote的堆都会进行垃圾回收

这里Sticky类型的垃圾回收便是基于“分代”的垃圾回收思想，根据IBM的一项研究表明，新生代中的对象有98%是生命周期很短的。所以将新创建的对象单独归为一类来进行GC是一种很高效的做法。

真正负责垃圾回收的逻辑是下面这个方法：

```
// heap.cc

collector::GcType Heap::CollectGarbageInternal(collector::GcType gc_type,
                                               GcCause gc_cause,
                                               bool clear_soft_references)
```

在`CollectGarbageInternal`方法中，会根据当前的GC类型和原因，选择合适的垃圾回收器，然后执行垃圾回收。

ART虚拟机中内置了多个垃圾回收器，包括下面这些：

![img](http://qiangbo-workspace.oss-cn-shanghai.aliyuncs.com/AndroidNewFeatureBook/Chapter3/art_gc_alg.png)

*ART虚拟机中的垃圾回收器*

这里的Compact类型的垃圾回收器便是前面提到“标记-压缩”算法。这种类型的垃圾回收器，会在将对象清理之后，将最终还在使用的内存空间移动到一起，这样可以既可以减少堆中的碎片，也节省了堆空间。但是由于这种垃圾回收器需要对内存进行移动，所以耗时较多，因此这种垃圾回收器适合于切换到后台的应用。

前面我们提到过：垃圾收集器会在Heap的构造函数中被创建，然后添加到`garbage_collectors_`列表中。

尽管各种垃圾回收器算法不一定，但它们都包含相同的垃圾回收步骤，垃圾回收器的回收过程主要包括下面四个步骤：

![img](http://qiangbo-workspace.oss-cn-shanghai.aliyuncs.com/AndroidNewFeatureBook/Chapter3/gc_phase.png)

*垃圾回收的四个阶段*

所以，想要深入明白每个垃圾回收器的算法细节，只要按照这个逻辑来理解即可。

# JIT的回归

前面我们提到：在Android 5.0上，系统在安装APK时会直接将dex文件中的代码编译成机器码。我们应该知道，编译的过程是比较耗时的。因此，用过Android 5.0的用户应该都会感觉到，在这个版本上安装应用程序明显比之前要慢了很多。

编译一个应用程序已经比较耗时，但如果系统中所有的应用都要重新编译一遍，那等待时间将是难以忍受的。但不幸的事，这样的事情却刚好发生了，相信用过Android 5.0的Nexus用户都看到过这样一个画面：

![img](http://qiangbo-workspace.oss-cn-shanghai.aliyuncs.com/AndroidNewFeatureBook/Chapter3/android-phone-system-update.jpg)

*Android 5.0的启动画面*

之所以发生这个问题，是因为：

- 应用程序编译生成的OAT文件会引用Framework中的代码。一旦系统发生升级，Framework中的实现发生变化，就需要重新修正所有应用程序的OAT文件，使得它们的引用是正确的，这就需要重新编译所有的应用
- 出于系统的安全性考虑，自2015年8月开始，Nexus设备每个月都会收到一次安全更新

要让用户每个月都要忍受一次这么长的等待时间，显然是不能接受的。

由此我们看到，单纯的AOT编译存在如下两个问题：

- 应用安装时间过长
- 系统升级时，所有应用都需要重新编译

其实这里还有另外一个问题，我们也应该能想到：编译生成的Oat文件中，既包含了原先的Dex文件，又包含了编译后的机器代码。而实际上，对于用户来说，并非会用到应用程序中的所有功能，因此很多时候编译生成的机器码是一直用不到的。一份数据存在两份结果（尽管它们的格式是不一样的）显然是一种存储空间的浪费。

因此，为了解决上面提到的这些问题，在 Android 7.0 中，Google又为Android添加了即时 (JIT) 编译器。JIT和AOT的配合，是取两者之长，避两者之短：在APK安装时，并不是一次性将所有代码全部编译成机器码。而是在实际运行过程中，对代码进行分析，将热点代码编译成机器码，让它可以在应用运行时持续提升 Android 应用的性能。

JIT编译器补充了ART当前的预先(AOT)编译器的功能，有助于提高运行时性能，节省存储空间，以及加快应用及系统更新速度。相较于 AOT编译器，JIT编译器的优势也更为明显，因为它不会在应用自动更新期间或重新编译应用（在无线下载 (OTA) 更新期间）时拖慢系统速度。

尽管JIT和AOT使用相同的编译器，它们所进行的一系列优化也较为相似，但它们生成的代码可能会有所不同。JIT会利用运行时类型信息，可以更高效地进行内联，并可让堆栈替换 (On Stack Replacement) 编译成为可能，而这一切都会使其生成的代码略有不同。

JIT的运行流程如下：

![img](http://qiangbo-workspace.oss-cn-shanghai.aliyuncs.com/AndroidNewFeatureBook/Chapter3/jit-architecture.png)

*JIT的运行流程*

1. 用户运行应用，而这随后就会触发 ART 加载 .dex 文件。
   - 如果有 .oat 文件（即 .dex 文件的 AOT 二进制文件），则 ART 会直接使用该文件。虽然 .oat 文件会定期生成，但文件中不一定会包含经过编译的代码（即 AOT 二进制文件）。
   - 如果没有 .oat 文件，则 ART 会通过 JIT 或解释器执行 .dex 文件。如果有 .oat 文件，ART 将一律使用这类文件。否则，它将在内存中使用并解压 APK 文件，从而得到 .dex 文件，但是这会导致消耗大量内存（相当于 dex 文件的大小）。
2. 针对任何未根据speed编译过滤器编译（见下文）的应用启用JIT（也就是说，要尽可能多地编译应用中的代码）。
3. 将 JIT 配置文件数据转存到只限应用访问的系统目录内的文件中。
4. AOT 编译 (dex2oat) 守护进程通过解析该文件来推进其编译。

## 控制JIT日志记录

要开启 JIT 日志记录，请运行以下命令：

```
adb root
adb shell stop
adb shell setprop dalvik.vm.extra-opts -verbose:jit
adb shell start
```

要停用 JIT，请运行以下命令：

```
adb root
adb shell stop
adb shell setprop dalvik.vm.usejit false
adb shell start
```

# ART虚拟机的演进与配置

从Android 7.0开始，ART组合使用了AOT和JIT。并且这两者是可以单独配置的。例如，在Pixel设备上，相应的配置如下：

1. 最初在安装应用程序的时候不执行任何AOT编译。应用程序运行的前几次都将使用解释模式，并且经常执行的方法将被JIT编译。
2. 当设备处于空闲状态并正在充电时，编译守护进程会根据第一次运行期间生成的Profile文件对常用代码运行AOT编译。
3. 应用程序的下一次重新启动将使用Profile文件引导的代码，并避免在运行时为已编译的方法进行JIT编译。在新运行期间得到JIT编译的方法将被添加到Profile文件中，然后被编译守护进程使用。

在应用程序安装时，APK文件会传递给`dex2oat`工具，该工具会为根据APK文件生成一个或多个编译产物，这些产物文件名和扩展名可能会在不同版本之间发生变化，但从Android 8.0版本开始，生成的文件是：

- `.vdex`：包含APK的未压缩Dex代码，以及一些额外的元数据用来加速验证。
- `.odex`：包含APK中方法的AOT编译代码。（注意，虽然Dalvik虚拟机时代也会生成odex文件，但和这里的odex文件仅仅是后缀一样，文件内容已经完全不同了）
- `.art`（可选）：包含APK中列出的一些字符串和类的ART内部表示，用于加速应用程序的启动。

ART虚拟机在演进过程中，提供了很多的配置参数供系统调优，关于这部分内容，请参见这里：[AOSP：配置 ART](https://source.android.google.cn/devices/tech/dalvik/configure) 。

# 参考资料与推荐读物

- [AOSP: 实现 ART JIT编译器](https://source.android.com/devices/tech/dalvik/jit-compiler.html)
- [AOSP: 配置 ART](https://source.android.com/devices/tech/dalvik/configure)
- [Improving Stability with Private C/C++ Symbol Restrictions in Android N](https://android-developers.googleblog.com/2016/06/improving-stability-with-private-cc.html)
- [Google I/O 2014 - The ART runtime](https://www.youtube.com/watch?v=EBlTzQsUoOw&t=450s)
- [The Evolution of ART - Google I/O 2016](https://www.youtube.com/watch?v=fwMM6g7wpQ8&t=9s)
- [维基百科: Executable and Linkable Format](https://en.wikipedia.org/wiki/Executable_and_Linkable_Format)
- [罗升阳：Android运行时ART简要介绍和学习计划](http://blog.csdn.net/luoshengyang/article/details/39256813)
- [LLVM](http://www.aosabook.org/en/llvm.html)
- [PDF: Dalvik and ART](https://qiangbo-workspace.oss-cn-shanghai.aliyuncs.com/2018-10-07-android-art-vm/Andevcon-ART.pdf)
- [PDF: Hiding Behind ART](https://qiangbo-workspace.oss-cn-shanghai.aliyuncs.com/2018-10-07-android-art-vm/asia-15-Sabanal-Hiding-Behind-ART-wp.pdf)
- [PDF: State Of The ART](https://qiangbo-workspace.oss-cn-shanghai.aliyuncs.com/2018-10-07-android-art-vm/D1T2-State-of-the-Art-Exploring-the-New-Android-KitKat-Runtime.pdf)
- [《程序员的自我修养:链接、装载与库》](https://www.amazon.cn/dp/B0027VSA7U)

### 1.bugreport
> java –jar chkbugreport.jar bugreport.txt

脚本
> chkbugreport.sh bugreportxxx.txt

[ChkBugReport](https://github.com/sonyxperiadev/ChkBugReport/wiki)

[bugreport实战篇](http://gityuan.com/2016/06/11/bugreport-2/)


---
### 2.simpleperf
[simpleperf](https://developer.android.com/ndk/guides/simpleperf)
---


### 3. MAT
命令行提取hprof文件

1. adb shell am dumpheap <processname> <FileName>
2. adb pull <FileName> <Dir>
3. /android-sdk/platform-tools/hprof-conv <FileName> <newFileName>.hprof
4. 使用MAT分析


```
Error opening heap dump 'memory-20190216T171338.hprof'. Check the error log for further details. Error opening heap dump 'memory-20190216T171338.hprof'. Check the error log for further details. Unknown HPROF Version (JAVA PROFILE 1.0.3) (java.io.IOException) Unknown HPROF Version (JAVA PROFILE 1.0.3)

```
出现这个错误是因为Android导出的hprof文件格式与标准的JAVA hprof格式不一样，根本原因是虚拟机不一样造成的，在导入MAT前需要用AndroidSDK/tools/hprof-conf.exe进行转换： 例如：



```
 /Users/tracyliu/Library/Android/sdk/platform-tools/hprof-conv memory-20200618T145927.hprof settings_memory.hprof
```





#### 使用MAT：

1. 在使用MAT之前，先使用as的Profile中的Memory去获取要分析的堆内存快照文件.hprof，如果要测试某个页面是否产生内存泄漏，可以先dump出没进入该页面的内存快照文件.hprof，然后，通常执行5次进入/退出该页面，然后再dump出此刻的内存快照文件.hprof，最后，将两者比较，如果内存相除明显，则可能发生内存泄露。（注意:MAT需要标准的.hprof文件，因此在as的Profiler中GC后dump出的内存快照文件.hprof必须手动使用android sdk platform-tools下的hprof-conv程序进行转换才能被MAT打开）

2. 然后，使用MAT打开前面保存的2份.hprof文件，打开Overview界面，在Overview界面下面有4中action，其中最常用的就是Histogram和Dominator Tree。

- Dominator Tree：支配树，按对象大小降序列出对象和其所引用的对象，注重引用关系分析。选择Group by package，找到当前要检测的类（或者使用顶部的Regex直接搜索），查看它的Object数目是否正确，如果多了，则判断发生了内存泄露。然后，右击该类，选择Merge Shortest Paths to GC Root中的exclude all phantom/weak/soft etc.references选项来查看该类的GC强引用链。最后，通过引用链即可看到最终强引用该类的对象。

- Histogram：直方图注重量的分析。使用方式与Dominator Tree类似。

3. 对比hprof文件，检测出复杂情况下的内存泄露：

##### 通用对比方式：


在Navigation History下面选择想要对比的dominator_tree/histogram，右击选择Add to Compare Basket，然后在Compare Basket一栏中点击红色感叹号（Compare the results）生成对比表格（Compared Tables），在顶部Regex输入要检测的类，查看引用关系或对象数量去进行分析即可



##### 针对于Historam的快速对比方式：
直接选择Histogram上方的Compare to another Heap Dump选择要比较的hprof文件的Historam即可。



---

### 4.打印trace

1. cat proc/[pid]/stack ==> 查看kernel调用栈
2. debuggerd -b [pid] ==> 也不可以不带参数-b, 则直接输出到/data/tombstones/目录
3. kill -3 [pid] ==> 收集指定进程的trace 生成/data/anr/traces.txt文件
4. lsof [pid] ==> 查看进程所打开的文件

[java trace文件解读](http://gityuan.com/2016/11/26/art-trace/)


---
### 5.GDB


[gdb调试 native crash](http://gityuan.com/2017/09/09/gdb/)

---
### 6.addr2line

[介绍addr2line调试命令](http://gityuan.com/2017/09/02/addr2line/)

---

### 7.Profiler

使用AndroidProfiler的MEMORY工具：

运行程序，对每一个页面进行内存分析检查。首先，反复打开关闭页面5次，然后收到GC（点击Profile MEMORY左上角的垃圾桶图标），如果此时total内存还没有恢复到之前的数值，则可能发生了内存泄露。此时，再点击Profile MEMORY左上角的垃圾桶图标旁的heap dump按钮查看当前的内存堆栈情况，选择按包名查找，找到当前测试的Activity，如果引用了多个实例，则表明发生了内存泄露。

[探索 Android Studio](https://developer.android.google.cn/studio/intro?hl=zh_cn)



[利用 Android Profiler 测量应用性能](https://developer.android.google.cn/studio/profile/android-profiler?hl=zh_cn)

> 要打开 Profiler 窗口，请依次选择 View > Tool Windows > Profiler，

[使用 CPU Profiler 检查 CPU 活动](https://developer.android.google.cn/studio/profile/cpu-profiler.html?hl=zh_cn)



#### 使用 Debug API 记录 CPU 活动

```
  Debug.startMethodTracing("OkayDock" );
  Debug.stopMethodTracing();
```

##### trace文件生成位置
```
/sdcard/Android/data/com.okay.dock/files/OkayDock.trace
```
可以直接用AS打开

[使用 Memory Profiler 查看 Java 堆和内存分配](https://developer.android.google.cn/studio/profile/memory-profiler.html?hl=zh_cn#save-hprof)

[使用 Network Profiler 检查网络流量](https://developer.android.google.cn/studio/profile/network-profiler.html?hl=zh_cn)

[使用 Energy Profiler 检查耗电量](https://developer.android.google.cn/studio/profile/energy-profiler.html?hl=zh_cn)

---
### 8.Systrace 
> /Users/tracyliu/Library/Android/sdk/platform-tools/systrace


[在命令行上捕获系统跟踪信息](https://developer.android.google.cn/studio/profile/systrace/command-line?hl=zh_cn)
[Systrace 概览](https://developer.android.google.cn/studio/profile/systrace)
[了解 Systrace](https://source.android.google.cn/devices/tech/debug/systrace)

[面试Tip之Android优化工具Systrace](https://juejin.im/post/5b3cce09e51d45198651069f#heading-12)
```
在进程的上面有一条很细的进度条，包含了该线程的状态：
　　灰色： 睡眠。
　　蓝色： 可以运行（它可以运行，但还未被调度运行）。
　　绿色： 正在运行（调度程序认为它正在运行）。
　　红色： 不间断的睡眠（通常发生在内核锁上）， 指出I / O负载，对于性能问题的调试非常有用
　　橙色： 由于I / O负载导致的不间断睡眠。
　　要查看不间断睡眠的原因（可从sched_blocked_reason跟踪点获取），请选择红色不间断睡眠切片。
```


```
按键操作       作用
w             放大，[+shift]速度更快
s             缩小，[+shift]速度更快
a             左移，[+shift]速度更快
d             右移，[+shift]速度更快

f             放大当前选定区域
m             标记当前选定区域
v             高亮VSync
g             切换是否显示60hz的网格线
            恢复trace到初始态，这里是数字0而非字母o

h             切换是否显示详情
/             搜索关键字
enter　　　　　　显示搜索结果，可通过← →定位搜索结果
`             显示/隐藏脚本控制台
?             显示帮助功能
```



```
./systrace.py -t 10 sched gfx view wm am app webview -a com.okay.dock
```
[性能工具Systrace](http://gityuan.com/2016/01/17/systrace/)


---

### 9.Uiautomatorviewer

> open /Users/tracyliu/Library/Android/sdk/tools/bin/uiautomatorviewer
---

### 10.反编译


#### jadx 

> jadx-gui

> jadx 

#### Apktool
https://ibotpeaches.github.io/Apktool/install/

> apktool d xxx.apk
```
1. 将下载好的apktool文件与apktool_2.3.1.jar文件准备好，并将apktool_2.3.1.jar更名为apktool.jar；
2. 将apktool.jar与apktool移动到/usr/local/bin目录下(可以通过在终端中输出命令open /usr/local/bin来打开这个目录)；
3. 为上述两个文件增加可执行权限，即在终端中输入并执行：
 chmod +x apktool.jar
 chmod +x apktool
4. 在终端输入apktool看是否可以运行，如果不可以需要在系统偏好设置中打开安全与隐私中点击仍要运行apktool.jar；
```
#### dex2jar
https://sourceforge.net/projects/dex2jar/files/

---

### 11.DDMS
Android Studio 3.0开始 DDMS弃用

可以在
>SDK/tools/monitor双击打开DDMS



---



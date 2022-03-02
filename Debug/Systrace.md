### Systrace抓取、分析







cd Users/tracyliu/Library/Android/sdk/platform-tools/systrace

Python2.7 Users/tracyliu/Library/Android/sdk/platform-tools/systrace/systrace.py -t 10 sched gfx view wm am app webview -a com.android.settings 



 systrace.py -t 10 -o /Users/tracyliu/Desktop/setting_trace.html sched gfx view wm am app webview -a com.android.settings 



./systrace.py -t 10 sched gfx view wm am app webview -a





#### 1.图形化DDMS抓取

>  open /Users/tracyliu/Library/Android/sdk/tools/monitor

#### 1.2命令行抓取



> python systrace.py [options] [categories]

>  systrace.py -t 10 -o /Users/tracyliu/Desktop/setting_trace.html sched gfx view wm am app webview -a com.android.settings

##### options可取值：

| options                                    | 解释                                                         |
| ------------------------------------------ | :----------------------------------------------------------- |
| -o <FILE>                                  | 指定trace数据文件的输出路径，如果不指定就是当前目录的trace.html |
| -t N, –time=N                              | 执行时间，默认5s。绝对不要把时间设的太短导致你操作没完Trace就跑完了，这样会出现Did not finish 的标签，分析数据就基本无效了 |
| -b N, –buf-size=N                          | buffer大小（单位kB),用于限制trace总大小，默认无上限          |
| -k <KFUNCS>，–ktrace=<KFUNCS>              | 追踪kernel函数，用逗号分隔                                   |
| -a <APP_NAME>,–app=<APP_NAME>              | 这个选项可以开启指定包名App中自定义Trace Label的Trace功能。也就是说，如果你在代码中使用了Trace.beginSection("tag"), Trace.endSection；默认情况下，你的这些代码是不会生效的，因此，这个选项一定要开启 |
| –from-file=<FROM_FILE>                     | 从文件中创建互动的systrace                                   |
| -e <DEVICE_SERIAL>,–serial=<DEVICE_SERIAL> | 指定设备，在特定连接设备上进行跟踪，由[设备序列号](https://developer.android.com/studio/command-line/adb.html#devicestatus)标识 。 |
| -l, –list-categories                       | 这个用来列出你分析的那个手机系统支持的Trace模块，一般来说，高版本的支持的模块更多 |

##### category可取值：

| category      |                             解释                             |
| ------------- | :----------------------------------------------------------: |
| gfx           | Graphic系统的相关信息，包括SerfaceFlinger，VSYNC消息，Texture，RenderThread等；分析卡顿非常依赖这个。 |
| input         |                            Input                             |
| view          |    View绘制系统的相关信息，比如onMeasure，onLayout等。。     |
| webview       |                           WebView                            |
| wm            |                        Window Manager                        |
| am            | ActivityManager调用的相关信息；用来分析Activity的启动过程比较有效。 |
| sm            |                         Sync Manager                         |
| audio         |                            Audio                             |
| video         |                            Video                             |
| camera        |                            Camera                            |
| hal           |                       Hardware Modules                       |
| app           |                         Application                          |
| res           |                       Resource Loading                       |
| dalvik        |                虚拟机相关信息，比如GC停顿等。                |
| rs            |                         RenderScript                         |
| bionic        |                       Bionic C Library                       |
| power         |                       Power Management                       |
| sched         | CPU调度的信息，非常重要；你能看到CPU在每个时间段在运行什么线程；线程调度情况，比如锁信息。 |
| binder_driver | Binder驱动的相关信息，如果你怀疑是Binder IPC的问题，不妨打开这个。 |
| core_services |  SystemServer中系统核心Service的相关信息，分析特定问题用。   |
| irq           |                          IRQ Events                          |
| freq          |                        CPU Frequency                         |
| idle          |                           CPU Idle                           |
| disk          |                           Disk I/O                           |
| mmc           |                        eMMC commands                         |
| load          |                           CPU Load                           |
| sync          |                       Synchronization                        |
| workq         |                      Kernel Workqueues                       |
| memreclaim    |                    Kernel Memory Reclaim                     |
| regulators    |                Voltage and Current Regulators                |



#### 1.3离线抓取 Systrace

1. 输入指令：adb root && adb remount

2. 输入以下指令开始后台抓取systrace，此时可以断开usb连接线去复现问题：

> ```
> adb shell "atrace -z -b 40000 gfx input view wm am camera hal res dalvik rs sched freq idle disk mmc -t 15 > /data/local/tmp/trace_output &"
> ```



3. 复现问题后，重新连接usb线输入如下指令，确认atrace进程是否结束抓取并退出：

> adb shell ps -A | grep atrace

4. 抓取完成后，取出生成的trace文件，并转换成html格式：

```
adb pull /data/local/tmp/trace_output
systrace.py --from-file trace_output -o output.html
```



#### 2.trace.html分析

**灰色**： 睡眠。
**蓝色**： 可以运行（它可以运行，但还未被调度运行）。
**绿色**： 正在运行（调度程序认为它正在运行）。
**红色**： 不间断的睡眠（通常发生在内核锁上）， 指出I / O负载，对于性能问题的调试非常有用
**橙色**： 由于I / O负载导致的不间断睡眠。
要查看不间断睡眠的原因（可从sched_blocked_reason跟踪点获取），请选择红色不间断睡眠切片。

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
0             恢复trace到初始态，这里是数字0而非字母o

h             切换是否显示详情
/             搜索关键字
enter　　　　　　显示搜索结果，可通过← →定位搜索结果
`             显示/隐藏脚本控制台
?             显示帮助功能
```





---

[Android：通过systrace进行性能分析](https://www.cnblogs.com/blogs-of-lxl/p/10926824.html)












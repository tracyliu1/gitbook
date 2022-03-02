### ADB 调试命令





#####  权限

>  adb shell appops set com.android.toofifi SYSTEM_ALERT_WINDOW allow

>  **adb shell pm grant** 包名 **android.permission.SYSTEM_ALERT_WINDOW**

> **adb shell appops set com.xxx.packagename SYSTEM_ALERT_WINDOW allow**



##### Monkey

>  adb shell monkey -p com.android.settings --throttle 1000 -s 100 --pct-touch 5 --monitor-native-crashes -v -v 20000000’



##### Kernel Log

>  adb shell cat /proc/kmsg > kernel.log



##### 强制GC

> adb shell kill -10 PIDXXX



##### 强制生成进程的内存镜像

> adb shell am dumpheap PIDxxx /data/xxx.hprof



##### 在events log中实时打印cpu信息。

```
$ adb logcat -b events | grep cpu
   I/cpu     (  743): [16,4,12,0,0,0]
   I/cpu     (  743): [15,2,13,0,0,0]
   I/cpu     (  743): [16,2,14,0,0,0]

   数字都是百分比，分别为：[total, user, system, iouat, irq, softlrq]``
```





**强制dump某个进程的内存镜像**

```
# 1044是Launcher的pid
$ adb shell am dumpheap 1044 /data/aa.hprof
```





```
adb shell dumpsys SurfaceFlinger | grep "Layer\|z="
adb shell dumpsys activity processes   进程信息 trimmemory
adb shell dumpsys activity intents
adb shell dumpsys activity oom
adb shell dumpsys input | grep Focus   查看焦点窗口
```

adb logcat -v threadtime|tee logcat.txt| grep "vold.cy"



adb logcat -v thread time -s Audio audio.txt

grep vold.decrypt . -rni



android 主线程栈默认大小可以通过输入 adb shell “ulimit -s” 查看（6.0为8M）














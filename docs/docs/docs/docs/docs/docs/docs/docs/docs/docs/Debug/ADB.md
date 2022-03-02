### ADB 调试命令



adb shell appops set com.android.toofifi SYSTEM_ALERT_WINDOW allow



**adb shell pm grant** 包名 **android.permission.SYSTEM_ALERT_WINDOW**

**adb shell appops set com.xxx.packagename SYSTEM_ALERT_WINDOW allow**





adb shell monkey -p com.android.settings --throttle 1000 -s 100 --pct-touch 5 --monitor-native-crashes -v -v 20000000’





禁用自动旋转：

adb shell content insert --uri content://settings/system --bind name:s:accelerometer_rotation --bind value:i:0



设置横屏

adb shell content insert --uri content://settings/system --bind name:s:user_rotation --bind value:i:1



设置竖屏

adb shell content insert --uri content://settings/system --bind name:s:user_rotation --bind value:i:0







**adb shell pm disable com.okayprovision.splash/.pages.welcome.WelcomeNewActivity;adb shell pm disable com.okayprovision.splash/.okProvisionMainActivity;adb shell pm disable com.okayprovision.splash/.pages.ContentNewActivity;adb shell pm disable com.okayprovision.splash/.common.PlayService;**







adb logcat -v threadtime|tee logcat.txt| grep "vold.cy"



adb logcat -v thread time -s Audio audio.txt

grep vold.decrypt . -rni





cd Users/tracyliu/Library/Android/sdk/platform-tools/systrace

Python2.7 Users/tracyliu/Library/Android/sdk/platform-tools/systrace/systrace.py -t 10 sched gfx view wm am app webview -a com.android.settings 



 systrace.py -t 10 -o /Users/tracyliu/Desktop/setting_trace.html sched gfx view wm am app webview -a com.android.settings 



./systrace.py -t 10 sched gfx view wm am app webview -a



hexo new “HelloWorld”

hexo s

hexo clean && hexo g && hexo d



1、Android系统应用优化，如应用的启动时间和运行流畅度

2、Android 系统底层优化，包括 Framework/HAL/Kernel/filesystem/Network等

3、监控系统性能，监督系统性能状况，发现和分析监控数据中可能的优化点





# ubuntu下压缩android开机动画

这个zip文件必须在ubuntu下使用下面指令：

```
 zip -Z store bootanimation.zip part0/*.png part1/*.png desc.txt
```

windows下zip或者ubuntu下UI压缩都不行。



du -h --max-depth=1



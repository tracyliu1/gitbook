## 使用dumpsys gfxinfo 



> adb shell dumpsys gfxinfo < PACKAGE_NAME >



```
Applications Graphics Acceleration Info:
Uptime: 144349605 Realtime: 361557144

** Graphics info for pid 2660 [com.android.settings] **

Stats since: 80957458978ns
Total frames rendered: 23 //本次收集23帧
Janky frames: 17 (73.91%) //17帧超过16.6ms 占73.19%
50th percentile: 22ms
90th percentile: 200ms
95th percentile: 450ms
99th percentile: 600ms
Number Missed Vsync: 7 //垂直同步失败的帧数
Number High input latency: 0 //input超时的帧数
Number Slow UI thread: 11 //因UI线程上的工作导致超时的帧数
Number Slow bitmap uploads: 0 //因bitmap的加载耗时的帧数
Number Slow issue draw commands: 12  //因绘制导致耗时的帧数

HISTOGRAM: 5ms=0 6ms=0 7ms=0 8ms=0 9ms=0 10ms=0 11ms=0 12ms=2 13ms=0 14ms=2 15ms=1 16ms=1 17ms=1 18ms=1 19ms=2 20ms=0 21ms=1 22ms=2 23ms=0 24ms=0 25ms=0 26ms=0 27ms=0 28ms=0 29ms=0 30ms=1 31ms=0 32ms=0 34ms=0 36ms=0 38ms=0 40ms=0 42ms=0 44ms=1 46ms=0 48ms=0 53ms=1 57ms=1 61ms=1 65ms=0 69ms=0 73ms=1 77ms=0 81ms=0 85ms=0 89ms=0 93ms=0 97ms=0 101ms=0 105ms=0 109ms=0 113ms=0 117ms=0 121ms=0 125ms=0 129ms=0 133ms=1 150ms=0 200ms=1 250ms=0 300ms=0 350ms=0 400ms=0 450ms=1 500ms=0 550ms=0 600ms=1 650ms=0 700ms=0 750ms=0 800ms=0 850ms=0 900ms=0 950ms=0 1000ms=0 1050ms=0 1100ms=0 1150ms=0 1200ms=0 1250ms=0 1300ms=0 1350ms=0 1400ms=0 1450ms=0 1500ms=0 1550ms=0 1600ms=0 1650ms=0 1700ms=0 1750ms=0 1800ms=0 1850ms=0 1900ms=0 1950ms=0 2000ms=0 2050ms=0 2100ms=0 2150ms=0 2200ms=0 2250ms=0 2300ms=0 2350ms=0 2400ms=0 2450ms=0 2500ms=0 2550ms=0 2600ms=0 2650ms=0 2700ms=0 2750ms=0 2800ms=0 2850ms=0 2900ms=0 2950ms=0 3000ms=0 3050ms=0 3100ms=0 3150ms=0 3200ms=0 3250ms=0 3300ms=0 3350ms=0 3400ms=0 3450ms=0 3500ms=0 3550ms=0 3600ms=0 3650ms=0 3700ms=0 3750ms=0 3800ms=0 3850ms=0 3900ms=0 3950ms=0 4000ms=0 4050ms=0 4100ms=0 4150ms=0 4200ms=0 4250ms=0 4300ms=0 4350ms=0 4400ms=0 4450ms=0 4500ms=0 4550ms=0 4600ms=0 4650ms=0 4700ms=0 4750ms=0 4800ms=0 4850ms=0 4900ms=0 4950ms=0
//分别展示耗时区间的帧数

Caches:
Current memory usage / total memory usage (bytes):
  TextureCache           148676 / 75497472
  LayerCache                  0 / 50331648 (numLayers = 0)
  Layers total          0 (numLayers = 0)
  RenderBufferCache           0 /  8388608
  GradientCache               0 /  1048576
  PathCache              802500 / 33554432
  TessellationCache        6840 /  1048576
  TextDropShadowCache         0 /  6291456
  PatchCache                  0 /   131072
  FontRenderer A8         74091 /  1048576
    A8   texture 0        74091 /  1048576
  FontRenderer RGBA           0 /        0
  FontRenderer total      74091 /  1048576
Other:
  FboCache                    0 /        0
Total memory usage:
  2006592 bytes, 1.91 MB


Pipeline=FrameBuilder
Profile data in ms:

	com.android.settings/com.android.settings.main.SettingsActivity/android.view.ViewRootImpl@e1cbebf (visibility=0)
View hierarchy:

  com.android.settings/com.android.settings.main.SettingsActivity/android.view.ViewRootImpl@e1cbebf
  205 views, 270.31 kB of display lists


Total ViewRootImpl: 1
Total Views:        205
Total DisplayList:  270.31 kB
```



### 精确的帧时间信息

> adb shell dumpsys gfxinfo com.android.settings framestats

framestats，该命令会根据最近的帧提供非常详细的帧时间信息，让您能够更准确地查出并调试问题

该命令会从应用生成的最近 120 个帧中输出带有纳秒时间戳的帧时间信息。每行输出均代表应用生成的一帧。每行都有固定的列数，描述帧生成管道的每个阶段所花的时间。下文将详细描述此格式，包括每列代表的具体内容。







---

[当我们讨论流畅度的时候，我们究竟在说什么？](https://toutiao.io/posts/ipz7lf/preview)

[测试界面性能](https://developer.android.com/training/testing/performance.html)




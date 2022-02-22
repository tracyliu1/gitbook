### Android 系统分区结构



- bootloader分区

  系统加载器 相当于bios 通常厂商进行加密 仅能引导相应固件

- boot分区

  存储boot.image 其中包括linux kernel initrd等文件

- Splash分区

  开机图片 动画

- radio分区

​       基带所在分区  存储通信质量相关的驱动，常用驱动存在于linux内核boot分区

- recovery分区

  mini Android boot镜像  用来做系统恢复 故障维修

- System 分区 

  存储系统镜像文件包括framework libraries 以及预装应用 即/system 目录

- User Data分区

   内部存储分区  即挂载后 /data目录

- Cache分区

  存储 日志 ota更新包等 cache



### Android 系统启动



- bootloader加载阶段
- boot分区加载kernel initrd到ram  跳转kernel
- 初始化设备服务  启动init
- 加载系统服务  启动adbd vold zygote servicemanager等
- 虚拟机初始化  startVM 启动framework服务
- 启动完成 发送boot_complete广播



![image-20210520104841402](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210520104841402.png)





### init进程 

pid = 1  0号是kernel

解析init.rc脚本

初始化属性服务 property servcie

for循环 建立子进程 对关键服务进行重启和异常处理



init.rc脚本

启动系统开启service和deamons

指定不同的service在不同的用户或者用户组运行

修改设置全局的属性服务

注册一些动作和命令在特定的时间执行



### Vold

Volume Daemon 存储类守护进程 负责CDROM USB MMC 存储挂载任务。



#### 处理过程

##### 创建链接

vold一方面接收驱动信息，将信息传给应用层，另一方面接受上层命令完成相应功能。

- vold socket：负责vold与应用层信息传递
- 访问udev的socket：负责vold与底层信息传递

##### 引导

vold启动时，对现有外设存储设备处理。首先加载vold.conf,并检查挂载点是否被挂载，执行mmc卡挂载，最后处理usb大容量存储

##### 事件处理

通过对两个链接舰艇，完成对动态事件的处理



### servicemanager

- 打开dev/binder 并在内存映射128kb的空间
- 通知bidner设备，把自己变成context_manager
- 循环读取binder设备，如果有对service的请求，就去调用svcmgr_handler函数回调处理请求1



![image-20210520113322666](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210520113322666.png)
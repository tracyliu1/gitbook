

系统在启动的时候，会先去执行BootLoader中的代码，判断按键是否按下，来进入不同的启动模式，如果案件没有按下的话再去读取MISC分区中BCB的值，来进入相应标志位标志的启动模式。

![image-20210326141210393](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210326141210393.png)

![image-20210326141030487](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210326141030487.png)





### ***\*Android OTA升级流程\****

### 	

![img](file:////private/var/folders/q8/w266cmnj7z9cpy_j23367j000000gn/T/com.kingsoft.wpsoffice.mac/wps-tracyliu/ksohtml/wpsQ0UlAs.jpg) 

\1. 获取update.zip文件

2.验证签名文件

3.通过installPackage接口升级

4.系统重新启动进入recovery界面（判断/cache/recovery 是否有cmd文件）

5.try_update_binary执行升级脚本

6.finish_recovery 重启

具体升级流程的介绍参考如下网站：https://blog.csdn.net/dingfengnupt88/article/details/52875228





boot.img 包含一个linux kernel （maybe named as zImage）和一个ramdisk。img文件结构在源码system/core/mkbootimg/bootimg.h中声明

uboot.img android启动时第一个加载的镜像，初始化硬件和基本输入出系统。

 

所以一般flash到android设备中的img一般是这几个：uboot.img,boot.img,recovery.img,userdata.img,system.img

system提取以及打包方法：

提取：adb pull system $dst_dir

即可将system.img解包提取到本地，

貌似GB的版本system.img用的文件系统为yaffs,可以使用mkyaffs（android自带） 生成system.img 解包可以使用网友自制的unyaffs解包。

ICS版本system.img使用的是ext4文件系统，可以使用android自带的mk_ext4fs工具打包system.img,目前网上对于ICS版本的讨论较少，并没有找到解包工具

 

ramdisk提取以及打包方法：

提取：由于ramdisk各个设备商打包方法略有不同，所以不推荐直接从设备中提取，最好还是找一个官方ramdisk，分析下结构。再做提取修改打包动作。

打包（android默认）：mkbootimgfs $root_dir | gzip > ramdisk.img

因此ramdisk.img是一个gzip的压缩包，里面有个ramdisk的镜像

由于不同厂商打包方式有所不同，比如MTK会把gzip的压缩包外面再加一个文件头（虽然不知道是什么，不过好像很厉害的样子），很多厂商也会加个头。不过可以根据gzip的文件格式从加壳的ramdisk中将gzip提取出来，修改后，再把gzip放回去。

因此ramdisk的修改会比较麻烦。改得不好，则无法开机。

 

boot.img打包解包方法：

解包：可以根据bootimg.h文件头格式，可以自己编个程序解包，也可以使用已有的工具进行解析：

split-bootimg.pl是一个国外网友自制的boot.img解包工具。解包后生成$bootimg_name-kernel.img 和 $bootimg_name-ramdisk.gz

打包：mkbootimg --kernel $kernelimg --ramdisk $ramdiskimg --kernel_base $kernel_base --page_size $page_size --cmd_line $cmd -o $out_image

--kernel --ramdisk 指定kernel ramdisk镜像

--kernel_base --page_size 【可选】指定kernel基址和页大小，如果有源码可以查看BoardConfig.mk

--cmd_line 指定一条命令，可以在开机的时候执行。

-o 输出镜像名字

 

boot.img一般不要轻易换，很容易造成不开机，一定要注意备份。。

不开机的几种原因：

kernel_base错了，uboot找不到kernel的引导程序。

ramdisk解包错误，无法建立文件系统

 

android开机过程：

上电，加载uboot，初始化硬件

加载boot.img，加载linux内核，建立文件系统。

根据启动模式，决定是正常启动、recovery_mode factory_mode。

加载recovery.img或者system.img







***\*Android系统OTA原理\****

Recovery的工作需要整个软件平台的配合，从通信架构上来看，主要有三个部分：

1、MainSystem：即上面提到的正常启动模式（无有效按键按下，BCB中无命令），是用boot.img启动的系统，更新时，在这种模式中我们的上层操作就是使用OTA或从SD卡中拿到update.zip包。在重启进入Recovery模式之前，会向BCB中写入命令，以便在重启后告诉bootloader进入Recovery模式。

2、Recovery：系统进入Recovery模式后会装载Recovery分区，该分区包含recovery.img（同boot.img相同，包含了标准的内核和根文件系统）。进入该模式后主要是运行Recovery服务（/sbin/recovery）来做相应的操作（重启、升级update.zip、擦除cache分区等）。

3、Bootloader：先做一些初始化，然后根据组合键做不同的事情，如果没有按键按下会读取位于MISC分区的启动控制信息块BCB（Bootloader Control Block）中的标志位获得来至Main system和Recovery的消息，判断进入Fastboot、Recovery还是正常启动系统。这个过程内核没有加载，机器知识在按顺序执行指令。 除了正常的加载启动系统之外，还会通过读取MISC分区（BCB）获得来至Main system和Recovery的消息。

其中通信的方式又分为两种：

1、通过/cache/recovery/目录下的三个文件进行通信

（1）/cache/recovery/command：这个文件保存着Main system传给Recovery的命令行，每一行就是一条命令，支持一下几种的组合。

send_intent=anystring（write the text out to recovery/intent）在Recovery结束时在finish_recovery函数中将定义的intent字符串作为参数传进来，并写入到/cache/recovery/intent中

update_package=root:path（verify install an OTA package file）Main system将这条命令写入时,代表系统需要升级，在进入Recovery模式后，将该文件中的命令读取并写入BCB中，然后进行相应的更新update.zip包的操作。

wipe_data（erase user data(and cache),then reboot）擦除用户数据。擦除data分区时必须要擦除cache分区。

wipe_cache（wipe cache(but not user data),then reboot）擦除cache分区。

（2）/cache/recovery/log：Recovery模式在工作中的log打印。在recovery服务运行过程中，stdout以及stderr会重定位到/tmp/recovery.log在recovery退出之前会将其转存到/cache/recovery/log中，供查看。

（3）/cache/recovery/intent：Recovery传递给Main system的信息。

2、MISC分区的启动控制信息块BCB（Bootloader Control Block）

BCB是Bootloader与Recovery的通信接口，也是Bootloader与Main system之间的通信接口。存储在flash中的MISC分区，占用三个page，其本身就是一个结构体，具体成员以及各成员含义如下：

 struct bootloader_message{

​            char command[32];

​            char status[32];

​            char recovery[1024];

​       };

（1）command成员：当我们想要在重启进入Recovery模式时，会更新这个成员的值。另外在成功更新后结束Recovery时，会清除这个成员的值，防止重启时再次进入Recovery模式。

（2）status：在完成相应的更新后，Bootloader会将执行结果写入到这个字段。

（3）recovery：可被Main System写入，也可被Recovery服务程序写入。存储的就是一个字符串，必须以recovery\n开头，否则这个字段的所有内容域会被忽略。“recovery\n”之后的部分，是/cache/recovery/command支持的命令。可以将其理解为Recovery操作过程中对命令操作的备份。Recovery对其操作的过程为：先读取BCB然后读取/cache/recovery/command，然后将二者重新写回BCB，这样在进入Main system之前，确保操作被执行。在操作之后进入Main system之前，Recovery又会清空BCB的command域和recovery域，这样确保重启后不再进入Recovery模式。









打开update.zip，有一个升级脚本META-INF/com/google/android/updater-script。Android就是根据这个脚本进行升级的，升级失败了，最好从这个脚本中找原因，因为这个文件会打印升级过程中的信息。通过adb shell,进入/tmp目录，有个文件记录了升级过程的信息，可通过这个文件查看升级失败的原因。 





![img](file:////private/var/folders/q8/w266cmnj7z9cpy_j23367j000000gn/T/com.kingsoft.wpsoffice.mac/wps-tracyliu/ksohtml/wps5h2rfS.png) 

​	升级执行的具体过程

①比较时间戳：如果升级包较旧则终止脚本的执行。

②匹配设备信息：如果和当前的设备信息不一致，则停止脚本的执行。

③显示进度条：如果以上两步匹配则开始显示升级进度条。

④格式化system分区并挂载。

⑤提取包中的recovery以及system目录下的内容到系统的/system下。

⑥为/system/bin/下的命令文件建立符号连接。

⑦设置/system/下目录以及文件的属性。

⑧将包中的boot.img提取到/tmp/boot.img。

⑨将/tmp/boot.img镜像文件写入到boot分区。

⑩完成后卸载/system。

需要注意的是执行过程中，并未将升级包另外解压到一个地方，而是需要什么提取什么。在操作的过程中，并未删除或改变update.zip包中的任何内容。在实际的更新完成后，update.zip包确实还存在于原来的位置



---



[Android OTA升级流程分析](https://skytoby.github.io/2019/Android%20OTA%E5%8D%87%E7%BA%A7%E6%B5%81%E7%A8%8B%E5%88%86%E6%9E%90/)


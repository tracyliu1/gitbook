
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

 
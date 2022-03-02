
## 1.image编译

#### 1. 新建分支

 比如在gstar905x_New/下，需要新建立一个分支GLink，则可以做如下操作：

```
cp -rf Reelplay GLink
```

#### 2.修改分支

 新建的GLink分支下有很多原有的Reelplay的路径和编译选项信息，需要修改下面的各个文件：



> 1. device.mk;(主要涉及会改动的文件包括：init.amlogic.usb.rc（新的加密方式需要去掉usb.ko加载，放在kernel中进行加载）；remote.conf；Vendor_0001_Product_0001.kl；（这两个文件是红外遥控键值映射相关）Generic.kl（这个是蓝牙遥控，USB键盘等键值映射相关））
> 2. Reelplay.mk 重命名为GLink.mk （主要涉及到modelname，OTA服务器地址，系统版本号，语言，国家等设置，以及需要预编译到系统中的so库文件等信息，WIFI BT的module_name等信息）
> 3. mkern.sh（dts文件，编译宏配置）
> 4. Android.mk
> 5. Kernel.mk （dts文件，编译宏配置文件，WIFI BT)
> 6. vendorsetup.sh（进行launch和source的环境变量配置名称)
> 7. BoardConfig.mk
> 8. AndroidProducts.mk
> 




##### 有用的Linux命令


```
grep "ronin" * -R | awk -F: '{print $1}' | sort | uniq | xargs sed -i 's/ronin/Catchon/g'
```
将文件夹下所有"ronin"字符串改为"catchon"
如果用此命令，除了Reeplay.mk文件需要手动改动外，其他文件中的Reelplay都会被替换成GLink


删除不同目录下相同文件夹.git


```
find . -type d -name .git | xargs rm -rf
```

查找OkayDock
```
find . -type f | xargs grep "OkayDock"
```



#### 3.dts文件修改

dts通常和硬件以及驱动相关，比如需要新加一个硬件串口，或者增加一路I2C控制器等； 如果不确定后续是否会新增硬件接口，最好每个分支单独建立一个dts文件。
> 1. 905的dts只有1个文件，只能支持1G或者2G DDR,也就是说，1G和2G DDR的版本，需要出两个版本； 905的dts文件是gxbb开头；
> 2. 905X的dts有两个文件，分别时1g和2g DDR的dts，也就是说，905X编译出来的一个版本，可以同时支持1G和2G DRR，无需编译两个版本，905x的dts是gxl开头；
> 3. dts的文件路径：/home/gstar8/work/gstar905x_New/common/arch/arm64/boot/dts/amlogic
> 

#### 4.meson_defconfig
    
> 这个文件控制kernel的编译开关，路径在：/home/gstar8/work/gstar905x_New/common/arch/arm64/configs
有些编译开关kernel中是默认关闭的，比如minigo的电压控制芯片；比如串口ch341；比如触屏驱动；比如usb转eth的驱动等等。各个项目的分支中，建议单独新键一个meson_xxx_defconfig的文件，用于控制将某些驱动程序加入到linux kernel中。

#### 5.开机图片
> 1.开机图片位于device/amlogic/MoudleName/logo_img_files#下，文件名称是bootup.bmp(高级模式 16位 R5G6B5）device\amlogic\MoudleNamew\logo_img_files\bootup.bmp

> 2.如果之前已经编译过本分支，但是客户又需要修改开机图片，请在再次编译的时候，删除/home/gstar8/work/gstar905x_New/out/target/product/GLink/upgrade路径下的logo.img文件


#### 6.开机动画
> 文件位置在device/amlogic/GLink/bootanimation.zip；直接替换即可。


#### 7.overlay目录
> overlay/目录下，主要是用于替换我们的app以及frameworks下的默认开关，图片等信息；

#### 8. 非源码编译的系统APK

>1.位置在目录/vendor/amlogic/prebuilt下，比如Launcher，Market等；

>2.如果新增预编译的APK，需要修改prebuilt下的Andorid.mk文件，增加预编译的APK定义；

>3.预编译的APK，还需要在/home/gstar8/work/gstar905x_New/device/amlogic/product_mbox.mk中，增加对应需要编译的APK；

>4.如果预编译的APK中，有私有的so库（可以将APK解压出来，查看解压出来的APK的对应路径下的：lib/armeabi-v7a文件夹，需要将这个文件夹下的.so文件，在编译的时候拷贝到system/lib目录下进行编译；

>5.每次第三方发布预编译的APK时，请务必检查lib/armeabi-v7a下的so文件是否有更新，如果忘记了更新，可能导致APK出问题；

>6.如果需要去掉预编译的APK，除了修改product_mbox.mk外，还需要将分支下的out/target/product/GLink/obj/APPS/下对应的APK目录整个删除（rm -rf），同时还需要将out/target/product/GLink/system/app/下对应的APK目录整个删除；

#### 9.源码编译APK

> 1. 源码编译的APK存放路径有两处：vendor/amlogic/apps 和 packages/apps/
> 2. vendor/amlogic/apps路径下是用户的APK，如果之前编译过，后面的编译又想去掉，则除了修改product_mbox.mk外，还需要手动删除两个路径下的编译生成目录：out/target/product/GLink/obj/APPS/下对应的APK目录整个删除和out/target/product/GLink/system/app/下对应的APK目录整个删除；
> 3. packages/apps/是系统的APK，比如TvSetting和Settings等。如果之前编译过，后面的编译又想去掉，则除了修改product_mbox.mk（或者修改APK源码下的Andriod.mk)外，还需要手动删除两个路径下的编译生成目录：out/target/product/GLink/obj/APPS/下对应的APK目录整个删除和out/target/product/GLink/system/priv-app/下对应的APK目录整个删除；

#### 10.编译命令

```
source build/envsetup.sh
lunch p201-eng-32
make otapackage -j4
```

#### 11.编译检查
> 1. 编译前检查device/amlogic/MoudleName/moudle.mk的ro.product.version，需加1。
> 2. 编译完成后，检查out/target/product/MoudleName/system/build.prop的版本号ro.product.version;检查out/target/product/GLink/MoudleName/root/default.prop的版本号ro.product.version;
> 3. 如果发现ro.product.version 版本号不一致的情况。则做makeinstallclean(source-lunch-makeinstallclean-make).



---


## 2.制作差异包
#### 1.版本备份

备份目录
```
UPDATE_VERSION/Reelplay/
```

 检查编译出image的版本号

```
vim system/build.prop
vim recovery/root/default.prop
```
备份 image 和 zip

```
cp ../../../out/target/product/Reelplay/aml_upgrade_package.img .
 cp ../../../out/target/product/Reelplay/obj/PACKAGING/target_files_intermediates/Reelplay-target_files-20180511.zip .
```

#### 2.编译ota差异包及测试

编译差异包


> ./build/tools/releasetools/ota_from_target_files -i Reelplay-target_files-20180427.zip Reelplay-target_files-20180511.zip ota_Reelplay_101_102.zip

ota服务器地址

> 各个产品的OTA服务器的名称（或者IP地址）位于各个分支的xxx.mk文件中（比如Glink分支，位于/home/gstar8/work/gstar905x_New/device/amlogic/GLink/GLink.mk文件ro.product.otaupdateurl=eu.echotv.me:2900）


#### 3.修改加密方式

1. >修改device/amlogic/Reelplay# vim init.amlogic.usb.rc;把insmod /system/lib/dwc3.ko去掉；
2. >查一下device/amlogic/Reelplay# vim Kernel.mk文件中，KERNEL_DEFCONFIG用的是哪个文件；
3. >根据2查找的内容，在common/arch/arm64/configs/下找到对应的KERNEL_DEFCONFIG文件，并修改CONFIG_USB_DWC3=y(其中y表示既编译，又加载，即在kernel中会自动加载，如果是m表示只编译，不加载，通过init.amlogic.usb.rc脚本来加载指定的dwc3.ko)，同时增加串口驱动两个编译宏：
CONFIG_USB_SERIAL_CONSOLE=y
CONFIG_USB_SERIAL_CH341=y
4. >修改common/arch/arm64/boot/dts/amlogic# vim gxl_Reelplay_1g.dts和gxl_Reelplay_2g.dts，查找unifykey，增加对应的密钥区节点。


---


### 相关代码路径
##### 音量调节定位java文件，740行左右：

>android/frameworks/base/core/java/android/view/VolumePanel.java（280行）

##### 布局文件：
core/res/res/layout/volume_adjust_item.xml 

core/res/res/layout/volume_adjust.xml 

##### 亮度调节：

android/frameworks/base/packages/SystemUI/src/com/android/systemui/settings/ToggleSlider.java

packages/SystemUI/res/layout/status_bar_toggle_slider.xml

packages/SystemUI/res/layout/quick_settings_brightness_dialog.xml 
##### 关机界面：

android/frameworks/base/policy/src/com/android/internal/policy/impl/GlobalActions.java

android/frameworks/base/core/java/com/android/internal/app/AlertController.java

base/services/java/com/android/server/power/ShutdownThread.java

base/core/res/res/values/symbols.xml
##### wifi无网浮层提示：

frameworks/base/services/java/com/android/server/wifi/WifiNotificationController.java

packages/SystemUI/src/com/android/systemui/statusbar/policy/NetworkController.java

packages/SystemUI/src/com/android/systemui/statusbar/phone/QuickSettings.java


##### PhoneWindowManager 拦截按键
>\frameworks\base\services\core\java\com\android\server\policy\PhoneWindowManager.java



```
 @Override
    public long interceptKeyBeforeDispatching(WindowState win, KeyEvent event, int policyFlags) {
       ...
        }
```

##### 系统内置App
> 默认预置apk到system/app/目录（普通系统apk，不可卸载），预置apk到system/priv-app/目录（系统核心apk，不可卸载），app对应的Android.mk下增加LOCAL_PRIVILEGED_MODULE := true，表示生成的apk放在system/priv-app/目录下。

##### make snod

> make snod  重新生成image文件，但不重新编译模块

##### 单独编译framework.jar

> 在framework/base/core/res/res 下添加资源文件后需要先编译资源 然后编译framework 才可正常引用
> 
> 
> 进入项目根目录 cd frameworks/base/core/res/ 执行mm命令（原生或高通）, 编译 framework-res.apk
> 
> 编译完后com.android.internal.R中会生成资源的引用。 
> 
> 
> 在目录frameworks/base/ 下执行mm 编译 framework.jar  （原生或高通）


##### android中更改framework层代码后怎操作才可以看到更改后的效果？
1.下面方法适合真机：下载android源码，然后编译你修改的framwork的代码，会生成framework.jar,然后push到system/framework目录下，重启机器！ok

2,下面方法适合模拟器：
(1):用unyaffs解压，你下载的sdk目录下system.img,然后替换其中的framework.jar,然后再压缩成新的system.img;然后启动模拟器就ok

(2):或者用直接全编译源码，用生成system.img去替换模拟器下面system.img也ok


替换framework.jar 执行如下命令

```
  adb remount

  adb push framework-res.apk /system/framework/

  adb push framework.jar /system/framework/

  adb push services.jar /system/framework/  （如果有修改的话）
```

  
  
#### android怎编译framework

1. 资源文件位置:frameworks/base/core/res
2. 编译后生成的文件:framework-res.apk 另外com.android.internal.R会更新这个R.java所在目录为/out/target/common/R/com/android/internal.
3. 编译资源后,必须重新编译framework.jar.
4. 如果在frameworks/base/core/res执行mm是并不重新编译,请使用toutch ### 命令 (###代表目录下的一个文件).
5. 资源文件要小写.
6. 如果没有必要,不要编译资源文件,可以用其他方式使用资源,比如将资源使用adb push 传到某个目
录,程序中直接指定具体目录.我在编译资源过程中遇到一些奇怪的问题,比如有时候许多图标会显
示错误,原因猜测跟重新编译资源有关,可以试着重新编译services.jar并替换看看.

##### 举一个例子:假如我想在WindowManagerService.java中使用一个图片资源pic.png.顺序如下.
1. 将文件pic.png拷贝到位置:frameworks/base/core/res/res/drawable下.
2. 在frameworks/base/core/res/res/drawable目录下执行touch pic.png.
3. 进入目录frameworks/base/core/res/ 执行mm命令, 编译 framework-res.apk
4. 执行完后com.android.internal.R 会新生成一个R.drawable.pic的引用.在程序中使用即可.
5. 在目录frameworks/base/ 下执行mm 编译 framework.jar.
6. 在WindowManagerService.java中使用com.android.internal.R.drawable.pic,使用完后保存文件.
7. 进入目录frameworks/base/services/java/ 执行mm 编译 services.jar
8. 替换机器上(虚拟机或者真机)的jar apk文件.
adb push framework-res.apk /system/framework/
adb push services.jar /system/framework/
adb push framework.jar /system/framework/
执行命令时注意framework-res.apk 的真实路径.
9. reboot 机器,查看修改结果.大功告成!

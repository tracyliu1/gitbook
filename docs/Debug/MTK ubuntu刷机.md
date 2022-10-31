#### MTK ubuntu刷机

第一步：

1. sudo gedit /etc/udev/rules.d/80-persistent-usb.rules

添加：

> SUBSYSTEM=="usb", ACTION=="add", ATTR{idVendor}=="0e8d", ATTR{idProduct}=="0003"

*0003 需要 lsusb看一下自己的设备*

2. sudo gedit /etc/udev/rules.d/20-mm-blacklist-mtk.rules
   添加：
   ATTRS{idVendor}=="0e8d", ENV{ID_MM_DEVICE_IGNORE}="1"
   ATTRS{idVendor}=="6000", ENV{ID_MM_DEVICE_IGNORE}="1"

3. 重新加载   sudo service udev restart

4. sudo gedit /etc/udev/rules.d/53-android.rules

添加：
SUBSYSTEM=="usb", SYSFS{idVendor}=="0e8d", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}="0e8d", ATTR{idProduct}="0003", SYMLINK+="android_adb"

5. sudo gedit /etc/udev/rules.d/53-MTKinc.rules

添加：
SUBSYSTEM=="usb", SYSFS{idVendor}=="0e8d", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}="0e8d", ATTR{idProduct}="0003", SYMLINK+="android_adb"
KERNEL=="ttyACM*", MODE="0666"

6. 重新加载驱动

　　sudo chmod a+rx /etc/udev/rules.d/53-android.rules
    sudo chmod a+rx /etc/udev/rules.d/53-MTKinc.rules
    sudo /etc/init.d/udev restart  
	

7. 依次输入下面命令

      1)   sudo usermod -a -G dialout $USER
      2)   sudo apt-get remove modemmanager
      3)   sudo service udev restart
      4)   lsmod | grep cdc_acm
      5)   sudo modprobe cdc_acm
	
8. 如打开工具遇到报错  error:status_err(-1073676287),Msp Error Code:0x00.
   网站步骤解决即可：
   https://blog.csdn.net/Suviseop/article/details/114126727
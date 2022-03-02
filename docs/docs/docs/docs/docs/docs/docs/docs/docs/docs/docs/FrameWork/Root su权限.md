## Root SU



Root后系统多了两个文件，su 和SuperUser.apk。 su负责获取Root权限的命令，SuperUser.apk是一个管理Root权限的应用。









su文件   Android手机的/system/bin或者/system/xbin/目录



你需要把一个所有者是root的su拷贝到Android手机上，并且把su的权限标志位置成-rwsr-xr-x。能把这个事情搞定你就成功root了一个手机。

大概意思就是两行代码

```bash
cp /data/tmp/su /system/bin/ #copy su 到/system/分区
chown root:root su #su的所有者置成root
chmod 4775 /system/bin/su #把su置成-rwsr-xr-x
```

然而，执行上面的每一行代码都需要root权限才能成功。





```csharp
int adb\_main(int is\_daemon)
   {
       ......
       property\_get("ro.secure", value, "");
       if (strcmp(value, "1") == 0) {
           // don't run as root if ro.secure is set...
           secure = 1;
           ......
       }

      if (secure) {
          ......
          setgid(AID\_SHELL);
          setuid(AID\_SHELL);
          ......
      }
  }
```





adbd会检测系统的ro.secure属性，如果该属性为1则将会把自己的用户权限降级成shell用户。一般设备出厂的时候在/default.prop文件中都会有：

1: ro.secure=1

这样将会使adbd启动的时候自动降级成shell用户



在init.rc中配置的系统服务启动的时候都是root权限（因为init进行是root权限，其子程序也是root）。由此我们可以知道在adbd程序在执行：

```bash
/* then switch user and group to "shell" */
   setgid(AID_SHELL);
   setuid(AID_SHELL);
```

代码之前都是root权限，只有执行这两句之后才变成shell权限的。





![image-20210520151021297](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210520151021297.png)



![image-20210520151715463](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210520151715463.png)



---



https://juejin.cn/post/6844903839817023495

https://www.jianshu.com/p/7e3d1499c37e

https://www.jianshu.com/p/6bc251ee9026
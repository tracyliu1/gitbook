会报错，tag 为 avc ， 如：

```
12-10 13:48:12.053 E/SELinux ( 3838): avc:  denied  { add } for service=gtv.system.commonservice scontext=u:r:system_app:s0 tcontext=u:object_r:default_android_service:s0 tclass=service_manager
12-10 13:48:12.053 E/ServiceManager( 3838): add_service('gtv.system.commonservice',5e) uid=1000 - PERMISSION DENIED
12-10 13:48:12.053 D/AndroidRuntime( 6259): Shutting down VM
12-10 13:48:12.055 E/AndroidRuntime( 6259): FATAL EXCEPTION: main
12-10 13:48:12.055 E/AndroidRuntime( 6259): Process: com.gtv.commonservice, PID: 6259
12-10 13:48:12.055 E/AndroidRuntime( 6259): java.lang.RuntimeException: Unable to create service com.gtv.commonservice.service.SystemCommonService: java.lang.SecurityException
```


使用工具生成需添加的 selinux 赋权命令
adb pull /sys/fs/selinux/policy
>  adb logcat -b all -d | audit2allow -p policy

对于972/Android 9.0
需要使用源码中的audit2allow
external/selinux/prebuilts/bin/audit2allow -p policy
或者
echo "avc:  denied  { add } for service=gtv.system.commonservice scontext=u:r:system_app:s0 tcontext=u:object_r:default_android_service:s0 tclass=service_manager" | audit2allow -p policy


执行后，提示下面这样的内容，提示在什么文件中添加赋权命令
#============= system_app ==============
allow system_app default_android_service:service_manager add;



其中 policy 为编译源码后生成的文件，不需要每次都pull出来，验证 SELinux
audit2allow 工具安装 
在 Ubuntu 14 下   
sudo apt-get install policycoreutils
在 Ubuntu 18 下
sudo apt-get install policycoreutils-python-utils
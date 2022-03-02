



1、编译的时候针对user版本会对apk进行处理，将里面的class.dex文件拿出来单独处理为odex,apk文件中只留下一些资源文件

2、第一次开机耗时会比较长，中间有大量的dex2oat的log存在，也是针对每个APK在做dex优化

##### LOCAL_DEX_PREOPT

这个变量设置为false可以使整个系统使用提前优化的时候，某个app不使用提前优化。在Android.mk中给该变量赋值为false,则编译生成的文件没有oat文件，也就意味着没有被提前优化。


##### 整个framework的默认编译设置
> /build/core/java_library.mk

查找 LOCAL_DEX_PREOPT := true
修改为 LOCAL_DEX_PREOPT := false

##### package下默认编译设置
> /build/core/package.mk

查找 LOCAL_DEX_PREOPT := true
修改为 LOCAL_DEX_PREOPT := false
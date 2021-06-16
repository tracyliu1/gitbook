## APK打包过程



编译 、 打包、签名优化

![image-20210520114058435](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210520114058435.png)



### 编译过程

使用aapt工具对资源文件打包，生成R文件。aidl工具处理AIDL，javac编译java文件。  .class文件转化成dex文件



### 打包过程

使用apk builder打包生成未签名的APK文件。将编译生成的文件按照一定格式压缩到apk文件中

### 签名优化

- 使用jarsigner对未签名的apk签名
- 使用zipalign工具对签名后的apk进行对齐处理
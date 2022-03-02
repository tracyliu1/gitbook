### PKMS安装流程相关

### 1.应用相关目录

- /system/priv-app：系统应用 特权APP安装路径，Android 4.4+ 开始出现，
- /system/app：系统应用安装路径，权限略低于 priv-app 目录下的应用，放置比如厂商内置应用
- /data/app：用户应用安装路径，应用安装时将 apk 复制到此目录下

- /data/data：用户应用数据存放路径，存在沙箱隔离
- /data/dalvik-cache：存放应用的dex 文件
- /data/system：存放应用安装相关文件
  - packages.xml 是一个应用的注册表，在解析应用时创建，有变化时更新，记录系统权限，各应用信息，如name, codePath, flag, version, userid，下次开机时直接读取并添加到内存列表
  - package.list 指定应用的默认存储位置，userid 等

应用安装过程总结

1. 将应用 apk 拷贝到指定目录下
2. 解压 apk，将 dex 文件拷贝到 /data/dalvik-cache 目录，创建 /data/data/ 数据目录
3. 解析 AndroidManifest.xml 及其他资源文件，提取应用包信息，注册到 packags.xml 中
4. 由 Launcher 进程通过 PMS 取出所有应用程序，展示在桌面上



![img](https://img-blog.csdn.net/20160628012032687?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQv/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/Center)



1. 大部分情况我们是在Activity中使用getPackageManager方法获取一个ApplicationPackageManager的对象，ApplicationPackageManager实际上是包装了一个IPackageManager.Stub.Proxy的对象
2. 由IPackageManager.Stub.Proxy代理执行PackageManager相关操作，IPackageManager.Stub.Proxy实际代理的是PackageManagerService,
3. IPackageManager是通过IPackageManager.aidl文件生成，同时生成了存根类IPackageManager.Stub，代理类：IPackageManager.Stub.Proxy。这个是packageManager进程通信的基本框架，



#### adb install 



```java
 private int runInstall() throws RemoteException {
  if(inPath != null) {
            File file = new File(inPath);
            if (file.isFile()) {
                try {
                    ApkLite baseApk = PackageParser.parseApkLite(file, 0);
                    //PackageLite pkgLite = new PackageLite(null, baseApk, null, null, null);
                    if (!mPm.InstallAvailable(baseApk.packageName)) {
                        throw new IOException("Error: Failed to install APK file, not in the WhiteList");
                    }
                } catch (PackageParserException | IOException e) {
                    System.err.println("Error: Failed to parse APK file : " + e);
                    return 1;
                }
            }
        }
 }
```



对应PackageManagerService，

```
 public boolean InstallAvailable(String packageName){
        Log.d(TAG, "InstallAvailable: packageName=" + packageName);
        boolean appInstallWhiteListEnable = (android.provider.Settings.System.getInt(mContext.getContentResolver(), android.provider.Settings.System.XDF_APK_INSTALL_ENABLE, 0) == 0);
        if(!appInstallWhiteListEnable || isWhiteApp(packageName)){
            return true;
        }
        return false;
    }
```



```

```

ApplicationPackageManager extends PackageManager
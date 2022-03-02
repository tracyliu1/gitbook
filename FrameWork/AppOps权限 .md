## AppOpsManager 权限





Android 权限大致分为三类 



API权限

等级分为 normal dangerous  signature signatureOrSystem



文件权限

dwrdwrdwr

IPC权限







![image-20210520150003851](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210520150003851.png)







Application Operations，应用权限管理。

- `PACKAGE` 应用包名
- `OP` 操作权限
- `MODE` allow（允许）、ignore（忽略）或default（默认）中的一种
- `USER_ID` 应用安装在哪个用户之下，如果没有指定就假设是当前用户





**adb shell pm grant** 包名 **android.permission.SYSTEM_ALERT_WINDOW**

**adb shell appops set com.xxx.packagename SYSTEM_ALERT_WINDOW allow**



#### appops set get reset

`appops set [--user (USER_ID)] (PACKAGE) (OP) (MODE)`，给应用设置权限。

```
appops set com.jiongbull.art.note READ_SMS allow
```

`appops get [--user <USER_ID>] <PACKAGE> [<OP>]`，获取应用的权限。

```
appops get com.android.phone WRITE_SMS
```

`appops reset [--user <USER_ID>] [<PACKAGE>]`，重置应用权限。

```
appops reset com.jiongbull.art.note
```
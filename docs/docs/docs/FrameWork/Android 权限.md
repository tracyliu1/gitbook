## Android Permission



https://www.cnblogs.com/rossoneri/p/10266189.html

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







[运行时权限-AOSP](https://source.android.com/devices/tech/config/runtime_perms)

[APP如何请求运行时权限-Developer](https://developer.android.com/training/permissions/requesting)

[Android O特许权限白名单](https://source.android.com/devices/tech/config/perms-whitelist)

[Android Permissions-简书](https://www.jianshu.com/p/ffd583f720f4)

### 运行时权限和gids

**GIDS**

> gids是由框架在Application安装过程中生成，与Application申请的具体权限相关。如果Application申请的相应的permission被granted，而且有对应的gids，那么这个Application的gids中将包含这个gids

[platform.xml](http://androidxref.com/7.1.2_r36/xref/frameworks/base/data/etc/platform.xml)

```
<!-- This file is used to define the mappings between lower-level system user and group IDs and the higher-level permission names managed by the platform. Be VERY careful when editing this file! Mistakes made here can open big security holes. -->
<permissions>

    <permission name="android.permission.WRITE_MEDIA_STORAGE" >
        <group gid="media_rw" />
        <group gid="sdcard_rw" />
    </permission>

</permissions>
```

### 调试命令

**查看设备支持的运行时权限列表**

adb shell pm list permissions -g -d

**查看进程gids**

adb shell dumpsys activity p com.sunmi.superpermissiontest

**查看应用已经授予的动态权限**

adb shell dumpsys package com.sunmi.superpermissiontest

**权限授予和收回**

pm grant [–user USER_ID] PACKAGE PERMISSION
pm revoke [–user USER_ID] PACKAGE PERMISSION
pm reset-permissions
pm set-permission-enforced PERMISSION [true|false]

### 系统预置应用授权

[DefaultPermissionGrantPolicy.java](http://androidxref.com/7.1.2_r36/xref/frameworks/base/services/core/java/com/android/server/pm/DefaultPermissionGrantPolicy.java)

**PackageManagerService**

```
    final DefaultPermissionGrantPolicy mDefaultPermissionPolicy;

    public PackageManagerService(Context context, Installer installer,
            boolean factoryTest, boolean onlyCore) {

            mDefaultPermissionPolicy = new DefaultPermissionGrantPolicy(this);

    }

    @Override
    public void systemReady() {

        // If we upgraded grant all default permissions before kicking off.
        for (int userId : grantPermissionsUserIds) {
            mDefaultPermissionPolicy.grantDefaultPermissions(userId);
        }

    }

    @Override
    public void grantRuntimePermission(String packageName, String name, final int userId) {}

    @Override
    public void revokeRuntimePermission(String packageName, String name, int userId) {}
```

**DefaultPermissionGrantPolicy**

```
    public void grantDefaultPermissions(int userId) {
        grantPermissionsToSysComponentsAndPrivApps(userId);
        grantDefaultSystemHandlerPermissions(userId);
        grantDefaultPermissionExceptions(userId);
    }
```

### APP如何请求动态权限

```
// 请求权限

// Here, thisActivity is the current activity
if (ContextCompat.checkSelfPermission(thisActivity,
        Manifest.permission.READ_CONTACTS)
        != PackageManager.PERMISSION_GRANTED) {

    // Permission is not granted
    // Should we show an explanation?
    if (ActivityCompat.shouldShowRequestPermissionRationale(thisActivity,
            Manifest.permission.READ_CONTACTS)) {
        // Show an explanation to the user *asynchronously* -- don't block
        // this thread waiting for the user's response! After the user
        // sees the explanation, try again to request the permission.
    } else {
        // No explanation needed; request the permission
        ActivityCompat.requestPermissions(thisActivity,
                new String[]{Manifest.permission.READ_CONTACTS},
                MY_PERMISSIONS_REQUEST_READ_CONTACTS);

        // MY_PERMISSIONS_REQUEST_READ_CONTACTS is an
        // app-defined int constant. The callback method gets the
        // result of the request.
    }
} else {
    // Permission has already been granted
}

// 请求结果

@Override
public void onRequestPermissionsResult(int requestCode,
        String[] permissions, int[] grantResults) {
    switch (requestCode) {
        case MY_PERMISSIONS_REQUEST_READ_CONTACTS: {
            // If request is cancelled, the result arrays are empty.
            if (grantResults.length > 0
                && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                // permission was granted, yay! Do the
                // contacts-related task you need to do.
            } else {
                // permission denied, boo! Disable the
                // functionality that depends on this permission.
            }
            return;
        }

        // other 'case' lines to check for other
        // permissions this app might request.
    }
}
```

------









https://lixiaogang03.github.io/2019/03/28/Android-Selinux/

[AOSP安全指南](https://source.android.com/security)

[官网应用安全最佳实践](https://developer.android.com/topic/security/best-practices#permissions)

[源码权限定义](http://androidxref.com/7.1.2_r36/xref/frameworks/base/core/res/AndroidManifest.xml)

[官网权限定义](https://developer.android.google.cn/reference/android/Manifest.permission)

[GID权限定义](http://androidxref.com/7.1.2_r36/xref/frameworks/base/data/etc/platform.xml)

[GID和权限对应关系](http://androidxref.com/7.1.2_r36/xref/system/core/include/private/android_filesystem_config.h)
## Android.mk





LOCAL_PATH:=$(call my-dir)  定义模块相对路径

include $(CLEAR_VARS)   清空当前环境变量

LOCAL_MODULE:= test  生成目标文件

LOCAL_SRC_FILES:=test.c  需要的源文件

include $(BUILD_EXECUTABLE)  编译生成的目标文件格式



call my_dir定义

> build/core/definitions.mk

返回mk文件所在目录即LOCAL_PATH

```
 # Figure out where we are.
define my-dir
$(strip \
  $(eval LOCAL_MODULE_MAKEFILE := $$(lastword $$(MAKEFILE_LIST))) \
  $(if $(filter $(BUILD_SYSTEM)/% $(OUT_DIR)/%,$(LOCAL_MODULE_MAKEFILE)), \
    $(error my-dir must be called before including any other makefile.) \
   , \
    $(patsubst %/,%,$(dir $(LOCAL_MODULE_MAKEFILE))) \
   ) \
 )
endef
```





> build/core/config.mk

定义CLEAR_VARS

```

CLEAR_VARS:= $(BUILD_SYSTEM)/clear_vars.mk
```

实际位置 build/core/clear_vars.mk 作用清除全部变量







---

https://juejin.cn/post/6854573211045068814




#### WMS接口结构



![WMS接口结构](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210222100157418.png)



主要交互过程：

1. 在Activity添加或删除窗口，具体通过WindowManager类的addView()和removeView()完成，这样会转而调用ViewRoot类相关方法，然后通过IPC调用到WMS中完成相关的添加 删除操作；
2. 当AMS通知ActivityThread销毁某个activity时，AT会直接调用WindowManager的removeView()删除窗口；
3. AMS中调用WMS，比如某个activity启动，WMS中会保存一个该Activity的记录引用；



WMS内部全权接管了输入消息的处理和屏幕的绘制，输入消息的处理借助于InputManager类完成，屏幕的绘制则是借助于SurfaceFlinger实现。



### WMS的内部类



#### 表示窗口的数据类

WMS中表示窗口的类是WindowState，但除此之外WMS还定义了额外两个类表示窗口，分别是AppWindowToken和WindowToken。

每一个窗口都会对应一个WindowState对象，用来描述窗口全部的数据、属性。

WindowToken描述的是窗口对应的token相关属性，每个窗口都对应一个WindowToken对象。同一个窗口的所有子窗口都对应同一个WindowToken对象。即多对一的关系。

如果是Activity创建的窗口，则窗口对应一个Activity，对应会有一个AppWindowToken对象。

所以从数量上说WindowState > WindowToken >AppWindowToken。







#### InputMonitor相关



![image-20210219001050727](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210219001050727.png)



在WMS中有两个全局变量InputMonitor和InputManager。

在InputManager中有一个全局变量mWindowManagerService即 wms。当底层的InputDispatcher线程接收到消息后，首先会回调InputManger中的一个callback函数，该函数内部大多调用wms中mInputMonitor对象的相应函数





### 窗口的创建和删除



#### 窗口创建的时机

窗口创建的时机分为两种，一种是主动调用wm的addView()方法，另外一种是启动Activity或者对话框，这种情况是程序内部会调用addview。



![image-20210222133039529](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210222133039529.png)

当调用wm.addview()方法后，该方法会创建一个新的ViewRoot对象，然后调用viewRoot的setView()方法，该方法会通过IPC调用WMS中session对应的add()方法。Session中的add()方法会间接调用WMS中的addWindow()。






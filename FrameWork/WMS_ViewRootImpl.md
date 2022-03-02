ViewRootImpl:performTraversals每次遍历刷新window界面时候，会调用relayoutWindow方法；
在WMS里面会代码判断当前显示window是可见的，就创建WindowSurfaceController；构造系统绘图的SurfaceController；并把ViewRootImpl传过来的Surface初始化；



- ViewRootImpl:performTraversals--->
- ViewRootImpl:relayoutWindow--->
- WMS:relayoutWindow--->
- WMS:createSurfaceControl--->
- WindowStateAnimator:createSurfaceLocked--->
  mSurfaceController = new WindowSurfaceController(mSession.mSurfaceSession,attrs.getTitle().toString(),width, height, format, flags, this);

 

##### ViewRootImpl:performTraversals在ViewRootImpl里面调用地方；

- requestChildFocus；
- clearChildFocus；
- handleDispatchSystemUiVisibilityChanged；
- setLayoutParams；
- handleAppVisibility；
- handleGetNewSurface；
- requestFitSystemWindows；
- requestLayout；
- Invalidate；
- invalidateRectOnScreen；
- setWindowStopped；

 

---

从软件层面上看，Android的Graphic框架主要有几个模块：
 Activity、Window、Surface、Layer、Canvas、BufferQueue。

其中：

1. **Activity**：标记一个活动，是活动的管理者（并不参与绘制），是Window的承载者；

2. **Window**：标记一个窗口（真实其实是WindowState），是一个抽象概念，用来对承载和管理Surface；

3. **Surface**：标记一个绘制流程，面向开发者弱化了GraphicBuffer的概念，用来申请/提交Buffer，管理Canvas，管理一个绘制回合（绘制流程的同步）;

4. **Layer**：Graphic服务端的Buffer承载者，对应一个Surface，它受SurfaceFlinger的管理。SurfaceFlinger是Surface的消费者，消费单位是Layer；

5. **Canvas**： 真正用于图形数据填充(绘制)的对象，Surface申请的Buffer会保存在Canvas中的SKBitmap中，绘制完成后，Surface会将Canvas对应的已经填充了有效数据的缓冲区enqueue到BufferQueue，然后通消费者有需要渲染的Buffer入队，然后交由消费者消费；

在App侧，只需要使用2D/3D图形绘制引擎来绘制出自己的图形数据，然后提交到这一块申请好的Buffer中，
 并提交到BufferQueue，消费者SurfaceFlinger会从BufferQueue取出数据经由opengl渲染之后递交到屏幕显示。

 App一般使用的事2D图形引擎Skia，3D由OpenGL做渲染。也可以通过开启硬件加速交由opengl来渲染，在Android N上有hwui作为硬件加速的可选项。

关于Android APP中 Skia和openGL的了解，可以参考：
 [Android Graphic ： apk and Skia/OpenGL|ES](https://blog.csdn.net/yili_xie/article/details/4803565)

1. BufferQueue： Android Graphic的核心之一，管理生产者和消费者之间对Buffer使用的同步，还有GPU/CPU的跨硬件同步(Fence)，在Graphic系统上起着关键的作用。具体参考上面的**第三大点**。

**以上所有的流程个人总结为：**
 初始化会话链接 -> 添加Window，设置Window信息(显示屏幕、显示大小，格式等等) -> 创建Surface ->
 初始化Layer -> 创建BufferQueue -> 申请Buffer -> 填充Buffer -> 提交Buffer -> 消费Buffer（渲染）->显示渲染内容

 

 




##### OnTrimMemory的主要作用就是指导应用程序在不同的情况下进行自身的内存释放，以避免被系统直接杀掉，提高应用程序的用户体验

OnTrimMemory：Android 4.0之后提供的API，系统会根据不同的内存状态来回调。根据不同的内存状态，来响应不同的内存释放策略。

##### onLowMemory()方法在使用过程只要低内存状态下,就会回调.

OnLowMemory：Android提供的API，在系统内存不足，所有后台程序（优先级为background的进程，不是指后台运行的进程）都被杀死时，系统会调用OnLowMemory。


#### onTrimMemory传入的几个内存级别释放内存：

- TRIM_MEMORY_RUNNING_MODERATE
  你的应用正在运行，并且不会被杀死，但设备已经处于低内存状态，并且开始杀死LRU缓存里的内存。(后台进程超过5个)，并且该进程优先级比较高，需要清理内存 

- TRIM_MEMORY_RUNNING_LOW
  你的应用正在运行，并且不会被杀死，但设备处于内存更低的状态，所以你应该释放无用资源以提高系统性能(直接影响app性能)

- TRIM_MEMORY_RUNNING_CRITICAL
  你的应用还在运行，但系统已经杀死了LRU缓存里的大多数进程，所以你应该在此时释放所有非关键的资源。如果系统无法回收足够的内存，它会清理掉所有LRU缓存，并且开始杀死之前优先保持的进程，像那些运行着service的。(后台进程不足3个)，并且该进程优先级比较高，需要清理内存

- TRIM_MEMORY_BACKGROUND
  系统运行在低内存状态，并且你的进程已经接近LRU列表的顶端(即将被清理).虽然你的app进程还没有很高的被杀死风险，系统可能已经清理LRU里的进程，你应该释放那些容易被恢复的资源，如此可以让你的进程留在缓存里，并且当用户回到app时快速恢复.该进程是后台进程。

- TRIM_MEMORY_MODERATE
  系统运行在低内存状态，你的进程在LRU列表中间附近。如果系统变得内存紧张，可能会导致你的进程被杀死。并且该进程在后台进程列表的中部。

- TRIM_MEMORY_COMPLETE
  系统运行在低内存状态，如果系统没有恢复内存，你的进程是首先被杀死的进程之一。你应该释放所有不重要的资源来恢复你的app状态。该进程在后台进程列表最后一个，马上就要被清

- TRIM_MEMORY_UI_HIDDEN：内存不足，并且该进程的UI已经不可见了。 

  


  ###### onTrimMemory()是在API 14里添加的，你可以在老版本里使用onLowMemory()回调，大致跟TRIM_MEMORY_COMPLETE事件相同。

  

  ##### onLowMemory、 onTrimMemory优化，需要释放什么资源？

  在内存紧张的时候，会回调OnLowMemory/OnTrimMemory，需要在回调方法中编写释放资源的代码。
  可以在资源紧张的时候，释放UI 使用的资源资：Bitmap、数组、控件资源。
  注意回调时刻：
  OnLowMemory被回调时，已经没有后台进程；而onTrimMemory被回调时，还有后台进程。
  OnLowMemory是在最后一个后台进程被杀时调用，一般情况是low memory killer 杀进程后触发；而OnTrimMemory的触发更频繁，每次计算进程优先级时，只要满足条件，都会触发。
  在Application、 Activity、Fragement、Service、ContentProvider中都可以重写回调方法，对OnLowMemory/OnTrimMemory进行回调，在回调方法中实现资源释放的实现。
  以Activity为例，在Activity源码中能够看到对于onTrimMemory的定义，因此在回调的时候重写方法即可。







https://developer.ibm.com/zh/technologies/mobile/articles/os-cn-android-mmry-rcycl/
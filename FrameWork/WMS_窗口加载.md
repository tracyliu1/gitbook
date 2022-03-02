### WMS窗口加载



PhoneWindow什么时候创建的 

setContentView流程

对于Activity来说，UI线程就是主线程；

对于View来说，UI线程就是ViewRootImpl创建时所在的线程

Activity对应的DecorView对应的ViewRootImpl是在主线程创建的





```java
public void setContentView(@LayoutRes int layoutResID) {
    getWindow().setContentView(layoutResID);//getWindow获取 mWindow对象
}
```

window对象在attach时创建,由此可知window是PhoneWindow

```java
final void attach(Context context, ActivityThread aThread,) {
mWindow = new PhoneWindow(this, window);
}
```

```java
 @Override
    public void setContentView(int layoutResID) {
        if (mContentParent == null) {
            installDecor();  //初始化decorview 和 mContentParent 
        } 
            mLayoutInflater.inflate(layoutResID, mContentParent);
    }
```





```java
final void handleResumeActivity(){
                if (a.mVisibleFromClient && !a.mWindowAdded) {               
                    wm.addView(decor, l);
                } 
}
```



> frameworks/base/core/java/android/view/WindowManagerGlobal.java

```java
public void addView(View view, ViewGroup.LayoutParams params,
        Display display, Window parentWindow) {
     root = new ViewRootImpl(view.getContext(), display);
     root.setView(view, wparams, panelParentView);

}
```



> frameworks/base/core/java/android/view/ViewRootImpl.java

```java
public void setView(View view, WindowManager.LayoutParams attrs, View panelParentView) {
  
  requestLayout();
  mWindowSession.addToDisplay(mWindow, mSeq, mWindowAttributes,)
  
}
```

重点看requestLayout 和 addToDisplay

#### requestLayout 

```java
public void requestLayout() {
        checkThread();//通过mThread判断是不是UI线程 mThread在ViewRootImpl构造函数中初始化
        scheduleTraversals();
}
```

向mChoreographer注册一个callback 即mTraversalRunnable  回调doTraversal(）对应performTraversals函数开始view的绘制流程

```java
void scheduleTraversals() {
    if (!mTraversalScheduled) {
        mTraversalScheduled = true;
        mTraversalBarrier = mHandler.getLooper().getQueue().postSyncBarrier();
        mChoreographer.postCallback(
                Choreographer.CALLBACK_TRAVERSAL, mTraversalRunnable, null);
        if (!mUnbufferedInputDispatch) {
            scheduleConsumeBatchedInput();
        }
        notifyRendererOfFramePending();
        pokeDrawLockIfNeeded();
    }
}
```



```java
private void performTraversals() {

  relayoutWindow();  // 申请surface
  performMeasure();
  performLayout();
  performDraw();
}
```

通过session调到WMS的relayoutWindow，最终在

```java
    result = createSurfaceControl(outSurface, result, win, winAnimator);
```



#### mWindowSession.addToDisplay

通过session 调用到WMS的addWindow,通过传入的client即mWindow对象创建windowstate，将窗口信息加入到mWindowMap中进行管理。

```java
 public int addWindow(Session session, IWindow client, ...) {
        WindowState win = new WindowState(this, session, client, token,
                    attachedWindow, appOp[0], seq, attrs, viewVisibility, displayContent);
   
         mWindowMap.put(client.asBinder(), win);
    }

```





![image-20210311143722340](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210311143722340.png)
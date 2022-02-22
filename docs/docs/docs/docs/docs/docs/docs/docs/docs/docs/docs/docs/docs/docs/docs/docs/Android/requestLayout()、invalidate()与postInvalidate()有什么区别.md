

#### requestLayout()、invalidate()与postInvalidate()有什么区别？

一般说来需要重新布局就调用requestLayout()方法，需要重新绘制就调用invalidate()方法。
- requestLayout()：会触发onMesaure()与onLayout()方法，不一定 会触发onDraw()方法。（只有当layout时改变l t r b）
- invalidate()：会触发onDraw()方法。postInvalidate()：该方法功能和invalidate()一样，只是它可以在非UI线程中调用。

###### requestLayout()

View中的requestLayout

```
 public void requestLayout() {
        if (mMeasureCache != null) mMeasureCache.clear();

        if (mAttachInfo != null && mAttachInfo.mViewRequestingLayout == null) {
            // Only trigger request-during-layout logic if this is the view requesting it,
            // not the views in its parent hierarchy
            ViewRootImpl viewRoot = getViewRootImpl();
            if (viewRoot != null && viewRoot.isInLayout()) {
                if (!viewRoot.requestLayoutDuringLayout(this)) {
                    return;
                }
            }
            mAttachInfo.mViewRequestingLayout = this;
        }
        //PFLAG_FORCE_LAYOUT会在执行View的measure()和layout()方法时判断
        mPrivateFlags |= PFLAG_FORCE_LAYOUT;
        mPrivateFlags |= PFLAG_INVALIDATED;

        if (mParent != null && !mParent.isLayoutRequested()) {
            mParent.requestLayout();
        }
        if (mAttachInfo != null && mAttachInfo.mViewRequestingLayout == this) {
            mAttachInfo.mViewRequestingLayout = null;
        }
    }
```
>   mParent.requestLayout();

mParent为ViewParent（interface）的实例，调到ViewGroup的requestLayout（改方法在View中实现）。
ViewRootImpl也实现了ViewParent接口，并重写了requestlayout

```
@Override
    public void requestLayout() {
        if (!mHandlingLayoutInLayoutRequest) {
            checkThread();
            mLayoutRequested = true;
            scheduleTraversals();
        }
    }
    
    
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
    
    
    final class TraversalRunnable implements Runnable {
        @Override
        public void run() {
            doTraversal();
        }
    }
    
     void doTraversal() {
        if (mTraversalScheduled) {
            mTraversalScheduled = false;
            mHandler.getLooper().getQueue().removeSyncBarrier(mTraversalBarrier);

            if (mProfile) {
                Debug.startMethodTracing("ViewAncestor");
            }

            performTraversals();

            if (mProfile) {
                Debug.stopMethodTracing();
                mProfile = false;
            }
        }
    }
```
经过一些流程可以走到ViewRootImpl的performTraversals()方法中。
 当requestlayout的时候mLayoutRequested = true，之后会顺利走到performMeasure。

performTraversals() -> performLayout()->view.layout
performMeasure -> view.measure


该方法递归调用父View的invalidateChildInParent()方法，直到调用ViewRootImpl的invalidateChildInParent()方法，最终触发ViewRootImpl的performTraversals()方法，此时mLayoutRequestede为false，不会 触发onMesaure()与onLayout()方法，

###### requestlayout 导致invalidate的情况
    
    layout中判断的位置是否变化，然后setFrame()会掉导致重绘


```
  public void layout(int l, int t, int r, int b) {
       

        boolean changed = isLayoutModeOptical(mParent) ?
                setOpticalFrame(l, t, r, b) : setFrame(l, t, r, b);
                
                
                
    }
    
     protected boolean setFrame(int left, int top, int right, int bottom) {
        boolean changed = false;

       
        if (mLeft != left || mRight != right || mTop != top || mBottom != bottom) {
            changed = true;

            // Remember our drawn bit
            int drawn = mPrivateFlags & PFLAG_DRAWN;

            int oldWidth = mRight - mLeft;
            int oldHeight = mBottom - mTop;
            int newWidth = right - left;
            int newHeight = bottom - top;
            boolean sizeChanged = (newWidth != oldWidth) || (newHeight != oldHeight);

            // Invalidate our old position
            invalidate(sizeChanged);

        
```


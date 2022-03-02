### Activity finish流程



- ActivityManagerService.finishActivity--->
- ActivityStack.requestFinishActivityLocked--->
- ActivityStack.finishActivityLocked



```

final boolean finishActivityLocked(ActivityRecord r, int resultCode, Intent resultData,
        String reason, boolean oomAdj) {
 
    r.makeFinishingLocked();//把当前的Activity修改成 finishing = true状态
   
    r.pauseKeyDispatchingLocked();  //停止key分发

    adjustFocusedActivityLocked(r, "finishActivity");

    finishActivityResultsLocked(r, resultCode, resultData);

    final boolean endTask = index <= 0;
    final int transit = endTask ? TRANSIT_TASK_CLOSE : TRANSIT_ACTIVITY_CLOSE;
    if (mResumedActivity == r) {
        // Tell window manager to prepare for this one to be removed.
        mWindowManager.setAppVisibility(r.appToken, false);

        if (mPausingActivity == null) {
            startPausingLocked(false, false, null, false); //暂停当前Activity
        }

        if (endTask) {
            mStackSupervisor.removeLockedTaskLocked(task);
        }
    } else if (r.state != ActivityState.PAUSING) {
        // If the activity is PAUSING, we will complete the finish once
        // it is done pausing; else we can just directly finish it here.
        if (DEBUG_PAUSE) Slog.v(TAG_PAUSE, "Finish not pausing: " + r);
        if (r.visible) {
            mWindowManager.prepareAppTransition(transit, false);
            mWindowManager.setAppVisibility(r.appToken, false);
            mWindowManager.executeAppTransition();
            if (!mStackSupervisor.mWaitingVisibleActivities.contains(r)) {
                mStackSupervisor.mWaitingVisibleActivities.add(r);
            }
        }
        return finishCurrentActivityLocked(r, (r.visible || r.nowVisible) ?
                FINISH_AFTER_VISIBLE : FINISH_AFTER_PAUSE, oomAdj) == null;
    } else {
        if (DEBUG_PAUSE) Slog.v(TAG_PAUSE, "Finish waiting for pause of: " + r);
    }

    return false;
}
```



```

private void adjustFocusedActivityLocked(ActivityRecord r, String reason) {
    final ActivityRecord next = topRunningActivityLocked();//获取到就是下一个要启动的Activity
    if (next != r) {//ｒ是当前的Activity，但next 就是下一个要启动的Activity
            mService.setFocusedActivityLocked(next, myReason);
            return;
    }     
         // AMS下一个Activity设置成Focused
        mService.setFocusedActivityLocked(mStackSupervisor.topRunningActivityLocked()
}
```

在setFocusedActivityLocked里面会调用

- ActivityStackSupervisor.moveActivityStackToFront
- ActivityStack.moveToFront，把将要启动Activity对应的task放到最顶端；

ActivityStack.finishActivityLocked方法之后会调用

- ActivityStack.startPausingLocked

- ActivityStack.activityPausedLocked

- ActivityStack.completePauseLocked

- ActivityStack.resumeTopActivityInnerLocked，最后调到resumeTopActivityInnerLocked－－－scheduleResumeActivity显示下一个Activity

  

下一个Activity正常onResume显示时候会调用IdleInternal接口然后执行

- ActivityStackSupervisor$ActivityStackSupervisorHandler.activityIdleInternal
- ActivityStackSupervisor.activityIdleInternalLocked－－－》
- ActivityStack.finishCurrentActivityLocked－－》
- ActivityStack.destroyActivityLocked
  这时候正式调用之前上一个Activity的onStop和onDestroy并且将它从系统中finish，移除系统列表；
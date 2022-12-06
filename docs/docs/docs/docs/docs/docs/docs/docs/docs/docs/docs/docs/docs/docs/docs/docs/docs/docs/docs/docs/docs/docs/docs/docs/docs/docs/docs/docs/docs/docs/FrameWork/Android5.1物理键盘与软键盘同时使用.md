# 解决Android物理键盘与软键盘的同时使用

在android 5.1系统中插入扫码枪物理设备后，软键盘无法弹出的问题。

##### 1. 在代码frameworks/base/services/core/java/com/android/server/wm/WindowManagerService.java中，如果把updateShowImeWithHardKeyboard()方法中的showImeWithHardKeyboard变量直接置为true，则可以实现软键盘与物理键盘的同时使用，但这样修改影响较大(哪些影响？)，不推荐。==


```
public void updateShowImeWithHardKeyboard() {
    //final boolean showImeWithHardKeyboard = Settings.Secure.getIntForUser(
    //mContext.getContentResolver(), Settings.Secure.SHOW_IME_WITH_HARD_KEYBOARD, 0,
    //mCurrentUserId) == 1;
    final  boolean  showImeWithHardKeyboard  =  true;
    synchronized (mWindowMap) {
    if (mShowImeWithHardKeyboard != showImeWithHardKeyboard) {
        mShowImeWithHardKeyboard = showImeWithHardKeyboard;
        mH.sendEmptyMessage(H.SEND_NEW_CONFIGURATION);
        }   
   }
} 
```
##### 2 在代码frameworks/base/core/java/android/inputmethodservice/InputMethodService.java类的第1143行，修改onEvaluateInputViewShown()方法直接返回true


```
public boolean onEvaluateInputViewShown() {
    Configuration config = getResources().getConfiguration();
    //return config.keyboard == Configuration.KEYBOARD_NOKEYS
    //      || config.hardKeyboardHidden == Configuration.HARDKEYBOARDHIDDEN_YES;
    return  true;
}
```


---

[解决Android 5.1物理键盘与软键盘的同时使用](https://blog.csdn.net/u014770862/article/details/52459166)
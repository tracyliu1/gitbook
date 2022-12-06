

## Audio Device Strategy 音频设备输出选择 7.0





1. 首先我们会获取当前存在的设备集合availableOutputDevices

2.  然后根据传入的strategty类型进行匹配选择

3. 在选择之前会先检测是否处于特殊情况下（如通话中）

4. 最后按照优先级匹配设备。

关于音频设备选择的策略定义在AudioPolicyManager中的getDeviceForStrategy()方法，会根据当时设备的状态和连接设备选择最合适的设备，具体实现在frameworks/av/services/audiopolicy/enginedefault/src/Engine.cpp中。





以下注释解释很清楚，参数为strategy和fromCache，如果fromCache = true,则从mDeviceForStrategy[]选择，否则继续往下走。 

mDeviceForStrategy[NUM_STRATEGIES] 是一个数组。

```
frameworks/av/services/audiopolicy/common/include/RoutingStrategy.h
 enum routing_strategy {
    STRATEGY_MEDIA,
    STRATEGY_PHONE,
    STRATEGY_SONIFICATION,
    STRATEGY_SONIFICATION_RESPECTFUL,
    STRATEGY_DTMF,
    STRATEGY_ENFORCED_AUDIBLE,
    STRATEGY_TRANSMITTED_THROUGH_SPEAKER,
    STRATEGY_ACCESSIBILITY,
    STRATEGY_REROUTING,
    NUM_STRATEGIES
};
 
```



> frameworks/av/services/audiopolicy/managerdefault/AudioPolicyManager.h

```cpp
// return appropriate device for streams handled by the specified strategy according to current
// phone state, connected devices...
// if fromCache is true, the device is returned from mDeviceForStrategy[],
// otherwise it is determine by current state
// (device connected,phone state, force use, a2dp output...)
// This allows to:
//  1 speed up process when the state is stable (when starting or stopping an output)
//  2 access to either current device selection (fromCache == true) or
// "future" device selection (fromCache == false) when called from a context
//  where conditions are changing (setDeviceConnectionState(), setPhoneState()...) AND
//  before updateDevicesAndOutputs() is called.


virtual audio_devices_t getDeviceForStrategy(routing_strategy strategy,
                                             bool fromCache);
```



#### 1.1 AudioPolicyManager.cpp中的具体实现

>  frameworks/av/services/audiopolicy/managerdefault/AudioPolicyManager.cpp

##### 以下逻辑均涉及getDeviceForStrategy的调用

- void AudioPolicyManager::setPhoneState(audio_mode_t state)

- audio_io_handle_t AudioPolicyManager::getOutput(audio_stream_type_t stream ---）

- status_t AudioPolicyManager::getOutputForAttr

- status_t AudioPolicyManager::startOutput(

- status_t AudioPolicyManager::getStreamVolumeIndex(audio_stream_type_t stream,int *index  audio_devices_t device)

- audio_io_handle_t AudioPolicyManager::getOutputForEffect(const effect_descriptor_t *desc)

- void AudioPolicyManager::checkStrategyRoute(routing_strategy strategy, audio_io_handle_t ouptutToSkip)

- status_t AudioPolicyManager::connectAudioSource(const sp<AudioSourceDescriptor>& sourceDesc){

- void AudioPolicyManager::checkStrategyRoute(routing_strategy strategy,audio_io_handle_t ouptutToSkip){

- void AudioPolicyManager::checkOutputForStrategy(routing_strategy strategy)

- audio_devices_t AudioPolicyManager::getNewOutputDevice(const sp<AudioOutputDescriptor>& outputDesc, bool fromCache)

- audio_devices_t AudioPolicyManager::getDevicesForStream(audio_stream_type_t stream) {

- void AudioPolicyManager::updateDevicesAndOutputs()

- uint32_t AudioPolicyManager::checkDeviceMuteStrategies(sp<AudioOutputDescriptor> 

- float AudioPolicyManager::computeVolume(audio_stream_type_t stream,

- void AudioPolicyManager::handleIncallSonification(audio_stream_type_t stream,bool starting, bool stateChange)

- status_t AudioPolicyManager::setDeviceConnectionStateInt(audio_devices_t device,

  

```cpp
audio_devices_t AudioPolicyManager::getDeviceForStrategy(routing_strategy strategy,
                                                         bool fromCache)
{
    // Routing
    // see if we have an explicit route
    // scan the whole RouteMap, for each entry, convert the stream type to a strategy
    // (getStrategy(stream)).
    // if the strategy from the stream type in the RouteMap is the same as the argument above,
    // and activity count is non-zero
    // the device = the device from the descriptor in the RouteMap, and exit.
    for (size_t routeIndex = 0; routeIndex < mOutputRoutes.size(); routeIndex++) {
        sp<SessionRoute> route = mOutputRoutes.valueAt(routeIndex);
        routing_strategy routeStrategy = getStrategy(route->mStreamType); //仍旧调用getDeviceForStrategy
        if ((routeStrategy == strategy) && route->isActive()) {
            return route->mDeviceDescriptor->type();
        }
    }

    if (fromCache) {
        ALOGVV("getDeviceForStrategy() from cache strategy %d, device %x",
              strategy, mDeviceForStrategy[strategy]);
        return mDeviceForStrategy[strategy];
    }
    return mEngine->getDeviceForStrategy(strategy);
}
```



##### 具体实现在Engine.cpp中

frameworks/av/services/audiopolicy/enginedefault/src/Engine.cpp

```cpp
routing_strategy Engine::getStrategyForStream(audio_stream_type_t stream)
{
    // stream to strategy mapping
    switch (stream) {
    case AUDIO_STREAM_VOICE_CALL:
    case AUDIO_STREAM_BLUETOOTH_SCO:
        return STRATEGY_PHONE;
    case AUDIO_STREAM_RING:
    case AUDIO_STREAM_ALARM:
        return STRATEGY_SONIFICATION;
    case AUDIO_STREAM_NOTIFICATION:
        return STRATEGY_SONIFICATION_RESPECTFUL;
    case AUDIO_STREAM_DTMF:
        return STRATEGY_DTMF;
    default:
        ALOGE("unknown stream type %d", stream);
    case AUDIO_STREAM_SYSTEM:
        // NOTE: SYSTEM stream uses MEDIA strategy because muting music and switching outputs
        // while key clicks are played produces a poor result
    case AUDIO_STREAM_MUSIC:
        return STRATEGY_MEDIA;
    case AUDIO_STREAM_ENFORCED_AUDIBLE:
        return STRATEGY_ENFORCED_AUDIBLE;
    case AUDIO_STREAM_TTS:
        return STRATEGY_TRANSMITTED_THROUGH_SPEAKER;
    case AUDIO_STREAM_ACCESSIBILITY:
        return STRATEGY_ACCESSIBILITY;
    case AUDIO_STREAM_REROUTING:
        return STRATEGY_REROUTING;
    }
}
```

```cpp
audio_devices_t Engine::getDeviceForStrategy(routing_strategy strategy) const
{
    DeviceVector availableOutputDevices = mApmObserver->getAvailableOutputDevices();
    DeviceVector availableInputDevices = mApmObserver->getAvailableInputDevices();

    const SwAudioOutputCollection &outputs = mApmObserver->getOutputs();

    return getDeviceForStrategyInt(strategy, availableOutputDevices,
                                   availableInputDevices, outputs);
}
```



#### 1.2 针对STRATEGY_MEDIA分析，播放设备优先级如下

- AUDIO_DEVICE_OUT_BLUETOOTH_A2DP
- AUDIO_DEVICE_OUT_BLUETOOTH_A2DP_HEADPHONES(普通蓝牙耳机)
- AUDIO_DEVICE_OUT_BLUETOOTH_A2DP_SPEAKER(蓝牙小音箱)
  //此处属于setForceUse的强制插队
  (if FORCE_SPEAKER)AUDIO_DEVICE_OUT_SPEAKER(扬声器)
- AUDIO_DEVICE_OUT_WIRED_HEADPHONE(普通耳机，只能听，不能操控播放)
- AUDIO_DEVICE_OUT_LINE
- AUDIO_DEVICE_OUT_WIRED_HEADSET(线控耳机)
- AUDIO_DEVICE_OUT_USB_HEADSET(USB耳机)

```cpp
case STRATEGY_MEDIA: {
        uint32_t device2 = AUDIO_DEVICE_NONE;

        if (isInCall() && (device == AUDIO_DEVICE_NONE)) {  //针对通话
            // when in call, get the device for Phone strategy
            device = getDeviceForStrategy(STRATEGY_PHONE);
            break;
        }

        if (strategy != STRATEGY_SONIFICATION) {//和提示做特别处理
            // no sonification on remote submix (e.g. WFD)
            if (availableOutputDevices.getDevice(AUDIO_DEVICE_OUT_REMOTE_SUBMIX,
                                                 String8("0")) != 0) {
                device2 = availableOutputDevices.types() & AUDIO_DEVICE_OUT_REMOTE_SUBMIX;
            }
        }
        if (isInCall() && (strategy == STRATEGY_MEDIA)) {
            device = getDeviceForStrategyInt(
                    STRATEGY_PHONE, availableOutputDevices, availableInputDevices, outputs);
            break;
        }
        if ((device2 == AUDIO_DEVICE_NONE) &&
                (mForceUse[AUDIO_POLICY_FORCE_FOR_MEDIA] != AUDIO_POLICY_FORCE_NO_BT_A2DP) &&
                (outputs.isA2dpOnPrimary() || (outputs.getA2dpOutput() != 0))) {
            device2 = availableOutputDevicesType & AUDIO_DEVICE_OUT_BLUETOOTH_A2DP;   //A2DP
            if (device2 == AUDIO_DEVICE_NONE) {
                device2 = availableOutputDevicesType & AUDIO_DEVICE_OUT_BLUETOOTH_A2DP_HEADPHONES; //蓝牙耳机
            }
            if (device2 == AUDIO_DEVICE_NONE) {
                device2 = availableOutputDevicesType & AUDIO_DEVICE_OUT_BLUETOOTH_A2DP_SPEAKER; //蓝牙音箱
            }
        }
        if ((device2 == AUDIO_DEVICE_NONE) &&
            (mForceUse[AUDIO_POLICY_FORCE_FOR_MEDIA] == AUDIO_POLICY_FORCE_SPEAKER)) {//如果force speker 扬声器 喇叭
            device2 = availableOutputDevicesType & AUDIO_DEVICE_OUT_SPEAKER;
        }
        if (device2 == AUDIO_DEVICE_NONE) {
            device2 = availableOutputDevicesType & AUDIO_DEVICE_OUT_WIRED_HEADPHONE; //普通有线耳机 不带麦克风
        }
        if (device2 == AUDIO_DEVICE_NONE) {
            device2 = availableOutputDevicesType & AUDIO_DEVICE_OUT_LINE;
        }
        if (device2 == AUDIO_DEVICE_NONE) {
            device2 = availableOutputDevicesType & AUDIO_DEVICE_OUT_WIRED_HEADSET; //带麦克风的有线耳机
        }
        if (device2 == AUDIO_DEVICE_NONE) {
            device2 = availableOutputDevicesType & AUDIO_DEVICE_OUT_USB_ACCESSORY;
        }
        if (device2 == AUDIO_DEVICE_NONE) {
            device2 = availableOutputDevicesType & AUDIO_DEVICE_OUT_USB_DEVICE;  //USB设备 
        }
        if (device2 == AUDIO_DEVICE_NONE) {
            device2 = availableOutputDevicesType & AUDIO_DEVICE_OUT_DGTL_DOCK_HEADSET;
        }
        if ((strategy != STRATEGY_SONIFICATION) && (device == AUDIO_DEVICE_NONE)
            && (device2 == AUDIO_DEVICE_NONE)) {
            // no sonification on aux digital (e.g. HDMI)
            device2 = availableOutputDevicesType & AUDIO_DEVICE_OUT_AUX_DIGITAL;
        }
        if ((device2 == AUDIO_DEVICE_NONE) &&
                (mForceUse[AUDIO_POLICY_FORCE_FOR_DOCK] == AUDIO_POLICY_FORCE_ANALOG_DOCK)
                && (strategy != STRATEGY_SONIFICATION)) {
            device2 = availableOutputDevicesType & AUDIO_DEVICE_OUT_ANLG_DOCK_HEADSET;
        }
#ifdef AUDIO_EXTN_AFE_PROXY_ENABLED
        if ((strategy != STRATEGY_SONIFICATION) && (device == AUDIO_DEVICE_NONE)
            && (device2 == AUDIO_DEVICE_NONE)) {
            // no sonification on WFD sink
            device2 = availableOutputDevicesType & AUDIO_DEVICE_OUT_PROXY;
        }
#endif
        if (device2 == AUDIO_DEVICE_NONE) {
            device2 = availableOutputDevicesType & AUDIO_DEVICE_OUT_SPEAKER; // 外放 扬声器 喇叭
        }
        int device3 = AUDIO_DEVICE_NONE;
        if (strategy == STRATEGY_MEDIA) {///如果arc,spdif,aux_line可用,赋值给device3
            // ARC, SPDIF and AUX_LINE can co-exist with others.
            device3 = availableOutputDevicesType & AUDIO_DEVICE_OUT_HDMI_ARC;
            device3 |= (availableOutputDevicesType & AUDIO_DEVICE_OUT_SPDIF);
            device3 |= (availableOutputDevicesType & AUDIO_DEVICE_OUT_AUX_LINE);
        }

        device2 |= device3;
        // device is DEVICE_OUT_SPEAKER if we come from case STRATEGY_SONIFICATION or
        // STRATEGY_ENFORCED_AUDIBLE, AUDIO_DEVICE_NONE otherwise
        device |= device2;

        // If hdmi system audio mode is on, remove speaker out of output list.
        if ((strategy == STRATEGY_MEDIA) &&
            (mForceUse[AUDIO_POLICY_FORCE_FOR_HDMI_SYSTEM_AUDIO] ==
                AUDIO_POLICY_FORCE_HDMI_SYSTEM_AUDIO_ENFORCED)) {
            device &= ~AUDIO_DEVICE_OUT_SPEAKER;
        }
        } break;
```

---



[Android中实现录制内置声音](https://juejin.cn/post/6844903705561530382)
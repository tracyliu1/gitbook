## Audio Device Strategy 音频设备 输入选择 7.0

### 1.输入设备选择

#### 1.1 MediaRecorder java层setAudioSource

以MediaRecorder为例，不考虑其他。setAudioSource设置输入源

```javascript
   mMediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);// 设置麦克风
```

>  frameworks/base/media/java/android/media/MediaRecorder.java   

AudioSource共定义以下几种

```cpp
/** Default audio source **/
public static final int DEFAULT = 0; //默认
/** Microphone audio source */
public static final int MIC = 1; //麦克
/** Voice call uplink (Tx) audio source */
public static final int VOICE_UPLINK = 2; //电话上行
/** Voice call downlink (Rx) audio source */
public static final int VOICE_DOWNLINK = 3; //电话下行
/** Voice call uplink + downlink audio source */
public static final int VOICE_CALL = 4;  //电话录音
/** Microphone audio source with same orientation as camera if available, the main
 *  device microphone otherwise */
public static final int CAMCORDER = 5;  //摄像头麦克
public static final int VOICE_RECOGNITION = 6; //语音识别
public static final int VOICE_COMMUNICATION = 7;//网络电话
public static final int REMOTE_SUBMIX = 8; //用于内录
public static final int UNPROCESSED = 9;  //未处理原始声音
@SystemApi
public static final int RADIO_TUNER = 1998; //广播
@SystemApi
public static final int HOTWORD = 1999;
```

继续看MediaRecorder

```cpp
public native void setAudioSource(int audio_source)
        throws IllegalStateException;
```

通过JNI调用到mediarecorder.cpp

> frameworks/base/media/jni/android_media_MediaRecorder.cpp

```cpp
static void
android_media_MediaRecorder_setVideoSource(JNIEnv *env, jobject thiz, jint vs)
{
    sp<MediaRecorder> mr = getMediaRecorder(env, thiz);
}
```

> frameworks/av/media/libmedia/mediarecorder.cpp

```cpp
status_t MediaRecorder::setAudioSource(int as){
 status_t ret = mMediaRecorder->setAudioSource(as);
}
```

#### 1.2 mMediaRecorder是谁

在看mMediaRecorder实例，是一个IMediaPlayerService 的service对象，调用了createMediaRecorder()

```cpp
MediaRecorder::MediaRecorder(const String16& opPackageName) : mSurfaceMediaSource(NULL)
{
    const sp<IMediaPlayerService> service(getMediaPlayerService());
    if (service != NULL) {
        mMediaRecorder = service->createMediaRecorder(opPackageName);
    }
}
```

> frameworks/av/media/libmedia/IMediaPlayerService.cpp

下面就是明显的binder操作，BnMediaPlayerService 定义了如下

```cpp
virtual sp<IMediaRecorder> createMediaRecorder(const String16 &opPackageName)
{
    Parcel data, reply;
    data.writeInterfaceToken(IMediaPlayerService::getInterfaceDescriptor());
    data.writeString16(opPackageName);
    remote()->transact(CREATE_MEDIA_RECORDER, data, &reply);
    return interface_cast<IMediaRecorder>(reply.readStrongBinder());
}
```

MediaPlayerService继承BnMediaPlayerService

> frameworks/av/media/libmediaplayerservice/MediaPlayerService.h

```
class MediaPlayerService : public BnMediaPlayerService
```

这就通过binder来到了MediaRecorderClient，可知recorder对象就是MediaRecorderClient

> frameworks/av/media/libmediaplayerservice/MediaPlayerService.cpp

```cpp
sp<IMediaRecorder> MediaPlayerService::createMediaRecorder(const String16 &opPackageName){
    sp<MediaRecorderClient> recorder = new MediaRecorderClient(this, pid, opPackageName);
    return recorder;
}
```

#### 1.3 MediaRecorderClient.cpp的setAudioSource

到这里可以继续看setAudioSource了

> frameworks/av/media/libmediaplayerservice/MediaRecorderClient.cpp

```cpp
status_t MediaRecorderClient::setAudioSource(int as)
{
    return mRecorder->setAudioSource((audio_source_t)as);
}
MediaRecorderBase      *mRecorder;
```

mRecorder为MediaRecorderBase实例，StagefrightRecorder继承于MediaRecorderBase，这里继续看StagefrightRecorder

> frameworks/av/media/libmediaplayerservice/StagefrightRecorder.cpp

```cpp
struct StagefrightRecorder : public MediaRecorderBase {
status_t StagefrightRecorder::setAudioSource(audio_source_t as) {
   
    if (as == AUDIO_SOURCE_DEFAULT) {
        mAudioSource = AUDIO_SOURCE_MIC;
    } else {
        mAudioSource = as;
    }
}
}
```

StagefrightRecorder中会根据mAudioSource去创建audioSource……

```cpp
sp<MediaCodecSource> StagefrightRecorder::createAudioSource() {
 
sp<AudioSource> audioSource = AVFactory::get()->createAudioSource(           
}
```

> frameworks/av/media/libavextensions/stagefright/AVFactory.cpp

```cpp
AudioSource* AVFactory::createAudioSource(
    return new AudioSource(inputSource, opPackageName, sampleRate,
                            channels, outSampleRate, clientUid, clientPid);
}
```

AudioSource中有创建了AudioRecord

> frameworks/av/media/libstagefright/AudioSource.cpp

```cpp
mRecord = new AudioRecord(inputSource, sampleRate, AUDIO_FORMAT_PCM_16_BIT, 
```

以下代码在AudioRecord的构造方法中，inputsource是我们上边传入的参数。

>  frameworks/av/media/libmedia/AudioRecord.cpp 

```
mStatus = set(inputSource, sampleRate, format, channelMask, frameCount, cbf, user,
        notificationFrames, false /*threadCanCallJava*/, sessionId, transferType, flags,
        uid, pid, pAttributes);
 //set方法       
set(){
 if (pAttributes == NULL) {
        mAttributes.source = inputSource;
    } 
}        
```

mAttributes应用在openRecord_l方法中，可以看到AudioSystem调用了getInputForAttr

```cpp
status_t AudioRecord::openRecord_l(const Modulo<uint32_t> &epoch, const String16& opPackageName)
{
status = AudioSystem::getInputForAttr(&mAttributes, &input,mSessionId,mClientPid,mClientUid,mSampleRate, mFormat, mChannelMask,
                                        mFlags, mSelectedDeviceId);
}
```

> frameworks/av/media/libmedia/AudioSystem.cpp

```cpp
status_t AudioSystem::getInputForAttr(const audio_attributes_t *attr,)
{
    const sp<IAudioPolicyService>& aps = AudioSystem::get_audio_policy_service();
    if (aps == 0) return NO_INIT;
    return aps->getInputForAttr(
            attr, input, session, pid, uid,
            samplingRate, format, channelMask, flags, selectedDeviceId);
}
```

> frameworks/av/media/libmedia/IAudioPolicyService.cpp

重点关注aps，是IAudioPolicyService。点进去发现又是binder

```cpp
virtual status_t getInputForAttr(const audio_attributes_t *attr,){
  status_t status = remote()->transact(GET_INPUT_FOR_ATTR, data, &reply);

}
```

> frameworks/av/services/audiopolicy/service/AudioPolicyService.h

```cpp
class AudioPolicyService :
    public BinderService<AudioPolicyService>,
    public BnAudioPolicyService,
```

AudioPolicyService 继承 BnAudioPolicyService，BnAudioPolicyService实现于 AudioPolicyInterface，AudioPolicyManager又继承AudioPolicyInterface。终于来到了AudioPolicyManager.cpp

#### 1.4 AudioPolicyManager.cpp中的策略

> frameworks/av/services/audiopolicy/managerdefault/AudioPolicyManager.cpp

```cpp
device = getDeviceAndMixForInputSource(inputSource, &policyMix); 
*input = getInputForDevice(device, address, session, uid, inputSource,
                               samplingRate, format, channelMask, flags,
                               policyMix);
```



```cpp
audio_devices_t AudioPolicyManager::getDeviceForInputSource(audio_source_t inputSource)
{
    for (size_t routeIndex = 0; routeIndex < mInputRoutes.size(); routeIndex++) {
         sp<SessionRoute> route = mInputRoutes.valueAt(routeIndex);
         if (inputSource == route->mSource && route->isActive()) {
             return route->mDeviceDescriptor->type();
         }
     }

     return mEngine->getDeviceForInputSource(inputSource);
}
```

##### 以下为具体策略

> frameworks/av/services/audiopolicy/enginedefault/src/Engine.cpp

```cpp
audio_devices_t Engine::getDeviceForInputSource(audio_source_t inputSource) const
{
    const DeviceVector &availableOutputDevices = mApmObserver->getAvailableOutputDevices();
    const DeviceVector &availableInputDevices = mApmObserver->getAvailableInputDevices();
    const SwAudioOutputCollection &outputs = mApmObserver->getOutputs();
    audio_devices_t availableDeviceTypes = availableInputDevices.types() & ~AUDIO_DEVICE_BIT_IN;

    uint32_t device = AUDIO_DEVICE_NONE;

    switch (inputSource) {
    case AUDIO_SOURCE_VOICE_UPLINK:
      if (availableDeviceTypes & AUDIO_DEVICE_IN_VOICE_CALL) {
          device = AUDIO_DEVICE_IN_VOICE_CALL;
          break;
      }
      break;

    case AUDIO_SOURCE_DEFAULT:
    case AUDIO_SOURCE_MIC:
    if (availableDeviceTypes & AUDIO_DEVICE_IN_BLUETOOTH_A2DP) {  //A2DP
        device = AUDIO_DEVICE_IN_BLUETOOTH_A2DP;
    } else if ((mForceUse[AUDIO_POLICY_FORCE_FOR_RECORD] == AUDIO_POLICY_FORCE_BT_SCO) && //如果强制蓝牙 优先蓝牙耳机
        (availableDeviceTypes & AUDIO_DEVICE_IN_BLUETOOTH_SCO_HEADSET)) {
        device = AUDIO_DEVICE_IN_BLUETOOTH_SCO_HEADSET;
    } else if (availableDeviceTypes & AUDIO_DEVICE_IN_WIRED_HEADSET) {//有线蓝牙
        device = AUDIO_DEVICE_IN_WIRED_HEADSET;
    } else if (availableDeviceTypes & AUDIO_DEVICE_IN_USB_DEVICE) {//usb
        device = AUDIO_DEVICE_IN_USB_DEVICE;
    } else if (availableDeviceTypes & AUDIO_DEVICE_IN_BUILTIN_MIC) { //手机自带mic
        device = AUDIO_DEVICE_IN_BUILTIN_MIC;
    }
    break;

    case AUDIO_SOURCE_VOICE_COMMUNICATION:
        // Allow only use of devices on primary input if in call and HAL does not support routing
        // to voice call path.
        if ((getPhoneState() == AUDIO_MODE_IN_CALL) &&
                (availableOutputDevices.types() & AUDIO_DEVICE_OUT_TELEPHONY_TX) == 0) {
            sp<AudioOutputDescriptor> primaryOutput = outputs.getPrimaryOutput();
            availableDeviceTypes =
                    availableInputDevices.getDevicesFromHwModule(primaryOutput->getModuleHandle())
                    & ~AUDIO_DEVICE_BIT_IN;
        }

        switch (mForceUse[AUDIO_POLICY_FORCE_FOR_COMMUNICATION]) {
        case AUDIO_POLICY_FORCE_BT_SCO:
            // if SCO device is requested but no SCO device is available, fall back to default case
            if (availableDeviceTypes & AUDIO_DEVICE_IN_BLUETOOTH_SCO_HEADSET) {
                device = AUDIO_DEVICE_IN_BLUETOOTH_SCO_HEADSET;
                break;
            }
            // FALL THROUGH

        default:    // FORCE_NONE
            if (availableDeviceTypes & AUDIO_DEVICE_IN_WIRED_HEADSET) {
                device = AUDIO_DEVICE_IN_WIRED_HEADSET;
            } else if (availableDeviceTypes & AUDIO_DEVICE_IN_USB_DEVICE) {
                device = AUDIO_DEVICE_IN_USB_DEVICE;
            } else if (availableDeviceTypes & AUDIO_DEVICE_IN_BUILTIN_MIC) {
                device = AUDIO_DEVICE_IN_BUILTIN_MIC;
            }
            break;

        case AUDIO_POLICY_FORCE_SPEAKER:
            if (availableDeviceTypes & AUDIO_DEVICE_IN_BACK_MIC) {
                device = AUDIO_DEVICE_IN_BACK_MIC;
            } else if (availableDeviceTypes & AUDIO_DEVICE_IN_BUILTIN_MIC) {
                device = AUDIO_DEVICE_IN_BUILTIN_MIC;
            }
            break;
        }
        break;

    case AUDIO_SOURCE_VOICE_RECOGNITION:
    case AUDIO_SOURCE_UNPROCESSED:
    case AUDIO_SOURCE_HOTWORD:
        if (mForceUse[AUDIO_POLICY_FORCE_FOR_RECORD] == AUDIO_POLICY_FORCE_BT_SCO &&
                availableDeviceTypes & AUDIO_DEVICE_IN_BLUETOOTH_SCO_HEADSET) {
            device = AUDIO_DEVICE_IN_BLUETOOTH_SCO_HEADSET;
        } else if (availableDeviceTypes & AUDIO_DEVICE_IN_WIRED_HEADSET) {
            device = AUDIO_DEVICE_IN_WIRED_HEADSET;
        } else if (availableDeviceTypes & AUDIO_DEVICE_IN_USB_DEVICE) {
            device = AUDIO_DEVICE_IN_USB_DEVICE;
        } else if (availableDeviceTypes & AUDIO_DEVICE_IN_BUILTIN_MIC) {
            device = AUDIO_DEVICE_IN_BUILTIN_MIC;
        }
        break;
    case AUDIO_SOURCE_CAMCORDER:
        if (availableDeviceTypes & AUDIO_DEVICE_IN_BACK_MIC) {
            device = AUDIO_DEVICE_IN_BACK_MIC;
        } else if (availableDeviceTypes & AUDIO_DEVICE_IN_BUILTIN_MIC) {
            device = AUDIO_DEVICE_IN_BUILTIN_MIC;
        }
        break;
    case AUDIO_SOURCE_VOICE_DOWNLINK:
    case AUDIO_SOURCE_VOICE_CALL:
        if (availableDeviceTypes & AUDIO_DEVICE_IN_VOICE_CALL) {
            device = AUDIO_DEVICE_IN_VOICE_CALL;
        }
        break;
    case AUDIO_SOURCE_REMOTE_SUBMIX:
        if (availableDeviceTypes & AUDIO_DEVICE_IN_REMOTE_SUBMIX) {
            device = AUDIO_DEVICE_IN_REMOTE_SUBMIX;
        }
        break;
     case AUDIO_SOURCE_FM_TUNER:
        if (availableDeviceTypes & AUDIO_DEVICE_IN_FM_TUNER) {
            device = AUDIO_DEVICE_IN_FM_TUNER;
        }
        break;
    default:
        ALOGW("getDeviceForInputSource() invalid input source %d", inputSource);
        break;
    }
    if (device == AUDIO_DEVICE_NONE) {
        ALOGV("getDeviceForInputSource() no device found for source %d", inputSource);
        if (availableDeviceTypes & AUDIO_DEVICE_IN_STUB) {
            device = AUDIO_DEVICE_IN_STUB;
        }
        ALOGE_IF(device == AUDIO_DEVICE_NONE,
                 "getDeviceForInputSource() no default device defined");
    }
    ALOGV("getDeviceForInputSource()input source %d, device %08x", inputSource, device);
    return device;
}
```



---

[Android-MediaRecorder之setAudioSource](https://blog.csdn.net/cheriyou_/article/details/105642626)

[Android两种改变音频输出/入设备的方式](https://www.jianshu.com/p/4c3704464741)
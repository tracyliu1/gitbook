## MediaPlayer 播放流程

### 1.MediaPlayer播放简介

从java层的Mediaplayer，通过JNI进行binder 连接到 mediaserver进程的 MediaPlayerService。MediaPlayerService中会根据传入的source，判断不同的播放器。



#### 1.1 MediaPlayer基本框架

Java层

> frameworks/base/media/java/android/media/MediaPlayer.java

JNI层  编译为 libmedia_jni.so

> frameworks/base/media/jni/android_media_MediaPlayer.cpp

Native层 编译为 libmedia.so

>  frameworks/av/media/libmedia/mediaplayer.cpp

Binder  编译为 libmedia.so

> frameworks/av/media/libmedia/IMediaPlayer.cpp

>  frameworks/av/media/libmedia/IMediaPlayerService.cpp

播放器  编译为 libmediaplayerservice.so

> frameworks/av/media/libmediaplayerservice/nuplayer/NuPlayer.cpp



![image-20210128092326307](/Users/tracyliu/Library/Application Support/typora-user-images/image-20210128092326307.png)



Binder可分为实名binder和匿名binder， 实名binder是在ServiceManager注册的servce，可以通过ServiceManager的getService获取，而匿名binder没在ServiceManager中注册，没法通过ServiceManager获取，需要想办法获取service的binder实例才能通讯。

对于MediaPlayer的结构，MediaPlayerServcie 属于实名binder，  IMediaPlayer 和 IMediaPlayerClient 属于匿名binder。MediaPlayer 通过 MediaPlayerServcie实名binder， 将IMediaPlayerClient binder 传递给MediaPlayerServcie，同时MediaPlayerServcie将IMediaPlayer binder返回MediaPlayer。 这样MediaPlayer 就能通过 IMediaPlayer 调用 MediaPlayerServcie::client接口， MediaPlayerServcie可以通过IMediaPlayerClient调用MediaPlayer接口



#### 1.2 MediaPlayer使用

这里主要分析setDataSource 、prepare、start

```
MediaPlayer = new MediaPlayer();

player.setDataSource(path);//*文件路径可以是*uri*，或者本地路径*

player.setAudioStreamType(AudioManager.STREAM_MUSIC);　//*设置流类型*

player.prepare();　//*调用*prepare*方法*

player.start();//*调用*start*开始播放
```



### 2.代码流程

![img](https://upload-images.jianshu.io/upload_images/10190436-d56764e08988f985.png?imageMogr2/auto-orient/strip|imageView2/2/w/665/format/webp)

#### 2.1 setDataSource流程

1. 从java层MediaPlayer.java，通过JNI调用到native层的mediaplayer.cpp
2. native层通过IMediaPlayerService binder调用，返回mediaserver进程中 MediaPlayerService中的client对象
3. MediaPlayerService中client，根据datasource类型创建对应播放器，一般为Nuplayer



> frameworks/base/media/java/android/media/MediaPlayer.java

```java
public void setDataSource(FileDescriptor fd, long offset, long length)
        throws IOException, IllegalArgumentException, IllegalStateException {
    _setDataSource(fd, offset, length);
}

private native void _setDataSource(FileDescriptor fd, long offset, long length)
        throws IOException, IllegalArgumentException, IllegalStateException;
```

> frameworks/base/media/jni/android_media_MediaPlayer.cpp

```cpp
static void
android_media_MediaPlayer_setDataSourceFD(JNIEnv *env, jobject thiz, jobject fileDescriptor, jlong offset, jlong length)
{
    sp<MediaPlayer> mp = getMediaPlayer(env, thiz);
    //调用native层MediaPlayer实例mp的setdatasource，process_media_player_call负责抛出异常和错误
    process_media_player_call( env, thiz, mp->setDataSource(fd, offset, length), "java/io/IOException", "setDataSourceFD failed." );
}
```

> frameworks/av/media/libmedia/mediaplayer.cpp

```cpp
status_t MediaPlayer::setDataSource(int fd, int64_t offset, int64_t length){   
    const sp<IMediaPlayerService> service(getMediaPlayerService());
    if (service != 0) {
      //调用mps的create方法，创建一个IMediaPlayer实例，作为应用端的mediaplayer跟mediaserver进程间的跨进程通信桥梁。
      //IMediaPlayer对应服务端的实现是mediaplayerservice.cpp的内部类Client
        sp<IMediaPlayer> player(service->create(this, mAudioSessionId)); //create操作
        player->setDataSource(fd, offset, length);
        err = attachNewPlayer(player);//保存这个MediaPlayerService:client
    }
    return err;
}
```

> frameworks/av/media/libmedia/IMediaPlayerService.cpp 

##### 先看create()操作 

位于IMediaPlayerService.cpp 中，可以看出是binder关系，对应的BnMediaPlayerService被MediaPlayerService继承实现

>  frameworks/av/media/libmediaplayerservice/MediaPlayerService.h

```cpp
class MediaPlayerService : public BnMediaPlayerService{
```

生成一个client对象并返回，client继承于BnMediaPlayer，BnMediaPlayer是IMediaPlayer的接口

```cpp
sp<IMediaPlayer> MediaPlayerService::create(const sp<IMediaPlayerClient>& client,
        audio_session_t audioSessionId){
    sp<Client> c = new Client(
            this, pid, connId, client, audioSessionId,
            IPCThreadState::self()->getCallingUid());
    return c;
}
```

##### 接下来再看player->setDataSource(fd, offset, length)，

通过传入参数判断playerType，具体在MediaPlayerService::Client中

```cpp
status_t MediaPlayerService::Client::setDataSource(int fd, int64_t offset, int64_t length){

    player_type playerType = MediaPlayerFactory::getPlayerType(this,fd,offset,length);//判断播放器类型
    sp<MediaPlayerBase> p = setDataSource_pre(playerType);//预处理
    // now set data source
    return mStatus = setDataSource_post(p, p->setDataSource(fd, offset, length));//判断status状态 如果ok mPlayer = p;
}
```

setDataSource_pre 首先根据播放类型创建播放器，并创建AudioOutput对象。

```cpp
sp<MediaPlayerBase> MediaPlayerService::Client::setDataSource_pre(player_type playerType){
 
    sp<MediaPlayerBase> p = createPlayer(playerType);// 最终new   NuPlayerDriver
    if (!p->hardwareOutput()) {
        mAudioOutput = new AudioOutput(mAudioSessionId, IPCThreadState::self()->getCallingUid(),
                mPid, mAudioAttributes);
        static_cast<MediaPlayerInterface*>(p.get())->setAudioSink(mAudioOutput);
    }
    return p;
}
```

NuPlayerDriver 的 setDataSource()    mPlayer是 NuPlayer

> frameworks/av/media/libmediaplayerservice/nuplayer/NuPlayerDriver.cpp

```cpp
status_t NuPlayerDriver::setDataSource(int fd, int64_t offset, int64_t length) {
    mPlayer->setDataSourceAsync(fd, offset, length); //NuPlayer
    return mAsyncResult;
}
```

setDataSourceAsync中根据不同情况初始化了source的类型

> frameworks/av/media/libmediaplayerservice/nuplayer/NuPlayer.cpp

```cpp
void NuPlayer::setDataSourceAsync(
        const sp<IMediaHTTPService> &httpService,
        const char *url,
        const KeyedVector<String8, String8> *headers) {

    sp<AMessage> msg = new AMessage(kWhatSetDataSource, this);
    size_t len = strlen(url);

    sp<AMessage> notify = new AMessage(kWhatSourceNotify, this);

    sp<Source> source;
    if (IsHTTPLiveURL(url)) {
        source = new HTTPLiveSource(notify, httpService, url, headers);
    } else if (!strncasecmp(url, "rtsp://", 7)) {
        source = new RTSPSource(
                notify, httpService, url, headers, mUIDValid, mUID);
    } else if ((!strncasecmp(url, "http://", 7)
                || !strncasecmp(url, "https://", 8))
                    && ((len >= 4 && !strcasecmp(".sdp", &url[len - 4]))
                    || strstr(url, ".sdp?"))) {
        source = new RTSPSource(
                notify, httpService, url, headers, mUIDValid, mUID, true);
    } else {
        sp<GenericSource> genericSource =
                new GenericSource(notify, mUIDValid, mUID);
        // Don't set FLAG_SECURE on mSourceFlags here for widevine.
        // The correct flags will be updated in Source::kWhatFlagsChanged
        // handler when  GenericSource is prepared.

        status_t err = genericSource->setDataSource(httpService, url, headers);

        if (err == OK) {
            source = genericSource;
        } else {
            ALOGE("Failed to set data source!");
        }
    }
    msg->setObject("source", source);//这里的source 就是之后的mSource
    msg->post();
}
```

留坑，解码相关



#### 2.2 prepare()流程



> frameworks/base/media/java/android/media/MediaPlayer.java

```cpp
public void prepare() throws IOException, IllegalStateException {
    _prepare();
    scanInternalSubtitleTracks();
}
```

JNI

> frameworks/base/media/jni/android_media_MediaPlayer.cpp

```cpp
static voidandroid_media_MediaPlayer_prepare(JNIEnv *env, jobject thiz)
{
    sp<MediaPlayer> mp = getMediaPlayer(env, thiz);
    process_media_player_call( env, thiz, mp->prepare(), "java/io/IOException", "Prepare failed." );
}
```

>  frameworks/av/media/libmedia/mediaplayer.cpp

```cpp
status_t MediaPlayer::prepare()
{
    status_t ret = prepareAsync_l();
    return mPrepareStatus;
}

status_t MediaPlayer::prepareAsync_l()
{
    if ( (mPlayer != 0) && ( mCurrentState & (MEDIA_PLAYER_INITIALIZED | MEDIA_PLAYER_STOPPED) ) ) {
        if (mAudioAttributesParcel != NULL) {
            mPlayer->setParameter(KEY_PARAMETER_AUDIO_ATTRIBUTES, *mAudioAttributesParcel);
        } else {
            mPlayer->setAudioStreamType(mStreamType);
        }
        mCurrentState = MEDIA_PLAYER_PREPARING;
        return mPlayer->prepareAsync(); // 对应IMediaPlayer.cpp
    }
 
    return INVALID_OPERATION;
}
```

> frameworks/av/media/libmedia/IMediaPlayer.cpp

prepareAsync来到IMediaPlayer中，熟悉的binder，内部对应的BnMediaPlayer由 MediaPlayerService中的client实现

```
class Client : public BnMediaPlayer {
```

假设和上面一致，播放器p是 Nuplayer

```cpp
status_t MediaPlayerService::Client::prepareAsync()
{
    sp<MediaPlayerBase> p = getPlayer(); 
    status_t ret = p->prepareAsync();
    return ret;
}
```

> frameworks/av/media/libmediaplayerservice/nuplayer/NuPlayer.cpp

```cpp
void NuPlayer::prepareAsync() {
    (new AMessage(kWhatPrepare, this))->post();
}

 case kWhatPrepare:{
            mSource->prepareAsync(); //这里的mSource是 取决于setDataSource时传入的。
            break;
        }
```

留坑 解码相关

#### 2.3 start()流程

```cpp
public void start() throws IllegalStateException {
    baseStart(); //控制音量
    stayAwake(true);//控制wakelock
    _start();
}

private native void _start() throws IllegalStateException;
```

继续通过JNI来到

> frameworks/av/media/libmedia/mediaplayer.cpp

这里的mPlayer,attachNewPlayer中传入的player对象，是IMediaPlayerService的service对象create()创建出来的,是一个MediaPlayerService:client对象，并在之后调用了setDataSource。 想不起来往上翻翻

```cpp
status_t MediaPlayer::start()
{
    } else if ( (mPlayer != 0) && ( mCurrentState & ( MEDIA_PLAYER_PREPARED |
                    MEDIA_PLAYER_PLAYBACK_COMPLETE | MEDIA_PLAYER_PAUSED ) ) ) {
        mPlayer->setLooping(mLoop);
        mPlayer->setVolume(mLeftVolume, mRightVolume);
        mPlayer->setAuxEffectSendLevel(mSendLevel);
        mCurrentState = MEDIA_PLAYER_STARTED;
        ret = mPlayer->start();
    } 
}


```

> frameworks/av/media/libmediaplayerservice/MediaPlayerService.cpp

```cpp
status_t MediaPlayerService::Client::start()
{
    sp<MediaPlayerBase> p = getPlayer(); //这里的p是 NuPlayerDriver
    return p->start();
}
```

```
void NuPlayer::start() {
    (new AMessage(kWhatStart, this))->post();
}

case kWhatStart:
        {if (mStarted) {
                // do not resume yet if the source is still buffering
                if (!mPausedForBuffering) {
                    onResume();  //对应   mSource->resume();
                }
            } else {
                onStart(); // 处理编解码  留坑
            }
      
        }
```





---

[音频的回放流程－播放器的创建及数据准备（提取，解码）](https://blog.csdn.net/lin20044140410/article/details/79837813)


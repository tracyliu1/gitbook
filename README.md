# 工作经历

介于之前到手的offer被搞了，又开始搞工作了

如果gitbook对你有用，希望能在github给个星，谢谢各位了。

### 个人信息

- Github:https://github.com/tracyliu1 
- blog: https://tracyliu1.github.io/
-  邮箱: liudi920307@gmail.com



### 工作经历 

####  XXX教育公司 (2018.9-至今)

负责OS中Launcher、Settings的维护 Dock、Log模块的 开发、framework层需求等。

##### Settings

优化fragment使用不当，解决内存泄漏问题; launcher白名单、应用安装白名单、应用联网白名单、USB KEY 校验开发者模式密码;

##### Dock

系统常驻dock栏(代替launcher)，通过wm.addview的方式添加一个可拖动窗口。可以在全局任意 应用下划出，实现不同应用间直接跳转。支持icon不同消息类型提示(应用更新、消息数量等)。支 持⻓按图标拖动，自定义图标位置。支持动态图标显示、支持根据账号动态配置应用展示顺序。

### 北京XXX(2016.3-2018.9)

负责Amlogic平台rom编译、ota包的制作。Launcher、Market、Settings等系统App和NOVA App的 维护及开发工作。

抽象出基类EchoLauncher，统一业务逻辑，加快开发效率; 实现视频播放srt字幕文件的支持以及多音轨切换功能; 注音输入法TV版，修改自手机开源版本; 系统拦截特定按键，唤醒SystemUI中自定义的equalizer界面，处理简单JNI;

#### Reelplay

集成Market和Launcher功能。根据产品型号，在OOBE过程实现远程配置预装应用;支持远程配置 Launcher图标的启动Activity;支持桌面Shortcut功能;支持远程配置Launcher背景图和Logo。监控 模式下可以实时查看设备的存储、内存、CPU、WIFI、网速等。可以远程控制设备上应用运行、卸 载、HDMI、Block设备、重启设备。支持对所有应用清除缓存、数据。

Market;支持应用分类顺序远程配置，通过DownloadManager实现应用后台下载，EventBus实现下 载进度更新、自动安装、自动清理。远程控制设备是否支持第三方APP安装。

#### NOVA

视频直播、点播应用，播放支持软硬解切换;软解采用IJKPlayer，直播提供EPG。支持频道 Favorite、Lock(童锁)功能;支持收藏、历史等多个频道列表;支持Recall、数字键等频道快速切 换;点播服务提供排序、外加字幕、音轨切换、搜索、连播等功能;支持本地设置隐藏分类。联网 采用https，图片解析使用Glide，传输数据格式为Protocol buffer。

#### RemoteControl(跨平台遥控器)

采用在APP内运行WebServer的方式发布JS网⻚，软件通过Zxing生成二维码，用戶扫码后可以使用 遥控器、输入法、鼠标拖拽点击、机顶盒~~~~截图浏览四项功能。通过Instrumentation工具类向系 统模拟传递事件。
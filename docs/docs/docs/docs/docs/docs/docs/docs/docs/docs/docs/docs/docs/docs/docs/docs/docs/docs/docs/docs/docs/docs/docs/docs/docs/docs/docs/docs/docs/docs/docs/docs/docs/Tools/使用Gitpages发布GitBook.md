### 使用Gitpages发布GitBook



### GitBook 安装

#### 1.1检测node.js是否安装

```
npm -v
6.12.1
```
#### 1.2 安装gitboot和命令行工具(-g 代表全局安装)


```
//安装
sudo npm install -g gitbook
sudo npm install -g gitbook-cli

//查看版本
gitbook -V
CLI version: 2.3.2
GitBook version: 3.2.3


//更新gitbook命令行工具
sudo npm update gitbook-cli -g

//卸载gitbook命令
sudo npm uninstall gitbook-cli -g
```

#### 安装Gitbook的Disqus插件。
```
npm install gitbook-plugin-disqus
```

### 2 GitBook使用

#### 2.1 初始化

> gitbook init   

执行之后会生成Readme 和 summary两个文件

以下为GitBook 电子书基本结构

```
.
├── book.json
├── README.md
├── SUMMARY.md
├── chapter-1/
|   ├── README.md
|   └── something.md
└── chapter-2/
    ├── README.md
    └── something.md

```

#### 2.2 本地预览

> gitbook serve

#### 本地预览生成http://localhost:4000/

#### 2.3 生成静态网页

> gitbook build

默认生成在_book/下，并将生成所有文件拷贝到根目录或者/docs（需手动创建）

> cp -r _book/*  .

####  设置 `GitHub Pages` 选项

点击仓库首页右上方设置(`Settings`)选项卡,往下翻到 `GitHub Pages` 选项,选择源码目录,根据实际情况选择源码来源于 `master` 分支还是其他分支或者`docs/` 目录.



![](https://user-gold-cdn.xitu.io/2019/4/8/169fd9bdffa52801?imageView2/0/w/1280/h/960)


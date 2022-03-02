## minicom 串口调试





### mac os

安装

>  brew install minicom

查看mac上 usb的串口

```ruby
ls /dev/cu.usbserial-*
```

```ruby
tracyliu@tracyliudeMacBook-Pro ~ % ls /dev/cu.usbserial-*
/dev/cu.usbserial-0001
```



minicom -s 选择第三项  ***\**\*Serial port setup\*\**\***

1. 设置Serial Device为刚才 打印的串口号

2. 设置Hardware Flow Control为：No

3. 选择 Save setup as df 选项保存退出。
dumpsys memInfo  / procrank/ top





adb shell procrank







```
User  处于用户态的运行时间，不包含优先值为负进程 
Nice  优先值为负的进程所占用的CPU时间 
Sys   处于核心态的运行时间 
Idle  除IO等待时间以外的其它等待时间 
IOW   IO等待时间 
IRQ   硬中断时间 
SIRQ  软中断时间 
```



```
PID   进程id
PR    优先级
CPU%  当前瞬时CPU占用率
S     进程状态:D=不可中断的睡眠状态, R=运行, S=睡眠, T=跟踪/停止, Z=僵尸进程

THR  程序当前所用的线程数

VSS   Virtual Set Size  虚拟耗用内存（包含共享库占用的内存）
RSS   Resident Set Size 实际使用物理内存（包含共享库占用的内存）
PCY   调度策略优先级，SP_BACKGROUND/SP_FOREGROUND
UID   进程所有者的用户id
Name  进程的名称
```



具体信息可以查看源代码中： xx\system\core\toolbox\top.c



从以上打印可以看出，一般来说内存占用大小有如下规律：VSS >= RSS >= PSS >= USS
VSS - Virtual Set Size 虚拟耗用内存（包含共享库占用的内存）是单个进程全部可访问的地址空间
RSS - Resident Set Size 实际使用物理内存（包含共享库占用的内存）是单个进程实际占用的内存大小，对于单个共享库， 尽管无论多少个进程使用，实际该共享库只会被装入内存一次。
PSS - Proportional Set Size 实际使用的物理内存（比例分配共享库占用的内存）
USS - Unique Set Size 进程独自占用的物理内存（不包含共享库占用的内存）USS 是一个非常非常有用的数字， 因为它揭示了运行一个特定进程的真实的内存增量大小。如果进程被终止， USS 就是实际被返还给系统的内存大小。
USS 是针对某个进程开始有可疑内存泄露的情况，进行检测的最佳数字。怀疑某个程序有内存泄露可以查看这个值是否一直有增加







http://gityuan.com/2016/01/02/memory-analysis-command/


## 1.常用命令

### 1.1 初始化配置

Git 的设置文件为 .gitconfig，它可以在用户主目录下（全局配置），也可以在项目目录下（项目配置）。

- 显示当前的 Git 配置

> $ git config --list

- 编辑 Git 配置文件

> $ git config -e [--global] //--global 表示设置全局配置，不加该参数只对当前仓库生效

- 设置提交代码时的用户信息

> $ git config [--global] user.name "[name]"
>
> $ git config [--global] user.email "[email address]"

- 创建 SSH key

> $ ssh-keygen -t rsa -C "email@example.com"

此时会生成 id_rsa 和 id_rsa.pub 两个文件，登录网站设置点击 **Add SSH Key** 在 **key** 文本里粘贴 **id_rsa.pub** 文件的内容

- 在当前目录新建一个 Git 代码库

> $ git init

- 关联远程仓库

> $ git remote add origin git@github.com:xxx/xxx.git

- 推送到远程 master 分支

> $ git push -u origin master


修改远程url
> git remote set-url origin <new url>



### 1.2 查看代码库信息

- 显示有变更的文件

> $ git status

- 显示当前分支的版本历史

> $ git log [--pretty=oneline] //--pretty=oneline 参数可以简化输出信息

- 显示当前分支的最近几次提交

> $ git reflog

- 显示暂存区和工作区的差异

> $ git diff

- 显示暂存区和上一个commit的差异

> $ git diff --cached [file]


- 查看分支合并情况

> $ git log --graph --pretty=oneline --abbrev-commit

- 查看分支合并图

> $ git log --graph



### 1.3 拉取，提交与推送操作

- 下载远程仓库的所有变动

> $ git fetch [remote]

- 取回远程仓库的变化，并与本地分支合并

> $ git pull [remote] [branch]

- 添加文件到暂存区

> $ git add [file1] [file2] ... //添加文件名
>
> $ git add [dir]  //添加目录
>
> $ git add . //添加当前目录的所有文件(不包括删除文件)
>
> $ git add -A //(-A : --all的缩写)添加当前目录的所有文件

- 提交暂存区到仓库区

> $ git commit -m [message]

- 推送到远程仓库

> $ git push [remote] [branch]
>
> $ git push [remote] --all
>
> $ git push origin(远程仓库名称) master(分支名称) //将master分支上的内容推送到远程仓库，如果远程仓库没有master分支将创建



### 1.4 分支操作

- 查看远程仓库信息

> $ git remote -v

- 列出所有本地分支和远程分支

> $ git branch -a

- 新建一个分支，并切换到该分支

> $ git checkout -b [branch]

相当于

> $ git branch [branch-name] //新建一个分支，但依然停留在当前分支
>
> $ git checkout [branch-name] //切换到指定分支，并更新工作区；如果是远程分支将自动与远程关联本地分支

- 新建一个分支，指向指定 commit

> $ git branch [branch] [commit]

- 新建一个分支，与指定的远程分支建立追踪关系

> $ git branch --track [branch] [remote-branch]

- 设置本地分支与远程origin分支链接

> $ git branch --set-upstream [branch] origin/[branch]

- 合并指定分支到当前分支

> $ git merge [branch]

- 查看分支合并情况

> $ git log --graph --pretty=oneline --abbrev-commit

- 查看分支合并图

> $ git log --graph

- 删除分支

> $ git branch -d [branch-name]
>
> $ git branch -D [branch-name]	//强行删除

- 删除远程分支

> $ git push origin --delete [branch-name]
>
> $ git branch -dr [remote/branch]




### 1.5 TAG

- 创建标签

> $ git tag [tag-name]
>
> $ git tag [tag-name] [commit] //新建一个 tag 在指定 commit
>
> $ git tag -a [tag] -m [desc] [commit] //创建带描述的标签

- 查看所有标签

> $ git tag

- 查看标签信息

> $ git show [tag-name]

- 删除标签

> $ git tag -d [tag-name]

- 推送标签

> $ git push origin [tag-name]
>
> $ git push origin --tags //批量推送

- 删除远程标签

> $ git tag -d [tag-name] //先删除本地
>
> $ git push origin :refs/tags/[tag-name] //推送



### 1.6 恢复操作


- 恢复暂存区的指定文件到工作区

> $ git checkout [file]

- 恢复某个 commit 的指定文件到暂存区和工作区

> $ git checkout [commit] [file]

- 恢复暂存区的所有文件到工作区

> $ git checkout .

- 重置暂存区的指定文件，与上一次 commit 保持一致，但工作区不变

> $ git reset [file]

- 重置暂存区与工作区，与上一次 commit 保持一致

> $ git reset --hard

- 重置当前分支的指针为指定 commit，同时重置暂存区，但工作区不变

> $ git reset [commit]

- 重置当前分支的 HEAD 为指定 commit，同时重置暂存区和工作区，与指定 commit 一致

> $ git reset --hard [commit]

- 重置当前 HEAD 为指定 commit，但保持暂存区和工作区不变

> $ git reset --keep [commit]

- 新建一个 commit，用来撤销指定 commit
- 后者的所有变化都将被前者抵消，并且应用到当前分支

> $ git revert [commit]



---

## 2.使用场景

### 2.1 恢复本地版本与远程版本一致（本地无commit）


>checkout . && git clean -df

git checkout . //放弃本地修改，没有提交的可以回到未修改前版本

git clean是从工作目录中移除没有track的文件.
通常的参数是git clean -df:
-d表示同时移除目录,-f表示force,因为在git的配置文件中, clean.requireForce=true,如果不加-f,clean将会拒绝执行.

### 2.2 修改提交的注释

> git commit –amend


### 2.3 批量删除远程分支

批量删除本地分支
 > git branch -a | grep -v -E 'master|develop' | xargs git branch -D

批量删除远程分支
> git branch -r| grep -v -E 'master|develop' | sed 's/origin\///g' | xargs -I {} git push origin :{}


```
用到命令说明
grep -v -E 排除master 和 develop

-v 排除
-E 使用正则表达式

xargs 将前面的值作为参数传入 git branch -D 后面

-I {} 使用占位符 来构造 后面的命令

```



```
如果有些分支无法删除，是因为远程分支的缓存问题，可以使用git remote prune
```

批量删除本地tag
> git tag | xargs -I {} git tag -d {}

批量删除远程tag
> git tag | xargs -I {} git push origin :refs/tags/{}




---

### 3.代码
下载
```
git clone  // 下载代码
git branch -a //查看本地及远程分支
git branch okui1.0 origin/okui1.0 //创建本地分支关联远程分支
git checkout okui1.0 //切换本地分支
```
提交
```
git pull
git status .
git add .
git commit -m "Add Feature 修改设置关于手机"
gitk --all // 比较代码
git push origin 4.2.16_20180904:4.2.16_20180904
```


```
git rm packages/apps/Calendar/Android.mk
```


---
## 图形工具

- [SourceTree](https://www.sourcetreeapp.com/)
- [TortoiseGit](https://tortoisegit.org/)


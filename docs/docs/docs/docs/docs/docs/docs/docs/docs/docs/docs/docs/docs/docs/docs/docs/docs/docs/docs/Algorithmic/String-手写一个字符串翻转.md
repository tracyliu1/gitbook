
#### 手写一个字符串翻转？


```
string:  Hello
  length:  5
  
          0 1 2 3 4 
  before: H e l l o
  after:  o l l e H
  
  index             sum
  0: H--->o  0-->4  4
  1: e--->l  1-->3  4
  2: l--->l  2-->2  4
```
- 解法一：使用数组

将字符串转换为char数组
遍历循环给char数组赋值


```
public static String strReverseWithArray2(String string){
    if(string==null||string.length()==0)return string;
    int length = string.length();
    char [] array = string.toCharArray();
    for(int i = 0;i<length/2;i++){
        array[i] = string.charAt(length-1-i);
        array[length-1-i] = string.charAt(i);
    }
    return new String(array);
}
```

- 解法二：使用栈

将字符串转换为char数组
将char数组中的字符依次压入栈中
将栈中的字符依次弹出赋值给char数组


```
public static String strReverseWithStack(String string){
    if(string==null||string.length()==0)return string;
    Stack<Character> stringStack = new Stack<>();
    char [] array = string.toCharArray();
    for(Character c:array){
        stringStack.push(c);
    }
    int length = string.length();
    for(int i= 0;i<length;i++){
        array[i] = stringStack.pop();
    }
    return new String(array);
}
```
- 解法三：逆序遍历

逆序遍历字符串中的字符，并将它依次添加到StringBuilder中


```
public static String strReverseWithReverseLoop(String string){
        if(string==null||string.length()==0)return string;
        StringBuilder sb = new StringBuilder();
        for(int i = string.length()-1;i>=0;i--){
            sb.append(string.charAt(i));
        }
        return sb.toString();
    }
```
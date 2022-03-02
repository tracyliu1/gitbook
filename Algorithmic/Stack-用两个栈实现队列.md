
#### 用两个栈实现队列

##### 题目：用两个栈来实现一个队列，完成队列的Push和Pop操作。 队列中的元素为int类型。


```
import java.util.Stack;

public class Solution {
    Stack<Integer> stack1 = new Stack<Integer>();
    Stack<Integer> stack2 = new Stack<Integer>();
    
    public void push(int node) {
        //向stack2 push时，先判断Stack2是否为空，
        //如果不为空则将stack2的元素出栈,放进stack1中
        while(!stack2.isEmpty()){
             stack1.push(stack2.pop());
        }
        //stack2为空，则直接放入元素
        stack2.push(node);
    }
    
    public int pop() {
        //栈2元素出栈时先判断栈1是否为空
        //如果不为空则将stack1的元素出栈,放进stack2中
        while(!stack1.isEmpty()){
            stack2.push(stack1.pop());
        }
        //栈1为空，此时栈2直接出栈
        return stack2.pop();
    }
}
```

---

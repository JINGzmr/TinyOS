#include "thread.h"
#include "stdint.h"
#include "string.h"
#include "global.h"
#include "memory.h"

#include "debug.h"
#include "interrupt.h"
#include "print.h"

#define PG_SIZE 4096

struct task_struct* main_thread;    // 主线程PCB
struct list thread_ready_list;	    // 就绪队列
struct list thread_all_list;	    // 所有任务队列
static struct list_elem* thread_tag;// 用于保存队列中的线程结点

extern void switch_to(struct task_struct* cur, struct task_struct* next);

/* 获取当前线程pcb指针 */
struct task_struct* running_thread() {
   uint32_t esp; 
   asm ("mov %%esp, %0" : "=g" (esp));
  /* 取esp整数部分即pcb起始地址 */
   return (struct task_struct*)(esp & 0xfffff000);
}

/* 由kernel_thread去执行function(func_arg) , 这个函数就是线程中去开启我们要运行的函数*/
static void kernel_thread(thread_func* function, void* func_arg) {
   /* 执行function前要开中断,避免后面的时钟中断被屏蔽,而无法调度其它线程 */
   intr_enable();
   function(func_arg); 
}

/*用于根据传入的线程的pcb地址、要运行的函数地址、函数的参数地址来初始化线程栈中的运行信息，核心就是填入要运行的函数地址与参数 */
void thread_create(struct task_struct* pthread, thread_func function, void* func_arg) {
   /* 先预留中断使用栈的空间,可见thread.h中定义的结构 */
   //pthread->self_kstack -= sizeof(struct intr_stack);  //-=结果是sizeof(struct intr_stack)的4倍
   //self_kstack类型为uint32_t*，也就是一个明确指向uint32_t类型值的地址，那么加减操作，都是会是sizeof(uint32_t) = 4 的倍数
   pthread->self_kstack = (uint32_t*)((int)(pthread->self_kstack) - sizeof(struct intr_stack));

   /* 再留出线程栈空间,可见thread.h中定义 */
   //pthread->self_kstack -= sizeof(struct thread_stack);
   pthread->self_kstack = (uint32_t*)((int)(pthread->self_kstack) - sizeof(struct thread_stack));
   struct thread_stack* kthread_stack = (struct thread_stack*)pthread->self_kstack;     //我们已经留出了线程栈的空间，现在将栈顶变成一个线程栈结构体
                                                                                         //指针，方便我们提前布置数据达到我们想要的目的
   kthread_stack->eip = kernel_thread;      //我们将线程的栈顶指向这里，并ret，就能直接跳入线程启动器开始执行。
                                            //为什么这里我不能直接填传入进来的func，这也是函数地址啊，为什么还非要经过一个启动器呢？其实是可以不经过线程启动器的

    //因为用不着，所以不用初始化这个返回地址kthread_stack->unused_retaddr
   kthread_stack->function = function;      //将线程启动器（thread_start）需要运行的函数地址放入线程栈中
   kthread_stack->func_arg = func_arg;      //将线程启动器（thread_start）需要运行的函数所需要的参数地址放入线程栈中
   kthread_stack->ebp = kthread_stack->ebx = kthread_stack->esi = kthread_stack->edi = 0;
}

/* 初始化线程基本信息 , pcb中存储的是线程的管理信息，此函数用于根据传入的pcb的地址，线程的名字等来初始化线程的管理信息*/
void init_thread(struct task_struct* pthread, char* name, int prio) {
   memset(pthread, 0, sizeof(*pthread));                                //把pcb初始化为0
   strcpy(pthread->name, name);                                         //将传入的线程的名字填入线程的pcb中

   if(pthread == main_thread){
      pthread->status = TASK_RUNNING;     //由于把main函数也封装成一个线程,并且它一直是运行的,故将其直接设为TASK_RUNNING */  
   } 
   else{
      pthread->status = TASK_READY;
   }
   pthread->priority = prio;            
                                                                        /* self_kstack是线程自己在内核态下使用的栈顶地址 */
   pthread->ticks = prio;
   pthread->elapsed_ticks = 0;
   pthread->pgdir = NULL;	//线程没有自己的地址空间，进程的pcb这一项才有用，指向自己的页表虚拟地址	
   pthread->self_kstack = (uint32_t*)((uint32_t)pthread + PG_SIZE);     //本操作系统比较简单，线程不会太大，就将线程栈顶定义为pcb地址
                                                                        //+4096的地方，这样就留了一页给线程的信息（包含管理信息与运行信息）空间
   pthread->stack_magic = 0x19870916;	                                // /定义的边界数字，随便选的数字来判断线程的栈是否已经生长到覆盖pcb信息了              
}
/* 创建一优先级为prio的线程,线程名为name,线程所执行的函数是function(func_arg) */
struct task_struct* thread_start(char* name, int prio, thread_func function, void* func_arg) {
/* pcb都位于内核空间,包括用户进程的pcb也是在内核空间 */
   struct task_struct* thread = get_kernel_pages(1);    //为线程的pcb申请4K空间的起始地址

   init_thread(thread, name, prio);                     //初始化线程的pcb
   thread_create(thread, function, func_arg);           //初始化线程的线程栈

/* 确保之前不在队列中 */
   ASSERT(!elem_find(&thread_ready_list, &thread->general_tag));
   /* 加入就绪线程队列 */
   list_append(&thread_ready_list, &thread->general_tag);

   /* 确保之前不在队列中 */
   ASSERT(!elem_find(&thread_all_list, &thread->all_list_tag));
   /* 加入全部线程队列 */
   list_append(&thread_all_list, &thread->all_list_tag);

   return thread;
}

/* 将kernel中的main函数完善为主线程 */
static void make_main_thread(void) {
/* 因为main线程早已运行,咱们在loader.S中进入内核时的mov esp,0xc009f000,
就是为其预留了tcb,地址为0xc009e000,因此不需要通过get_kernel_page另分配一页*/
   main_thread = running_thread();
   init_thread(main_thread, "main", 31);

/* main函数是当前线程,当前线程不在thread_ready_list中,
 * 所以只将其加在thread_all_list中. */
   ASSERT(!elem_find(&thread_all_list, &main_thread->all_list_tag));
   list_append(&thread_all_list, &main_thread->all_list_tag);
}

/* 实现任务调度 */
void schedule() {
   ASSERT(intr_get_status() == INTR_OFF);
   struct task_struct* cur = running_thread(); 
   if (cur->status == TASK_RUNNING) { // 若此线程只是cpu时间片到了,将其加入到就绪队列尾
      ASSERT(!elem_find(&thread_ready_list, &cur->general_tag));
      list_append(&thread_ready_list, &cur->general_tag);
      cur->ticks = cur->priority;     // 重新将当前线程的ticks再重置为其priority;
      cur->status = TASK_READY;
   }
   else {
      /* 若此线程需要某事件发生后才能继续上cpu运行,
      不需要将其加入队列,因为当前线程不在就绪队列中。*/
   }

   ASSERT(!list_empty(&thread_ready_list));
   thread_tag = NULL;	  // thread_tag清空
/* 将thread_ready_list队列中的第一个就绪线程弹出,准备将其调度上cpu. */
   thread_tag = list_pop(&thread_ready_list);   
   struct task_struct* next = elem2entry(struct task_struct, general_tag, thread_tag);
   next->status = TASK_RUNNING;
   switch_to(cur, next);   
}

/* 初始化线程环境 */
void thread_init(void) {
   put_str("thread_init start\n");
   list_init(&thread_ready_list);
   list_init(&thread_all_list);
/* 将当前main函数创建为线程 */
   make_main_thread();
   put_str("thread_init done\n");
}
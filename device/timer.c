#include "timer.h"
#include "io.h"
#include "print.h"

#define IRQ0_FREQUENCY 100  // 定义我们想要的中断发生频率，100HZ
#define INPUT_FREQUENCY 1193180  // 计数器0的工作脉冲信号评率
#define COUNTER0_VALUE INPUT_FREQUENCY / IRQ0_FREQUENCY
#define CONTRER0_PORT 0x40  // 要写入初值的计数器端口号
#define COUNTER0_NO 0       // 要操作的计数器的号码
#define COUNTER_MODE 2  // 用在控制字中设定工作模式的号码，这里表示比率发生器
#define READ_WRITE_LATCH \
    3  // 用在控制字中设定读/写/锁存操作位，这里表示先写入低字节，然后写入高字节
#define PIT_CONTROL_PORT 0x43  // 控制字寄存器的端口

/* 把操作的计数器counter_no、读写锁属性rwl、计数器模式counter_mode写入模式控制寄存器并赋予初始值counter_value
 */
static void frequency_set(uint8_t counter_port,
                          uint8_t counter_no,
                          uint8_t rwl,
                          uint8_t counter_mode,
                          uint16_t counter_value) {
    /* 往控制字寄存器端口0x43中写入控制字 */
    outb(PIT_CONTROL_PORT,
         (uint8_t)(counter_no << 6 | rwl << 4 | counter_mode << 1));
    /* 先写入counter_value的低8位 */
    outb(counter_port, (uint8_t)counter_value);
    /* 再写入counter_value的高8位 */
    // outb(counter_port, (uint8_t)counter_value >> 8);
    // 作者这句代码会先将16位的counter_value强制类型转换为8位值，也就是原来16位值只留下了低8位，然后
    // 又右移8未，所以最后送入counter_port的counter_value的高8位是8个0，这会导致时钟频率过高，出现GP异常
    outb(counter_port, (uint8_t)(counter_value >> 8));
}

/* 初始化PIT8253 */
void timer_init() {
    put_str("timer_init start\n");
    /* 设置8253的定时周期,也就是发中断的周期 */
    frequency_set(CONTRER0_PORT, COUNTER0_NO, READ_WRITE_LATCH, COUNTER_MODE,
                  COUNTER0_VALUE);
    put_str("timer_init done\n");
}

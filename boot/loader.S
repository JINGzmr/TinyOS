%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR
    ; jmp loader_start					                ;loader一进来是下面一大堆GDT段描述符数据，无法执行，所以要跳过
                                                        ;虽然代码在执行时跳过了定义部分，但定义部分的数据已经被加载到内存中，并可以通过相关的指令来访问和使用
   
                                                        ;-----------------   保护模式前的准备过程   ------------------------------------------
                                                        ;-------构建全局描述符表，并直接在里面填充段描述符-----------
GDT_BASE:                                               ;GDT 的起始地址是标号 GDT_BASE所在的地址
    dd 0x00000000                                       ;下面定义了三个段描述符，每个描述符8字节
	dd 0x00000000                                       ;因为第0个描述符不可用，所以前8个字节用0填充，因此下面段描述符是从第一个开始

CODE_DESC:                                              ;---第一个：代 码 段 描 述 符 CODE_DESC
    dd 0x0000FFFF                                       ;低 4 字节中：低 2 字节是段界限的 0～15 位，高 2 字节是段基址的 0～15 位
	dd DESC_CODE_HIGH4                                  ;高 4 字节中:复杂的字段已经在boot.inc文件里以宏的形式定义好了，这里直接用即可（下面两个同理）

DATA_STACK_DESC:                                        ;---第二个：数 据 段 和 栈 段 描 述 符 DATA_STACK_DESC
    dd 0x0000FFFF
    dd DESC_DATA_HIGH4

VIDEO_DESC:                                             ;---第三个：显存段描述符 VIDEO_DESC
    dd 0x80000007	                                    ;limit=(0xbffff-0xb8000)/4k=0x7
    dd DESC_VIDEO_HIGH4                                 ; 此时dpl已改为0

    GDT_SIZE equ $ - GDT_BASE                           ;--------计算gdt的界限--------
    GDT_LIMIT equ GDT_SIZE - 1 

    times 60 dq 0					                    ;--------此处预留60个描述符的空间--------

                                                        ;--------构建代码段、数据段、显存段的选择子-----------
    SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0       ; 相当于(CODE_DESC - GDT_BASE)/8 + TI_GDT + RPL0
    SELECTOR_DATA equ (0x0002<<3) + TI_GDT + RPL0	    ; 同上
    SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0	    ; 同上 

    total_mem_bytes dd 0				                    ; 用于保存内存容量（以字节为单位），偏移 0x200 字节

    gdt_ptr dw GDT_LIMIT                                    ; 定义加载到 GDTR 的数据，前 2 字节是 GDT 界限
            dd  GDT_BASE                                    ; 后 4 字节是 GDT 起始地址

    ards_buf times 244 db 0                                 ; 预留 244 字节的 ARDS 缓冲区
    ards_nr dw 0		                                    ; 用于记录 ARDS 结构体数量

    loader_start:                                           ; 加载器的起始位置
                                                            ;-------  int 15h eax = 0000E820h ,edx = 534D4150h ('SMAP') 获取内存布局  -------

    xor ebx, ebx		                                    ; 第一次调用时，ebx 值为 0
    mov edx, 0x534d4150	                                    ; edx 赋值为 'SMAP' 标志
    mov di, ards_buf	                                    ; di 指向 ARDS 缓冲区
    .e820_mem_get_loop:	                                    ; 循环获取每个 ARDS 内存范围描述结构
    mov eax, 0x0000e820	                                    ; 设置 E820 功能号
    mov ecx, 20		                                        ; ARDS 结构大小是 20 字节
    int 0x15                                                ; 调用 BIOS 中断 0x15 获取内存信息
    add di, cx		                                        ; di 增加 20 字节，指向下一个 ARDS 结构位置
    inc word [ards_nr]	                                    ; 增加 ARDS 数量
    cmp ebx, 0		                                        ; 如果 ebx 为 0 且 cf 不为 1，则说明所有 ARDS 都已返回
    jnz .e820_mem_get_loop                                  ; 如果 ebx 不为 0，则继续循环

                                                            ; 在所有 ARDS 结构中，找出 (base_add_low + length_low) 的最大值，即内存容量
    mov cx, [ards_nr]	                                    ; 将 ARDS 数量存入 cx
    mov ebx, ards_buf                                       ; ebx 指向 ARDS 缓冲区
    xor edx, edx		                                    ; edx 清零，用于保存最大内存容量
    .find_max_mem_area:	                                    ; 遍历每一个 ARDS 结构体
    mov eax, [ebx]	                                        ; 取出 base_add_low
    add eax, [ebx+8]	                                    ; 加上 length_low，得到该段内存的结束地址
    add ebx, 20		                                        ; 指向下一个 ARDS 结构
    cmp edx, eax		                                    ; 比较 edx 和 eax，找出最大值(冒泡排序)
    jge .next_ards                                          ; 如果 edx >= eax，则跳到 next_ards
    mov edx, eax		                                    ; 如果 eax > edx，则将 edx 赋值为 eax
    .next_ards:
    loop .find_max_mem_area                                 ; 循环查找最大内存块

    mov [total_mem_bytes], edx	                            ; 将最大内存容量存入 total_mem_bytes

    ;-----------------   准备进入保护模式   ------------------------------------------
    ;1 打开 A20
    ;2 加载 GDT
    ;3 将 CR0 的 PE 位设为 1

    ;-----------------  打开 A20  ----------------
    in al, 0x92                                            ; 读取 0x92 端口的值到 al
    or al, 0000_0010B                                      ; 设置 A20 位
    out 0x92, al                                           ; 将值写回 0x92 端口

    ;-----------------  加载 GDT  ----------------
    lgdt [gdt_ptr]                                         ; 加载 GDT

    ;-----------------  CR0 第 0 位设为 1  ----------------
    mov eax, cr0                                           ; 读取 cr0 到 eax
    or eax, 0x00000001                                     ; 设置 PE 位
    mov cr0, eax                                           ; 写回 cr0

    jmp SELECTOR_CODE:p_mode_start	                        ; 远跳转到保护模式代码段 p_mode_start

    .error_hlt:		                                        ; 出错则挂起
    hlt

[bits 32]
p_mode_start:
    mov ax,SELECTOR_DATA
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov esp,LOADER_STACK_TOP
    mov ax,SELECTOR_VIDEO
    mov gs,ax

    mov byte [gs:160], 'P'

    jmp $
 
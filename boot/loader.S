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

    call setup_page                                     ;创建页目录表的函数,我们的页目录表必须放在1M开始的位置，所以必须在开启保护模式后运行

                                                        ;以下两句是将gdt描述符中视频段描述符中的段基址+0xc0000000
    mov ebx, [gdt_ptr + 2]                              ;ebx中存着GDT_BASE
    or dword [ebx + 0x18 + 4], 0xc0000000               ;视频段是第3个段描述符,每个描述符是8字节,故0x18 = 24，然后+4，是取出了视频段段描述符的高4字节。然后or操作，段基址最高位+c
                
    add dword [gdt_ptr + 2], 0xc0000000                 ;将gdt的基址加上0xc0000000使其成为内核所在的高地址

    add esp, 0xc0000000                                 ; 将栈指针同样映射到内核地址

    mov eax, PAGE_DIR_TABLE_POS                         ; 把页目录地址赋给cr3
    mov cr3, eax
                         
    mov eax, cr0                                        ; 打开cr0的pg位(第31位)
    or eax, 0x80000000  
    mov cr0, eax
                   
    lgdt [gdt_ptr]                                      ;在开启分页后,用gdt新的地址重新加载

    mov byte [gs:160], 'V'                              ;视频段段基址已经被更新,用字符v表示virtual addr

    jmp $

       
setup_page:                                             ;------------------------------------------   创建页目录及页表  -------------------------------------
                                                        ;--------以下6行是将1M开始的4KB置为0，将页目录表初始化(循环清空页目录表所占的内存)
    mov ecx, 4096                                       ;创建4096个byte 0，循环4096次
    mov esi, 0                                          ;用esi来作为偏移量寻址
.clear_page_dir:
    mov byte [PAGE_DIR_TABLE_POS + esi], 0
    inc esi
    loop .clear_page_dir                                ;每循环一次ecx会被loop减一，当ecx为0时，退出循环

                                                        ; ----------------初始化页目录表，让0号项与768号指向同一个页表，该页表管理从0开始4M的空间
.create_pde:				                            ;一个页目录表项可表示4MB内存,这样0xc03fffff以下的地址和0x003fffff以下的地址都指向相同的页表，这是为将地址映射为内核地址做准备
    mov eax, PAGE_DIR_TABLE_POS                         ; eax中存着页目录表的位置
    add eax, 0x1000 			                        ; 在页目录表位置的基础上+4K（页目录表的大小），现在eax中第一个页表的起始位置
    mov ebx, eax				                        ; 此处为ebx赋值，现在ebx存着第一个页表的起始位置
    or eax, PG_US_U | PG_RW_W | PG_P	                ; 页目录项的属性RW和P位为1,US为1,表示用户属性,所有特权级别都可以访问.
                                                        ; 现在eax中的值符合一个页目录项的要求了，高20位是一个指向第一个页表的4K整数倍地址，低12位是相关属性设置
    mov [PAGE_DIR_TABLE_POS + 0x0], eax                 ; 页目录表0号项写入第一个页表的位置(0x101000)及属性(7)
    mov [PAGE_DIR_TABLE_POS + 0xc00], eax               ; 页目录表768号项写入第一个页表的位置(0x101000)及属性(7)
					                                    
    sub eax, 0x1000                                     ;----------------- 使最后一个目录项指向页目录表自己的地址，为的是将来动态操作页表做准备
    mov [PAGE_DIR_TABLE_POS + 4092], eax	            ;属性包含PG_US_U是为了将来init进程（运行在用户空间）访问这个页目录表项
                                                        
    mov ecx, 256				                        ; -----------------初始化第一个页表，因为我们的操作系统不会超过1M，所以只用初始化256项
    mov esi, 0                                          ; esi来做寻址页表项的偏移量
    mov edx, PG_US_U | PG_RW_W | PG_P	                ; 属性为7,US=1,RW=1,P=1
.create_pte:				                            ; 创建Page Table Entry
    mov [ebx+esi*4],edx			                        ; 此时的ebx已经在上面通过eax赋值为0x101000,也就是第一个页表的地址 
    add edx,4096                                        ; edx指向下一个4kb空间，且已经设定好了属性，故edx中是一个完整指向下一个4kb物理空间的页表表项
    inc esi                                             ; 寻址页表项的偏移量+1
    loop .create_pte                                    ;循环设定第一个页表的256项

                                                        ; -------------------初始化页目录表769号-1022号项，769号项指向第二个页表的地址（此页表紧挨着上面的第一个页表），770号指向第三个，以此类推
    mov eax, PAGE_DIR_TABLE_POS                         ; eax存页目录表的起始位置
    add eax, 0x2000 		                            ; 此时eax为第二个页表的位置
    or eax, PG_US_U | PG_RW_W | PG_P                    ; 设置页目录表项相关属性，US,RW和P位都为1，现在eax中的值是一个完整的指向第二个页表的页目录表项
    mov ebx, PAGE_DIR_TABLE_POS                         ; ebx现在存着页目录表的起始位置
    mov ecx, 254			                            ; 要设置254个表项
    mov esi, 769                                        ; 要设置的页目录表项的偏移起始
.create_kernel_pde:
    mov [ebx+esi*4], eax                                ; 设置页目录表项
    inc esi                                             ; 增加要设置的页目录表项的偏移
    add eax, 0x1000                                     ; eax指向下一个页表的位置，由于之前设定了属性，所以eax是一个完整的指向下一个页表的页目录表项
    loop .create_kernel_pde                             ; 循环设定254个页目录表项
    ret
 
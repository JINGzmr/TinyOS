%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR
    jmp loader_start					                ;loader一进来是下面一大堆GDT段描述符数据，无法执行，所以要跳过
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

                                                        ;-------定义全局描述符表 GDT 的指针(用于 lgdt 加载 GDT 到 gdtr 寄存器)-----------
gdt_ptr dw GDT_LIMIT                                    ;定义加载进入GDTR的数据，前2字节是gdt界限，后4字节是gdt起始地址，
	    dd  GDT_BASE
loadermsg db '2 loader in real.'

loader_start:
                                                        ;------------------------------------------------------------
                                                        ;INT 0x10    功能号:0x13    功能描述:打印字符串“2 loader in real.”
                                                        ;------------------------------------------------------------                                                   
    mov sp,LOADER_BASE_ADDR
    mov	bp,loadermsg                                    
    mov	cx,17			                                
    mov	ax,0x1301		                                
    mov	bx,0x001f		                                
    mov	dx,0x1800		                                
    int	0x10                                            

                                                        ;-----------------   准备进入保护模式   -----------------
                                                        ;1 打开A20
                                                        ;2 加载gdt
                                                        ;3 将cr0的pe位置1

                                                        ;-----------------  打开A20  ----------------
    in al, 0x92
    or al, 0000_0010B
    out 0x92,al

                                                        ;-----------------  加载GDT  ----------------
    lgdt [gdt_ptr]


                                                        ;-----------------  cr0第0位置1  ----------------
    mov eax,cr0
    or eax,0x00000001
    mov cr0,eax

                                                        ;jmp dword SELECTOR_CODE:p_mode_start	    
    jmp  SELECTOR_CODE:p_mode_start	                    ; 刷新流水线，避免分支预测的影响,这种cpu优化策略，最怕jmp跳转，
					                                    ; 这将导致之前做的预测失效，从而起到了刷新的作用。

[bits 32]
p_mode_start:
                                                        ;---------用29行的选择子初始化成各段寄存器----------
    mov ax,SELECTOR_DATA
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov esp,LOADER_STACK_TOP
    mov ax,SELECTOR_VIDEO
    mov gs,ax

    mov byte [gs:160], 'P'

    jmp $
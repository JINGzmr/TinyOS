; 第一版：通过BIOS输出hello MBR
; ;主引导程序 
; SECTION MBR vstart=0x7c00       ;本程序在编译时，告诉编译器，把我的起始地址编译为 0x7c00
;     mov ax,cs                   ;此时cs寄存器为0，可以用来将ax寄存器置0
;     mov ds,ax
;     mov es,ax
;     mov ss,ax
;     mov fs,ax
;     mov sp,0x7c00               ;将栈指针sp寄存器初始化为0x7c00,让栈有足够的空间向低地址方向扩展。

;     ;清屏
;     ;利用0x06号功能，上卷全部行，则可清屏
;     mov ax, 0x600               ;ah中输入功能号
;     mov bx, 0x700               ;设置上卷行属性，0x70表示用黑底白字的属性填充空白行
;     mov cx, 0                   ;左上角: (0, 0)
;     mov dx, 0x184f	            ;右下角: (80,25),
; 			                    ;VGA文本模式中,一行只能容纳80个字符,共25行,下标从0开始,所以0x18=24,0x4f=79
;     int 0x10                    

;     ;下面这三行代码是获取光标位置
;     mov ah, 3		            ;输入: 3号子功能是获取光标位置,需要存入ah寄存器
;     mov bh, 0		            ;bh寄存器存储的是待获取光标的页号

;     int 0x10		            ;执行BIOS 0x10号中断,输出: ch=光标开始行,cl=光标结束行,dh=光标所在行号,dl=光标所在列号

;     ;打印字符串
;     ;还是用10h中断,不过这次是调用13号子功能打印字符串
;     mov ax, message 
;     mov bp, ax		           
;     mov cx, 9		            ;要打印的字符串的长度
;     mov ax, 0x1301	            ;ah=13h,al=01h,表示要打印字符串
;     mov bx, 0x2		            ;bh存储要显示的页号,此处是第0页,bl中是字符属性, 属性黑底绿字(bl = 02h,07是黑底白字)
;     int 0x10		            ;执行BIOS 0x10 号中断,打印字符串

;     jmp $		                ;使程序悬停在此,即死循环

;     message db "hello MBR"      ;定义打印的字符串为hello MBR
;     times 510-($-$$) db 0       ;$为本代码行的地址,$$为本section的起始地址,$-$$为本行到本 section的偏移量.
;                                 ;因为MBR 的最后两个字节是固定的内容，分别是 0x55 和 0xaa，要预留出这 2 个字节
;                                 ;故本扇区内前 512-2=510 字节要填满, 所以db 0是用 0 将本扇区剩余空间填充
;     db 0x55,0xaa                ;最后两个字节为固定的魔数,BIOS会检查这两个字节来识别这是一个有效的MBR


; 第二版:通过显卡输出hello MBR
; ;主引导程序 
; SECTION MBR vstart=0x7c00      
;     mov ax,cs                  
;     mov ds,ax
;     mov es,ax
;     mov ss,ax
;     mov fs,ax
;     mov sp,0x7c00       

;     ;往gs寄存器中存入段基址
;     mov ax,0xb800   ;由于显存文本模式中，其内存地址是 0xb8000，实模式下内存分段访问策略是“段基址*16+段内偏移地址”
;     mov gs,ax       ;所以由0xb8000得到的段基址是其除以16,也就是右移4位，得：0xb800

;     mov ax, 0x600              
;     mov bx, 0x700              
;     mov cx, 0                  
;     mov dx, 0x184f	           
			                   
;     int 0x10   
;     ; 输出背景色绿色，前景色红色，并且跳动的字符串"1 MBR"
;     mov byte [gs:0x00],'h'              ; 将字符 'h' 的 ASCII 码放入显存。gs为段跨越前缀，指定gs为段基址
;     mov byte [gs:0x01],0xA4             ; 设置颜色属性。A表示绿色背景闪烁，4表示前景色为红色

;     mov byte [gs:0x02],'e'
;     mov byte [gs:0x03],0xA4

;     mov byte [gs:0x04],'l'
;     mov byte [gs:0x05],0xA4   

;     mov byte [gs:0x06],'l'
;     mov byte [gs:0x07],0xA4

;     mov byte [gs:0x08],'o'
;     mov byte [gs:0x09],0xA4

;     mov byte [gs:0x0a],' '
;     mov byte [gs:0x0b],0xA4

;     mov byte [gs:0x0c],'M'
;     mov byte [gs:0x0d],0xA4

;     mov byte [gs:0x0e],'B'
;     mov byte [gs:0x0f],0xA4

;     mov byte [gs:0x10],'R'
;     mov byte [gs:0x11],0xA4

;     jmp $

;     times 510-($-$$) db 0
;     db 0x55,0xaa


; 第三版
;主引导程序 
%include "boot.inc"     ;nasm 编译器中的预处理指令,让编译器在编译之前把 boot.inc 文件包含进来
SECTION MBR vstart=0x7c00         
    mov ax,cs      
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov fs,ax
    mov sp,0x7c00
    mov ax,0xb800
    mov gs,ax

    ; 清屏
    mov ax, 0600h
    mov bx, 0700h
    mov cx, 0                      
    mov dx, 184fh		           		                   
				                   
    int 10h                        

    ; 输出字符串:MBR
    mov byte [gs:0x00],'1'
    mov byte [gs:0x01],0xA4

    mov byte [gs:0x02],' '
    mov byte [gs:0x03],0xA4

    mov byte [gs:0x04],'M'
    mov byte [gs:0x05],0xA4	        ;A表示绿色背景闪烁，4表示前景色为红色

    mov byte [gs:0x06],'B'
    mov byte [gs:0x07],0xA4

    mov byte [gs:0x08],'R'
    mov byte [gs:0x09],0xA4
	 
    ;下面三行为rd_disk_m_16 函数传递参数（用寄存器传递，这里用到eax、bx、cx 寄存器）
    mov eax,LOADER_START_SECTOR	    ; 待读入的起始扇区lba地址
    mov bx,LOADER_BASE_ADDR         ; 数据从硬盘读进来后，将其写入的内存地址
    mov cx,4			            ; 待读入的扇区数

    call rd_disk_m_16		        ; 调用函数 rd_disk_m_16 读取硬盘的一个扇区
  
    ; jmp LOADER_BASE_ADDR + 0x300           ; 跳转到 loader 的起始地址，执行 loader 程序
    jmp LOADER_BASE_ADDR   

; 功能: 读取硬盘 n 个扇区的函数
rd_disk_m_16:
    ; eax = LBA 扇区号
    ; ebx = 将数据写入的内存地址
    ; ecx = 读入的扇区数

    mov esi, eax  ; 备份 EAX 寄存器的值（LBA 扇区号）
    mov di, cx    ; 备份 ECX 寄存器的值（待读入的扇区数）

    ; 通过下面五步进行磁盘读取
    ; 第一步：选择特定通道的寄存器，设置要读取的扇区数
    mov dx, 0x1f2  ; 选择端口 0x1f2
    mov al, cl     ; 设置要读取的扇区数
    out dx, al     ; 写入到端口

    mov eax, esi   ; 恢复 EAX 寄存器的值

    ; 第二步：将 LBA 地址的各部分写入端口 0x1f3 ~ 0x1f6
    mov dx, 0x1f3  ; 设置 LBA 地址的低 8 位
    out dx, al     ; 写入到端口

    mov cl, 8      ; 将 EAX 寄存器右移 8 位，设置 LBA 地址的 15~8 位
    shr eax, cl
    mov dx, 0x1f4
    out dx, al

    shr eax, cl    ; 将 EAX 寄存器右移 8 位，设置 LBA 地址的 23~16 位
    mov dx, 0x1f5
    out dx, al

    shr eax, cl    ; 将 EAX 寄存器右移 8 位，设置 LBA 地址的 27~24 位
    and al, 0x0f   ; 只保留低 4 位
    or al, 0xe0    ; 设置高 4 位为 1110，表示 LBA 模式
    mov dx, 0x1f6
    out dx, al

    ; 第三步：向 0x1f7 端口写入读命令，0x20
    mov dx, 0x1f7
    mov al, 0x20  ; 设置读命令
    out dx, al   ; 写入到端口

    ; 第四步：检测硬盘状态，等待硬盘准备好数据传输
.not_ready:
    nop         ; 相当于 sleep，等待
    in al, dx   ; 从端口读取硬盘状态
    and al, 0x88  ; 检查第 4 位和第 7 位
    cmp al, 0x08  ; 如果第 4 位为 1，表示硬盘控制器已准备好数据传输
    jnz .not_ready  ; 如果未准备好，继续等待

    ; 第五步：从 0x1f0 端口读数据
    mov ax, di  ; 获取待读入的扇区数
    mov dx, 256  ; 每个扇区 512 字节，一次读取 2 字节，共需读取 256 次
    mul dx      ; 计算总读取次数
    mov cx, ax  ; 将总读取次数存入 CX 寄存器
    mov dx, 0x1f0  ; 设置数据端口

.go_on_read:
    in ax, dx    ; 从端口读取数据
    mov [bx], ax  ; 将数据写入内存
    add bx, 2    ; 增加内存地址指针
    loop .go_on_read  ; 循环读取，直到 CX 为 0

    ret  ; 返回，回到调用 rd_disk_m_16 的地方

    times 510-($-$$) db 0  ; 填充到 510 字节
    db 0x55, 0xaa  ; MBR 签名
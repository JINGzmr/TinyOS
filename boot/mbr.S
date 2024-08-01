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
;主引导程序 
SECTION MBR vstart=0x7c00      
    mov ax,cs                  
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov fs,ax
    mov sp,0x7c00       

    ;往gs寄存器中存入段基址
    mov ax,0xb800   ;由于显存文本模式中，其内存地址是 0xb8000，实模式下内存分段访问策略是“段基址*16+段内偏移地址”
    mov gs,ax       ;所以由0xb8000得到的段基址是其除以16,也就是右移4位，得：0xb800

    mov ax, 0x600              
    mov bx, 0x700              
    mov cx, 0                  
    mov dx, 0x184f	           
			                   
    int 0x10   
    ; 输出背景色绿色，前景色红色，并且跳动的字符串"1 MBR"
    mov byte [gs:0x00],'h'              ; gs为段跨越前缀，指定gs为段基址
    mov byte [gs:0x01],0xA4             ; A表示绿色背景闪烁，4表示前景色为红色

    mov byte [gs:0x02],'e'
    mov byte [gs:0x03],0xA4

    mov byte [gs:0x04],'l'
    mov byte [gs:0x05],0xA4   

    mov byte [gs:0x06],'l'
    mov byte [gs:0x07],0xA4

    mov byte [gs:0x08],'o'
    mov byte [gs:0x09],0xA4

    mov byte [gs:0x0a],' '
    mov byte [gs:0x0b],0xA4

    mov byte [gs:0x0c],'M'
    mov byte [gs:0x0d],0xA4

    mov byte [gs:0x0e],'B'
    mov byte [gs:0x0f],0xA4

    mov byte [gs:0x10],'R'
    mov byte [gs:0x11],0xA4

    jmp $

    times 510-($-$$) db 0
    db 0x55,0xaa
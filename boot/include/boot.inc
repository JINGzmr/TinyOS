; loader和kernel
LOADER_BASE_ADDR equ 0x900 ;相当于c语言的#define LOADER_BASE_ADDR 0x900
                           ;定义了 loader 在内存中的位置,MBR 要把 loader 从硬盘读入后放到此处
                           ;即将来 loader 会在内存地址 0x900 处
LOADER_START_SECTOR equ 0x2 ;loader 程序在硬盘上的起始扇区


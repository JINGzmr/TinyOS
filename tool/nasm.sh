#!/bin/bash
# usage: sh ~/Desktop/TinyOS/tool/nasm.sh

cd /home/ZMR/Desktop/TinyOS
mkdir -p build  # 创建 build 目录，如果已存在则不报错

# 编译并写入 MBR
nasm -o build/mbr -I ./boot/include/ boot/mbr.S 
if [ $? -ne 0 ]; then
    echo "Error: Failed to compile MBR"
    exit 1
fi

dd if=build/mbr of=/home/ZMR/Desktop/bochs/hd60M.img bs=512 count=1 conv=notrunc
if [ $? -ne 0 ]; then
    echo "Error: Failed to write MBR to hd60M.img"
    exit 1
fi

# 编译并写入 loader
nasm -o build/loader -I ./boot/include/ ./boot/loader.S 
if [ $? -ne 0 ]; then
    echo "Error: Failed to compile loader"
    exit 1
fi

dd if=build/loader of=/home/ZMR/Desktop/bochs/hd60M.img bs=512 count=4 conv=notrunc seek=2
if [ $? -ne 0 ]; then
    echo "Error: Failed to write loader to hd60M.img"
    exit 1
fi

# 编译 main
gcc -m32 -I lib/kernel/ -I lib/ -I kernel/ -c -fno-builtin -fno-stack-protector -o build/main.o -m32 kernel/main.c
if [ $? -ne 0 ]; then
    echo "Error: Failed to compile main"
    exit 1
fi

# 编译 print
nasm -f elf -o build/print.o lib/kernel/print.S
if [ $? -ne 0 ]; then
    echo "Error: Failed to compile print"
    exit 1
fi

# 编译 kernel
nasm -f elf -o build/kernel.o kernel/kernel.S
if [ $? -ne 0 ]; then
    echo "Error: Failed to compile kernel"
    exit 1
fi

# 编译 interrupt
gcc -m32 -I lib/kernel/ -I lib/ -I kernel/ -c -fno-builtin -fno-stack-protector -o build/interrput.o -m32 kernel/interrupt.c
if [ $? -ne 0 ]; then
    echo "Error: Failed to compile interrupt"
    exit 1
fi

# 编译 init
gcc -m32 -I lib/kernel/ -I lib/ -I kernel/ -I device/ -c -fno-builtin -fno-stack-protector -o build/init.o kernel/init.c
if [ $? -ne 0 ]; then
    echo "Error: Failed to compile init"
    exit 1
fi

# 编译 timer
gcc -m32 -I lib/kernel/ -I lib/ -I kernel/ -I device/ -c -fno-builtin -fno-stack-protector -o build/timer.o device/timer.c
if [ $? -ne 0 ]; then
    echo "Error: Failed to compile timer"
    exit 1
fi

# 链接成内核
ld -m elf_i386 -Ttext 0x00001500 -e main -o build/kernel.bin build/main.o build/kernel.o build/init.o build/interrput.o build/print.o build/timer.o
if [ $? -ne 0 ]; then
    echo "Error: Failed to link kernel"
    exit 1
fi

# 写入内核
dd if=build/kernel.bin of=/home/ZMR/Desktop/bochs/hd60M.img bs=512 count=200 seek=9 conv=notrunc
if [ $? -ne 0 ]; then
    echo "Error: Failed to write kernel to hd60M.img"
    exit 1
fi

# 清除 build 文件夹内所有的编译好的二进制文件
rm -rf build/*
echo "Build and installation completed successfully."
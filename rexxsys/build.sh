#!/bin/bash

export IFILE=rexxsys.asm

#sed -i \~ 's/^ *.model flat$//' rexxsys.asm && uasm -0 -Sa -Sg -Sn -bin -Fo=rexxsys.bin -Fl=rexxsys.lst rexxsys.asm || exit
uasm -0 -Sa -Sg -Sn -bin -Fo=rexxsys.bin -Fl=rexxsys.lst rexxsys.asm || exit

if [ ! -f rexxsys.sys ]; then
    cp archives/rexxsys.sys .
fi

if cmp rexxsys.bin rexxsys.sys; then
    rm -f rexxsys.bin rexxsys.sys
    printf "REXXSYS.ASM matches REXXSYS.SYS\n"
else
    diff <(xxd rexxsys.sys) <(xxd rexxsys.bin) | less
fi

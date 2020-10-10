#!/bin/bash

export IFILE=rexxsys.asm; sed -i \~ 's/^ *.model flat$//' rexxsys.asm && uasm -0 -bin -Fo=rexxsys.bin rexxsys.asm

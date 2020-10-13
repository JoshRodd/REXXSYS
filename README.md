# REXXSYS
REXXSYS Version 1.1191.A232

Disassembly: Josh Rodd

Original binary: Unknown

This is a source version of REXXSYS which is a TSR
which allows executing .BAT files from COMMAND.COM
that contain normal REXX programs. The .BAT file
must started with a comment like: 

```
/* Comment */
```

To use, add a DEVICE= statement to CONFIG.SYS to
load REXXSYS, such as:

```
DEVICE=C:\REXX\REXXSYS.SYS
```

A REXX88PC compatible TSR such as REXXIBMR.EXE must
be loaded.

Version 1.1191.A232 is compatible with genuine
versions of PC DOS and MS-DOS, including the DOS that
comes with Windows and OS/2, but has compatibility
issues with alternatives like FreeDOS.

It can be built using MASM or a compatible equivalent
such as uasm; the Makefile supplied has only been
tested on macOS 10.15.5 with uasm v2.47.

To build, run: `./build.sh`
Or run "make dist" from the src/ directory. The
output REXXSYS.SYS file is suitable for deplying to
a PC.

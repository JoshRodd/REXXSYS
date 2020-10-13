; REXXSYS.ASM
;
; This program builds REXXSYS.SYS, a 1,191-byte device driver which enables
; REXXIBMR.EXE from the REXX88PC package to allow .BAT files that contain
; REXX programs to be executed by COMMAND.COM.
;
; This is compatible with DOS 2.0 and later versions. It works on all genuine
; versions of DOS up to and including the variants included with Windows and
; OS/2, but does not function correctly in environments like DOSEMU2.
;
; Essentially, this driver hooks DOS file read calls and attempts to trap 
; when COMMAND.COM reads in a .BAT file that starts with a / character. If it
; finds that COMMAND.COM is trying to load an executable whose filename ends
; in .BAT and that starts with a /, it has REXX88PC execute the file instead.
;
; This program is not implemented in a particularly reentrant way, but it does
; have enough checks that it will function correctly when a network redirector
; is installed.
;
; Output file size: 1,191 bytes
; Output file SHA-256 hash:
; 4935AC2ED73158BDD1F26ABB2C99F35F322B360D53391C0EAEEC451B5C99A232
;
; The purpose of this code is to help develop a more flexible version of
; REXXSYS that functions properly on alternative versions of DOS.

_TEXT           segment para public 'CODE'
                assume cs:_TEXT,es:nothing, ss:nothing, ds:nothing

drvr_next_ptr   dd -1                   ; Next driver or -1 if last
drvr_flags      dw 8000h                ; bit 15 1=character device
drvr_strategy   dw offset strategy_routine ; This is the DOS device driver strategy routine. This just stores
                                        ; the pointer to the device request block in preparation for the
                                        ; interrupt routine to be called.
drvr_interrupt  dw offset interrupt_routine ; This is the interrupt routine for DOS.
                                        ;
                                        ; Realistically, the only thing this driver does is call its own initialisation
                                        ; routine. For anything else, it returns an error.
drvr_filename   db '_       '           ; REXXSYS driver filename (just "_")

; This is the DOS device driver strategy routine. This just stores
; the pointer to the device request block in preparation for the
; interrupt routine to be called.

devreq_vector   label   dword
devreq_offset   dw 0
devreq_selector dw 0

strategy_routine proc   far
                mov     devreq_offset, bx
                mov     devreq_selector, es
                ret
strategy_routine endp

; This is our flag we use to see if we are inside our hooks for Int 21h, etc.
REENTRANT_42h   equ     42h
REENTRANT_43h   equ     43h

; Internal REXXSYS work areas
file_start_buffer db    2 dup(0)
dos_reentrancy_flag db  REENTRANT_42h   ; When this is set to 43h ('C'), dispatcher does a caller_ds check
                                        ; When this is set to 42h ('B'), dispatcher skips the caller_ds check
command_com_psp_selector dw 0           ; The PSP of what we think COMMAND.COM is
                dw      0               ; Unused?
int7ch_caller_offset dw 0               ; This stores the offset of a caller to Int 7Ch (for searching the call stack)
first_word      dw 0                    ; We keep a copy of the first two bytes of an active executable here
caller_ds       dw 0                    ; This stores the DS of the caller of the currently
                                        ; executing REXX program (normally that is our driver's CS)
rexx88pc_vector label   dword           ; This points to the start of REXX88PC's data work area.
rexx88pc_off    dw      0
rexx88pc_sel    dw      0
current_psp_selector dw 0               ; We store the current PSP selector here. If this is not
                                        ; the same as command_com_psp_selector, it is safe to
                                        ; assume COMMAND.COM is trying to load a new program.
intxxh_caller   label   dword           ; Far pointer to caller of Int 7Ch or Int 21h
intxxh_caller_offset dw 0 
intxxh_caller_selector dw 0
dos_version_major db    0               ; This holds the DOS major version number for
                                        ; checking if we are on DOS 2.x
ctrl_break_flag db 0      ; Set to 1 or 0 when trapping AH=0 AL=8 calls
rexx88pc_exec_struc db  REENTRANT_42h   ; Structure passed to REXX88PC EXEC call
                db      0,47h,0,4Bh,0,1,0
                db      'REXX',0
                db      'DOS',0
                db      'BAT',0
string_zero     db      '0',0

REXX88_ESCAPE   equ     63h             ; Special AX=63h, CY=0 return code from Int 7Ch

; This is the main dispatch procedure. It can handle calls to either Int 21h or Int 7Ch.
dispatcher      proc    near
                cmp     dos_reentrancy_flag, 43h ; 'C' ; If our reentrancy flag is set (42h), skip caller_ds check
                jnz     short skip_caller_ds_check ; If our reentrancy flag is not set (43h), do the caller_ds check
                push    ax              ; Preserve AX (AX=file handle in question)
                mov     ax, ds          ; Compare DS
                cmp     ax, caller_ds   ; Is DS currently caller_ds?
                jz      short clc_ax_63h_pop ; If DS=CS:caller_ds, set AX to 63h, clear carry flag, and return
                pop     ax              ; Restore AX
                pushf                   ; Chain to original Int 21h handler
                call    dword ptr int21h_offset
                ret
; ---------------------------------------------------------------------------

clc_ax_63h_pop:                         ; CODE XREF: int7ch_dispatcher-A4↑j
                pop     ax              ; Restore AX from before jump
; END OF FUNCTION CHUNK FOR int7ch_dispatcher

clc_ax_63h:                             ; CODE XREF: _TEXT:00F2↓j
                mov     ax, REXX88_ESCAPE ; Return our special 63h file handle
                clc                     ; Clear carry flag

shortcut_ret_near:                      ; CODE XREF: int7ch_dispatcher-8E↓j
                ret
; ---------------------------------------------------------------------------
; START OF FUNCTION CHUNK FOR int7ch_dispatcher

skip_caller_ds_check:                   ; CODE XREF: int7ch_dispatcher-AE↑j
                pushf                   ; Place call to original Int 21h
                call    dword ptr int21h_offset
                jb      short shortcut_ret_near ; If carry flag set, return immediately
                call    pusha_proc      ; Preserve all registers
                push    cs              ; Read the first 2 bytes of the file from file handle in AX
                pop     ds              ; DS:DX=CS:is_slash_or_colon_char_buffer
                mov     dx, offset file_start_buffer
                mov     cx, 2           ; CX=2 bytes
; END OF FUNCTION CHUNK FOR int7ch_dispatcher
                mov     bx, ax          ; BX=file handle from AX
                mov     ah, 3Fh ; '?'   ; DOS Int 21h Func AH=3Fh: read file or device
                                        ; BX = file handle (copied from AX)
                                        ; CX = bytes to read (2 bytes)
                                        ; DS:DX = buffset (DS:DX=CS:21h)
                pushf                   ; Call original DOS Int 21h
                call    dword ptr int21h_offset
                mov     ah, 3Eh ; '>'   ; DOS Int 21h Func AH=3Eh: close file
                                        ; BX = file handle (originally copied from AX)
                pushf                   ; Call original DOS Int 21h
                call    dword ptr int21h_offset
                cmp     file_start_buffer, '/' ; Does the file start with a /
                jz      short file_starts_with_slash_char ; If so, handle as REXX program file
                cmp     file_start_buffer+1, '/'
                jnz     short fall_through_open_file ; If second byte is not a /, just chain to normal open file
                cmp     file_start_buffer, ':'
                jnz     short fall_through_open_file ; If first byte is not a :, just chain to normal open file
                cmp     ctrl_break_flag, 0 ; Is Ctrl+Break flag set?
                jz      short fall_through_open_file ; If so, do not try to execute program

file_starts_with_slash_char:            ; CODE XREF: _TEXT:009C↑j
                call    popa_proc       ; Restore all registers
                call    pusha_proc      ; Preserve all registers again
                mov     rexx88pc_sel, cs ; Set rexx88pc_vector to CS:rexx88pc_vector_ours
                mov     rexx88pc_off, offset rexx88pc_vector_ours ; This points to the "in REXX88PC" counter.
                mov     cs:current_psp_selector, es ; Save the PSP selector.
                mov     cs:caller_ds, ds ; Save caller's DS (this is normally our CS)
                call    exec_rexx88pc   ; Execute the batch file via the REXX88PC TSR.
                                        ; The PSP selector must be in cs:current_psp_selector.
                                        ; The PSP should contain the command line argument at PSP:81h
                                        ; with the command line length in PSP:80h.
                                        ;
                                        ; You must do an installation check that REXX88PC is
                                        ; installed before calling this function.
                                        ;
                                        ; Call with DX set to the unknown parameter.
                                        ;
                                        ; REXX88PC Func AX=00h (execute) is called with:
                                        ; AX=00h (func 00h, execute)
                                        ; ES:BX=name of script to execute followed by arguments (PSP:81h)
                                        ; DX:DI=REXX88PC reentrancy flag (CS:rexx88pc_reentrancy_flag)
                                        ; SI=unknown parameter
                                        ;
                                        ; All registers are destroyed.
                cmp     cs:dos_version_major, 0 ; Have we found out the DOS version number yet?
                jnz     short already_have_dos_version ; If so don't ask again
                mov     ah, 30h ; '0'   ; DOS Int 21h Func AH=30h (get DOS version)
                                        ;
                                        ; Returns major version in AL and minor version in AH
                pushf                   ; Call original DOS Int 21h
                call    dword ptr cs:int21h_offset
                mov     cs:dos_version_major, al ; Store the DOS version

already_have_dos_version:               ; CODE XREF: _TEXT:00DB↑j
                call    popa_proc
                mov     cs:dos_reentrancy_flag, 43h ; 'C' ; Set our DOS reentrancy flag to 43h to to bypass file I/O calls
                jmp     clc_ax_63h      ; Set AX to 63h, clear carry flag, and return
; ---------------------------------------------------------------------------

fall_through_open_file:                 ; CODE XREF: _TEXT:00A4↑j
                                        ; _TEXT:00AC↑j ...
                call    popa_proc       ; Restore all registers
                mov     ax, 3D00h       ; DOS Int 21h Func AH=3Dh (open file)
                                        ; AL=0 (read access only)
                pushf                   ; Call original DOS Int 21h
                call    dword ptr cs:int21h_offset
                ret                    ; Return to caller with whatever the result of the file open was
; ---------------------------------------------------------------------------
; START OF FUNCTION CHUNK FOR int7ch_dispatcher

handle_func_3dh_open:                   ; CODE XREF: int7ch_dispatcher+3↓j
                jmp     dispatcher      ; If our reentrancy flag is set (42h), skip caller_ds check
; END OF FUNCTION CHUNK FOR int7ch_dispatcher

; =============== S U B R O U T I N E =======================================

; Func 7Ch call dispatcher.

int7ch_dispatcher label near

                cmp     ah, 3Dh ; '='
                jz      short handle_func_3dh_open ; DOS Int 21h Func AH=3Dh (open)?
                cmp     ah, 3Fh ; '?'
                jz      short handle_func_3fh_read ; DOS Int 21h Func AH=3Dh (read)?
                cmp     ah, 42h ; 'B'
                jz      short handle_func_42h_seek ; DOS Int 21h Func AH=42h (seek)?
                cmp     ah, 3Eh ; '>'
                jz      short handle_func_3eh_close ; DOS Int 21h Func AH=3Eh (close)?
                ; Modern assemblers do this as CMP AX,+8 instead
                db 3Dh                  ; CMP AX,8
                dw 8                    ; REXX88PC Int 7Ch AX=8 BX=status (notify Ctrl+Break)
                jnz     short near ptr handle_func_00h_al_05h ; If not, pass through to default handler
                cmp     bx, 1           ; Is BX=1?
                jnz     short handle_func_00h_al_08h_bx_2 ; If not, check for BX=2
                mov     cs:ctrl_break_flag, 1 ; If BX=1 then set flag to 1
                jmp     short return_success ; Set CY=0 to show no error
                nop

handle_func_00h_al_08h_bx_2:            ; CODE XREF: int7ch_dispatcher+1C↑j
                cmp     bx, 2           ; Is BX=2?
                jnz     short near ptr handle_func_00h_al_05h ; If not, pass through to default handler
                mov     cs:ctrl_break_flag, 0 ; If BX=2 then set flag to 0
                jmp     short return_success ; Clear carry flag and return
                nop
handle_func_00h_al_05h:                 ; CODE XREF: int7ch_dispatcher+17↑j
                                        ; int7ch_dispatcher+2A↑j
                db 3Dh                  ; CMP AX, 5
                dw 5                    ; REXX88PC Int 7Ch AX=5 (return DS:SI of 0000:0000)
                jnz     short near ptr handle_func_00h_al_07h ; If not go to default handler
                mov     si, 0           ; Return DS:SI set to 0000:0000
                mov     ds, si
                jmp     short return_error ; Set carry flag and AX=-1 to return an error
                nop
handle_func_00h_al_07h:                 ; CODE XREF: int7ch_dispatcher+38↑j
                db 3Dh                  ; CMP AX,7
                dw 7                    ; REXX88PC Int 7Ch AX=7 (return DS:SI of '0' string)
                jnz     short return_error ; If not return an error
                mov     si, offset string_zero ; Return DS:SI set to null-terminated "0" string
                mov     ax, cs
                mov     ds, ax
                jmp     short return_error ; ; Set CY=1 and AX=-1 to return an error
                nop

return_success: clc
                ret

return_error:   mov     ax, -1      ; ; Set CY=1 and AX=-1 to return an error
                stc
                ret
; ---------------------------------------------------------------------------

handle_func_42h_seek:                   ; CODE XREF: int7ch_dispatcher+D↑j
                cmp     cs:dos_reentrancy_flag, 43h ; 'C' ; If DOS Int 21h reentrancy flag is 43h, immediately return
                jz      short return_success_0
                pushf                   ; If DOS Int 21h reentrancy flag is 42h, chain to original DOS Int 21h
                call    dword ptr cs:int21h_offset
                ret
; ---------------------------------------------------------------------------

return_success_0:                       ; CODE XREF: int7ch_dispatcher+5E↑j
                mov     ax, 0
                clc
                ret
; ---------------------------------------------------------------------------

handle_func_3eh_close:                  ; CODE XREF: int7ch_dispatcher+12↑j
                cmp     cs:dos_reentrancy_flag, 43h ; 'C' ; If DOS Int 21h reentrancy flag is 43h, immediately return and set AX=0
                jz      short return_success_0_0
                pushf                   ; If DOS Int 21h reentrancy flag is 42h, chain to original DOS Int 21h
                call    dword ptr cs:int21h_offset
                ret
; ---------------------------------------------------------------------------

return_success_0_0:                     ; CODE XREF: int7ch_dispatcher+72↑j
                mov     ax, 0
                clc
                ret
; ---------------------------------------------------------------------------

handle_func_3fh_read:                   ; CODE XREF: int7ch_dispatcher+8↑j
                cmp     cs:dos_reentrancy_flag, 43h ; 'C' ; If DOS Int 21h reentrancy flag is 43h, execute our own handler
                jz      short handle_func_3fh_read_handler ; Preserve ES:BX
                pushf                   ; If DOS Int 21h reentrancy flag is 42h, chain to original DOS Int 21h
                call    dword ptr cs:int21h_offset
                ret
; ---------------------------------------------------------------------------

handle_func_3fh_read_handler:           ; CODE XREF: int7ch_dispatcher+86↑j
                push    es              ; Preserve ES:BX
                push    bx
                les     bx, cs:rexx88pc_vector ; Load the REXX88PC vector
                mov     al, es:[bx]     ; Retrieve the current REXX88PC vector's count
                inc     word ptr cs:rexx88pc_vector ; Increment the REXX88PC vector's count
                cmp     al, 0           ; Is the vector count zero?
                jnz     short file_mode_not_40h ; If not, set the DOS Int 21h reentrancy flag to 42h
                call    rexx88pc_installation_check ; Check if TSR is installed
                les     bx, cs:rexx88pc_vector ; This points to the "in REXX88PC" counter.
                mov     al, es:[bx]
                cmp     cs:dos_version_major, 2 ; Is this DOS version 2.x?
                jnz     short not_dos_v2_x ; Is AL (REXX88PC vector counter) set to 40h?
                inc     word ptr cs:rexx88pc_vector ; This points to the "in REXX88PC" counter.
                jmp     short file_mode_not_40h
; ---------------------------------------------------------------------------
                nop

not_dos_v2_x:                           ; CODE XREF: int7ch_dispatcher+B3↑j
                cmp     al, 40h ; '@'   ; Is AL (REXX88PC vector counter) set to 40h?
                jnz     short file_mode_not_40h
                inc     word ptr cs:rexx88pc_vector ; If so, increment the vector count

file_mode_not_40h:                      ; CODE XREF: int7ch_dispatcher+A0↑j
                                        ; int7ch_dispatcher+BA↑j ...
                cmp     al, 1Ah
                jnz     short vector_count_not_1ah ; Is the vector count our reserved 01Ah signature?
                mov     cs:dos_reentrancy_flag, 42h ; 'B' ; If so, set the DOS Int 21h reentrancy flag to 42h

vector_count_not_1ah:                   ; CODE XREF: int7ch_dispatcher+C8↑j
                mov     bx, dx          ; Get address of read buffer
                mov     [bx], al        ; Write AL (the REXX88PC vector counter) to the read buffer
                mov     ax, 1           ; Number of bytes read = 1
                clc                     ; Set CY=0 (success)
                pop     bx              ; Restore ES:BX
                pop     es
                ret                     ; Return to caller

dispatcher endp


; =============== S U B R O U T I N E =======================================

; Execute the batch file via the REXX88PC TSR.
; The PSP selector must be in cs:current_psp_selector.
; The PSP should contain the command line argument at PSP:81h
; with the command line length in PSP:80h.
;
; You must do an installation check that REXX88PC is
; installed before calling this function.
;
; Call with DX set to the unknown parameter.
;
; REXX88PC Func AX=00h (execute) is called with:
; AX=00h (func 00h, execute)
; ES:BX=name of script to execute followed by arguments (PSP:81h)
; DX:DI=REXX88PC reentrancy flag (CS:rexx88pc_reentrancy_flag)
; SI=unknown parameter
;
; All registers are destroyed.

exec_rexx88pc   proc near               ; CODE XREF: _TEXT:00D2↑p
                mov     es, cs:current_psp_selector ; We store the current PSP selector here. This is the PSP
                                        ; of the currently executing REXX program.
                assume  es:_PSP
                mov     bl, cmdline_len ; Get command line arguments length
                sub     bh, bh          ; BH=0; BX=index to end of command line arguments

loc_1EC:                                ; DATA XREF: exec_rexx88pc+21↓r
                                        ; rexx88pc_installation_check+15↓r ...
                mov     byte ptr [offset cmdline_args + bx], 0 ; Null-terminate command line arguments
                mov     cx, bx          ; CX is now length of PSP up to end of arguments

loc_1F4:                                ; BX = 81h (pointer to command line arguments in PSP)
                mov     bx, offset cmdline_args
                mov     si, dx          ; SI = DX
                mov     di, offset rexx88pc_exec_struc ; DI = REXX88PC exec options structure
                push    cs              ; DX:DI = CS:rexx88pc_exec_struc
                pop     dx              ; DX:BX = CS:81h (pointer to command line arguments in PSP)
                mov     ax, 0           ; REXX88PC Func AX=0 (exec)
                int     7Ch             ; IBM REXX88PC command language
                retn
exec_rexx88pc   endp

; ---------------------------------------------------------------------------
zero_word       dw 0                    ; DATA XREF: rexx88pc_installation_check+1↓r
                                        ; This is so we can do MOV DS,0
msg_rexx_isnt_installed db 0Dh,0Ah      ; DATA XREF: rexx88pc_installation_check+28↓o
                db 'REXX isn',27h,'t installed',0Dh,0Ah,'$' ; Prints "REXX isn't isntalled" if REXX88PC hasn't been loaded
rexx_not_installed_vector dw 1A1Ah          ; DATA XREF: rexx88pc_installation_check+38↓o
                                        ; This is set to 0000:1A1A
                db    0
rexx88pc_vector_ours db    0            ; DATA XREF: _TEXT:00C1↑o

; =============== S U B R O U T I N E =======================================

; Checks if REXX88PC's TSR has been loaded yet.
;
; If it hasn't been loaded, it prints "REXX isn't installed" to the console,
; sets the rexx88pc_vector to rexx_installed_vector, and returns.
;
; If it has been loaded, it calls REXX88PC Func AH=1 to and stores the
; returned result in rexx88pc_vector.
;
; All registers are preserved.

DOS_PUT_MESSAGE equ     9

rexx88pc_installation_check proc near   ; CODE XREF: int7ch_dispatcher+A2↑p

                push    ds
                mov     ds, cs:zero_word ; Preserve DS; DS=0000: (interrupt vector table)
                cmp     word ptr ds:[07Ch * 4], offset int7ch_handler ; Is the REXX88PC Int 7Ch vector currently our own?
                pop     ds              ; Restore DS
                jz      short rexx88pc_not_installed ; Vector is our own, which means REXX88PC isn't installed
                call    pusha_proc      ; Preserve all registers before calling REXX88PC
                mov     ax, 1           ; REXX88PC Func 01h - get vector in DS:DX
                int     7Ch             ; IBM REXX88PC command language
                mov     word ptr cs:rexx88pc_vector+2, ds ; Store DS:DX result
                mov     word ptr cs:rexx88pc_vector, dx ; This points to the "in REXX88PC" counter.
                call    popa_proc       ; Restore all registers
                ret
rexx88pc_not_installed:                 ; CODE XREF: rexx88pc_installation_check+D↑j
                push    ax              ; Preserve AX, DX, DS
                push    dx
                push    ds
                mov     dx, offset msg_rexx_isnt_installed ; Print "REXX isn't installed"
                push    cs
                pop     ds
                mov     ah, DOS_PUT_MESSAGE ; DOS Int 21h Func 09h = Print string
                pushf                   ; Call original DOS Int 21h
                call    dword ptr cs:int21h_offset
                pop     ds              ; Restore AX, DX, DS
                pop     dx
                pop     ax
                mov     rexx88pc_off, offset rexx_not_installed_vector ; This is a vector we use so that we
                mov     rexx88pc_sel, cs    ; check if the REXX88PC work area doesn't exist yet.
                ret

rexx88pc_installation_check endp

; ---------------------------------------------------------------------------
pusha_popa_caller dw 0                  ; DATA XREF: pusha_proc↓w
                                        ; pusha_proc+F↓r ...

; =============== S U B R O U T I N E =======================================


pusha_proc      proc near               ; CODE XREF: int7ch_dispatcher-8C↑p
                                        ; _TEXT:00B9↑p ...
                pop     cs:pusha_popa_caller
                pushf
                push    ax
                push    bx
                push    cx
                push    dx
                push    si
                push    di
                push    bp
                push    ds
                push    es
                push    cs:pusha_popa_caller
                retn
pusha_proc      endp ; sp-analysis failed


; =============== S U B R O U T I N E =======================================


popa_proc       proc near               ; CODE XREF: _TEXT:file_starts_with_slash_char↑p
                                        ; _TEXT:already_have_dos_version↑p ...
                pop     cs:pusha_popa_caller
                pop     es
                pop     ds
                pop     bp
                pop     di
                pop     si
                pop     dx
                pop     cx
                pop     bx
                pop     ax
                popf
                push    cs:pusha_popa_caller
                retn
popa_proc       endp ; sp-analysis failed


; This is our replacement BIOS Int 1Bh Ctrl+Break handler.

; Standard REXX88PC-compatible vector area which is used for hooking vectors.

int1bh_vector_area proc far
                assume  cs:_TEXT,ds:nothing,es:nothing,ss:nothing

                jmp     short int1bh_handler

int1bh_vector   label   dword
int1bh_offset   dw      0               ; The original Int 1Bh vector for us to chain to
int1bh_selector dw      0 

                db      4Bh,REENTRANT_42h,0

                jmp     short int1bh_jump ; Skip the next 7 blank bytes

                db      7 dup (0)

int1bh_jump:    ret        

int1bh_vector_area endp

int1bh_handler  proc     far    

                mov     dos_reentrancy_flag, REENTRANT_42h ; Clear the reentrancy flag
                push    ax
                push    bx
                mov     ax, 8           ; Call REXX88PC AX=8 BX=0 function (notify Ctrl+Break)
                mov     bx, 0           ; BX=0: Set Ctrl+Break flag
                int     7Ch             ; This actually calls ourself if REXXIBMR is not installed
                pop     bx              ; Restore AX and BX
                pop     ax
                clc                     ; Clear carry flag
                jmp     int1bh_vector   ; Chain to the original Ctrl+Break handler

int1bh_handler  endp

; This our own handler that hooks REXX88PC (Int 7Ch).

VECTOR_SIGNATURE equ    80h

int7ch_handler  proc    far
                assume  cs:_TEXT,ds:nothing,es:nothing,ss:nothing

                jmp     int7ch_proc_main ; int7ch_handler immediately jumps here. We then handle the call in the dispatcher
                                        ; after saving a pointer to the caller.
int7ch_vector   label   dword           ; The original Int 7Ch vector for us to chain to
int7ch_offset   dw 0                
int7ch_selector dw 0                   

                db      4Bh,REENTRANT_42h ; Signature
int7ch_signature db     0               ; After this driver is initialised, this is set to 80h

                jmp     short int7ch_jump ; Skip the next 7 blank bytes
                db 7 dup(0)             ; 7 null bytes
int7ch_jump:    retf
int7ch_handler  endp

; int7ch_handler immediately jumps here. We then handle the call in the dispatcher
; after saving a pointer to the caller.

int7ch_proc_main proc   far
                assume  cs:_TEXT,ds:nothing,es:nothing,ss:nothing

                pop     intxxh_caller_offset ; Far pointer to caller of Int 7Ch or Int 21h
                pop     intxxh_caller_selector
                popf
                push    intxxh_caller_selector
                push    intxxh_caller_offset ; Far pointer to caller of Int 7Ch or Int 21h
                call    near ptr offset int7ch_dispatcher ; Func 7Ch call dispatcher.
                ret
int7ch_proc_main endp

                jmp     short near ptr int21h_handler ; This code is unreachable?
int21h_offset   dw 0                    ; DATA XREF: int7ch_dispatcher-A0↑r
                                        ; int7ch_dispatcher-93↑r ...
int21h_selector dw 0                    ; DATA XREF: device_command_init+2A↓w
                db 4Bh
                db 42h
                db 0
; ---------------------------------------------------------------------------
                jmp     short int21h_jump ; In theory this code is not reachable?
; ---------------------------------------------------------------------------
                db 7 dup(0)             ; 7 null bytes
; ---------------------------------------------------------------------------

int21h_jump:                            ; CODE XREF: _TEXT:02F4↑j
                retf

; =============== S U B R O U T I N E =======================================

; This is our own handler which hooks DOS Int 21h.

int21h_handler  proc far                ; CODE XREF: _TEXT:02EB↑j
                                        ; DATA XREF: device_command_init+60↓o
                pop     cs:intxxh_caller_offset ; Far pointer to caller of Int 7Ch or Int 21h
                pop     cs:intxxh_caller_selector ; Save caller's far address
                push    cs:intxxh_caller_selector ; Should be ADD SP,4
                push    cs:intxxh_caller_offset ; Far pointer to caller of Int 7Ch or Int 21h
                cmp     ah, 3Dh ; '='   ; DOS Int 21h Func AH=3Dh (open)?
                jz      short int21h_func3dh_open_handler ; If so go to that handler
                jmp     int_21h_func_3eh_3fh_42h_and_all_others ; Go to handler for other traps than Func 3Dh
; ---------------------------------------------------------------------------

int21h_func3dh_open_handler:            ; CODE XREF: int21h_handler+17↑j
                push    bx              ; Preserve BX and AX
                push    ax
                mov     bx, dx          ; DS:BX = DS:DX (pointer to null terminated string of file name)

scan_to_end_of_string:                  ; CODE XREF: int21h_handler+27↓j
                mov     al, [bx]        ; Should be MOV SI,BX; REPNZ SCASB; MOV BX,SI
                                        ; Scan to end of string
                cmp     al, 0
                jz      short at_end_of_string ; Check file extension. Assumes filename has an
                                        ; extension and that the filename is longer than 3 characters.
                inc     bx
                jmp     short scan_to_end_of_string ; Should be MOV SI,BX; REPNZ SCASB; MOV BX,SI
                                        ; Scan to end of string
; ---------------------------------------------------------------------------

at_end_of_string:                       ; CODE XREF: int21h_handler+24↑j
                sub     bx, 3           ; Check file extension. Assumes filename has an
                                        ; extension and that the filename is longer than 3 characters.
                mov     al, [bx]
                or      al, 20h         ; Convert character to lowercase
                cmp     al, 'b'         ; Check for ending in "BAT"
                jnz     short is_not_bat_file
                inc     bx
                mov     al, [bx]
                or      al, 20h
                cmp     al, 'a'
                jnz     short is_not_bat_file
                inc     bx
                mov     al, [bx]
                or      al, 20h
                cmp     al, 't'
                jnz     short is_not_bat_file ; Is it a match for ending in "BAT"?
                cmp     cs:command_com_psp_selector, 0 ; If so, check if we have ever opened a BAT file before
                jnz     short already_have_psp_selector ; If not, we can assume this is COMMAND.COM trying to run a BAT file for the first time
                pushf
                mov     ah, 51h ; 'Q'   ; DOS Int 21h Func AH=51h (get current PSP, returned in BX)
                call    dword ptr cs:int21h_offset
                mov     cs:command_com_psp_selector, bx ; Store PSP of current process which we assume is COMMAND.COM
                mov     es, bx          ; Load ES with our current PSP
                assume es:nothing
                mov     bx, 100h        ; Jump to beginning of binary image
                mov     ax, es:[bx]     ; Obtain first two bytes of program we just loaded
                mov     cs:first_word, ax ; Store that
                push    es              ; Preserve PSP segment
                jmp     short check_bp_for_new_psp ; If BP is not 0 or 1, do not handle this call
; ---------------------------------------------------------------------------
                nop

is_not_bat_file:                        ; CODE XREF: int21h_handler+32↑j
                                        ; int21h_handler+3B↑j ...
                jmp     chain_int21h_pop_ax_bx
; ---------------------------------------------------------------------------

already_have_psp_selector:              ; CODE XREF: int21h_handler+4C↑j
                push    es              ; Preserve ES
                pushf                   ; Call DOS Int 21h Func AH=51h (get PSP)
                mov     ah, 51h ; 'Q'
                call    dword ptr cs:int21h_offset
                mov     es, bx
                assume es:nothing
                mov     bx, 100h        ; Inspect the current loaded program
                mov     ax, es:[bx]
                cmp     ax, cs:first_word ; Does BX:[100h] seem to match what we think the current program is?
                jnz     short chain_int21h_pop_es_ax_bx ; If not, chain to original DOS Int 21h
                cmp     dx, 80h         ; Is DX >= 80h?
                jnb     short chain_int21h_pop_es_ax_bx ; If it is, chain to original DOS Int 21h
                cmp     bp, 0           ; Is BP=0 or BP=1?
                                        ; (Should be CMP BP,1; JA chain_int21h_pop_es_ax_bx)
                jz      short bp_is_zero ; If we don't have an Int 7Ch caller offset, skip this part
                cmp     bp, 1
                jnz     short chain_int21h_pop_es_ax_bx ; If BP is not 0 or 1,
                                        ; then chain to the original DOS Int 21h

bp_is_zero:                             ; CODE XREF: int21h_handler+8F↑j
                cmp     cs:int7ch_caller_offset, 0 ; If we don't have an Int 7Ch caller offset, skip this part
                jz      short check_bp_for_new_psp ; Check for BP=0 or BP=1 signature.
                mov     ax, cs:int7ch_caller_offset ; Compare Int 7Ch caller offset with the current caller offset
                cmp     ax, cs:intxxh_caller_offset ; Far pointer to caller of Int 7Ch or Int 21h
                jz      short chain_int7ch_pop_es_ax_bx ; If the current caller is the Int 7Ch caller, chain to Int 7Ch
                cmp     cs:dos_reentrancy_flag, 43h ; 'C' ; Is our Int 21h reentrancy flag 43h?
                jnz     short search_call_stack ; If not, search the call stack for the caller's offset
                mov     bx, ds
                cmp     bx, cs:caller_ds ; If caller_ds does not match current DS, then chain out
                jnz     short chain_int21h_pop_es_ax_bx

search_call_stack:                      ; CODE XREF: int21h_handler+AF↑j
                pop     es              ; Enter with PUSH BX,AX,ES; keep ES on top of stack
                assume es:nothing
                push    es
                push    cx              ; Preserve CX, ES:DI
                push    es
                push    di
                push    ax              ; Preserve AX
                mov     ax, ss          ; Copy SS:SP to ES:DI
                mov     es, ax
                mov     di, sp
                pop     ax              ; Restore AX
                mov     cx, 0FFFEh      ; Avoid segment wraparound
                sub     cx, di          ; Set ES:DI+CX to reach to end of segment
                shr     cx, 1           ; Convert CX to # words instead of bytes
                cmp     cx, 100h        ; Don't scan more than 256 words (512 bytes)
                jle     short trunc_cx_to_100h ; Search next 512 bytes (256 words) of stack for AX
                mov     cx, 100h

trunc_cx_to_100h:                       ; CODE XREF: int21h_handler+D2↑j
                repne scasw             ; Search next 512 bytes (256 words) of stack for AX
                pop     di              ; Restore ES:DI, CX
                pop     es
                pop     cx
                jnz     short chain_int21h_pop_es_ax_bx ; If AX not found in stack, chain to original DOS Int 21h
                jmp     short chain_int7ch_pop_es_ax_bx ; If AX found in stack, chain to original REXX88PC Int 7Ch
; ---------------------------------------------------------------------------
                nop

check_bp_for_new_psp:                   ; CODE XREF: int21h_handler+68↑j
                                        ; int21h_handler+9C↑j
                cmp     bp, 0           ; Check for BP=0 or BP=1 signature.
                jz      short check_dx_80h ; DX >= 80h?
                cmp     bp, 1
                jnz     short chain_int21h_pop_es_ax_bx ; If neither, chain to original DOS Int 21h handler.

check_dx_80h:                           ; CODE XREF: int21h_handler+E4↑j
                cmp     dx, 80h         ; DX >= 80h?
                jnb     short chain_int21h_pop_es_ax_bx ; If DX >= 80h, then pop ES,AX,BX and chain to Int 21h
                mov     ax, cs:intxxh_caller_offset ; If DX < 80h, load the ultimate return address of our caller
                mov     cs:int7ch_caller_offset, ax ; Store that and then fall into our own int 7Ch handler

chain_int7ch_pop_es_ax_bx:              ; CODE XREF: int21h_handler+A7↑j
                                        ; int21h_handler+DE↑j ...
                pop     es
                pop     ax
                pop     bx
                jmp     int7ch_proc_main ; int7ch_handler immediately jumps here. We then handle the call in the dispatcher
                                        ; after saving a pointer to the caller.
; ---------------------------------------------------------------------------

chain_int21h_pop_es_ax_bx:              ; CODE XREF: int21h_handler+84↑j
                                        ; int21h_handler+8A↑j ...
                pop     es

chain_int21h_pop_ax_bx:                 ; CODE XREF: int21h_handler:is_not_bat_file↑j
                pop     ax
                pop     bx

chain_int21h:                           ; CODE XREF: int21h_handler+116↓j
                                        ; int21h_handler+11B↓j
                jmp     dword ptr cs:int21h_offset

int_21h_func_3eh_3fh_42h_and_all_others:
                cmp     ah, 3Eh ; '>'   ; Close?
                jz      short is_hooked_21h
                cmp     ah, 3Fh ; '?'   ; Read?
                jz      short is_hooked_21h
                cmp     ah, 42h ; 'B'   ; Seek?
                jz      short is_hooked_21h
                jmp     short chain_int21h; Any other calls, simply chain through
is_hooked_21h:  cmp     bx, REXX88_ESCAPE ; Is this our special file handle of 63h?
                jnz     short chain_int21h ; Otherwise chain to original DOS Int 21h handler
                push    bx              ; Preserve registers for jump
                push    ax
                push    es
                jmp     short chain_int7ch_pop_es_ax_bx ; Restore registers and chain to our Int 7Ch handler
int21h_handler  endp ; sp-analysis failed


; This is the interrupt routine for DOS.
;
; Realistically, the only thing this driver does is call its own initialisation
; routine. For anything else, it returns an error.

interrupt_routine proc  far
                les     bx, devreq_vector
                or      word ptr es:[bx+3], 100h ; Set return to request completed successfully
                mov     al, es:[bx+2]   ; Load device command code
                test    al, al          ; AL=00h? (Device init request)
                jz      device_command_init ; Chain to the initialisation procedure.
                or      word ptr es:[bx+3], 8003h ; Set an error return of invalid command
                ret

; This initialisation function is set when DOS loads our driver.
; The end of this function really should be set to the start device_command_init
; instead of the end of device_command_init.
;
; This hooks Int 1Bh (Ctrl+Break), Int 21h (DOS), and Int 7Ch (REXX88PC).
;
; The purpose of hooking Int 7Ch is so we can detect if REXX88PC is installed
; or not.
;
; Int 1Bh hooks Ctrl+Break and notifies REXX88PC of Ctrl+Break conditions.

device_command_init:
                mov     ax, offset end_of_driver
                mov     es:[bx+0Eh], ax ; Store our driver's size in the request header for return
                mov     word ptr es:[bx+10h], cs
                xor     ax, ax          ; AX=0
                mov     es, ax          ; ES=0000: (interrupt vector table)
                assume  es:_IVT
                les     bx, ivt_1bh     ; Get Int 1Bh vector
                mov     int1bh_offset, bx ; Store original offset
                mov     int1bh_selector, es ; Store original selector
                mov     es, ax          ; ES=0000:
                les     bx, ivt_21h     ; Get Int 21h vector
                mov     int21h_offset, bx ; Store original offset
                mov     int21h_selector, es ; Store original selector
                mov     es, ax          ; ES=0000:
                les     bx, ivt_7ch     ; Get Int 7Ch vector
                mov     int7ch_offset, bx ; Store original offset
                mov     int7ch_selector, es ; Store original selector
                mov     int7ch_signature, VECTOR_SIGNATURE ; Set the flag to 80h that shows we've initialised
                mov     es, ax          ; ES=0000:
                mov     ivt_1bh_off, offset int1bh_handler ; This is our own handler that hooks BIOS Ctrl+Break Int 1Bh.
                mov     ivt_1bh_sel, cs
                mov     ivt_7ch_off, offset int7ch_handler ; This is our own handler that hooks REXX88PC Int 7Ch.
                mov     ivt_7ch_sel, cs
                mov     ivt_21h_off, offset int21h_handler ; This is our handler that hooks DOS Int 21h.
                mov     ivt_21h_sel, cs

end_of_program:                         ; DATA XREF: device_command_init↑t
                ret
interrupt_routine       endp

end_of_driver   label   near

_TEXT           ends

_IVT            segment at 0 public 'IVT'

                org     21h * 4
ivt_21h         label   dword
ivt_21h_off     dw      ?
ivt_21h_sel     dw      ?

                org     01bh * 4
ivt_1bh         label   dword
ivt_1bh_off     dw      ?
ivt_1bh_sel     dw      ?

                org     07ch * 4
ivt_7ch         label   dword
ivt_7ch_off     dw      ?
ivt_7ch_sel     dw      ?

_IVT            ends

_PSP            segment at 0 public 'PSP'

                org     80h
cmdline_len     db      ?
cmdline_args    db      7fh dup (?)

_PSP            ends

                end

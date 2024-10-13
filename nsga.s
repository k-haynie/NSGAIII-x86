extern printf               ; doing this manually would be nightmarish

; LIFESAVERS
; https://en.wikibooks.org/wiki/X86_Assembly/X86_Architecture
; https://kobzol.github.io/davis/


section .data
    ; declare a list of 4-byte values to be sorted
    list dd 34,5,29,9,41,68,78,42,98,51,1,86,80,92,95,23,16,56,72,73
    
    ; save their count as n - 1
    count dd 19

    ; preserve an output format
    fmt: db "number: %d", 10, 0


section .text
    global _start

; bubble sort
_start:
    mov edx, [count]                        ; initialize the count in edx

    outer:
        mov ecx, [count]                    ; duplicate the count in ecx
        mov esi, list                       ; move the list start pointer to esi

        inner:
            mov eax, [esi]                  ; load the initial value into eax
            mov ebx, [esi + 4]              ; load the proposed larger value into ebx

            cmp eax, ebx                    ; compare eax and ebx
            jl no_swap                      ; if eax < ebx, no swap is needed - jump ahead

            mov [esi + 4], eax              ; otherwise, swap [esi] and [esi + 4]
            mov [esi], ebx                  ; the "+4" coming from the dword

            no_swap:
                add esi, 4                  ; move the list pointer to the next dword
                loop inner                  ; repeat until ecx is met
        
        dec edx                             ; decrement edx (outer counter)
        jnz outer                           ; repeat until everything is done

add esi, 4              ; initialize the esi pointer

print_loop:
    sub esi, 4          ; decrement the array pointer
    push dword [esi]    ; push the top of the list reference
    push fmt            ; push the format
    call printf         ; print nicely
    add esp, 4          ; increment the stack pointer
    cmp esi, list       ; compare the current pointer with the array start
    jnz print_loop      ; loop if necessary

done_printing:          ; exit
    mov eax,1
    int 0x80


; ;Bubble sort 10 numbers in place
; https://kobzol.github.io/davis/
; ; https://github.com/mish24/Assembly-step-by-step/blob/master/Bubble-sort.asm


; .data
; ArrX DW 3, 7, 4, 9, 8, 3, 12, 5
; ArrY DW 6, 4, 8, 7, 5, 3, 1, 2


; Sample points for sorting
; p1 -  3, 6
; p2 -  7, 4
; p3 -  4, 8
; p4 -  9, 7
; p5 -  8, 5
; p6 -  3, 3
; p7 - 12, 1
; p8 -  5, 2

; Rank 1 - p6, p7, p8
; Rank 2 - p1, p2
; Rank 3 - p3, p5
; Rank 4 - p4


; registers - fourr 32-bit data registers
; EAX, EBX, ECX, EDX
; AX is the accumulator
; BX is the base register
; CX is the count register
; DX is the data register (I/O) operations

; Pointer registers
; IP is the instruction pointer (next instruction to be executed)
; SP (stack pointer, current position)
; BP (referencing parameter values for a subroutine)

; Index registers
; SI (source index for string operations)
; DI (destination index for string operations)

; Control registers
; OF (overflow)
; DF (direction (left/right))
; IF (external interrupts enabled)

; _start:
;     mov edx,len        ; messange length
;     mov ecx,msg        ; message to write
;     mov ebx,1          ; file descriptor (stdout)
;     mov eax,4          ; system call number (sys_write)
;     int 0x08            ; call kernel

;     mov eax,1           ; system call number (sys_exit)
;     int 0x08            ; call kernel; SF (sign flag +-)
; ZR (result of an arithmetic operation)
; AF (auxiliary carry flag)
; PF (parity flag) total of 1-bits from the result
; CF (carries 0 or one from the high-order bit after arithmetic operation)

;
; mut_pm takes x, xl, xu, eta, prob, and at_least_once
; var n,int
; var n_var, int

; osy https://en.wikipedia.org/wiki/Test_functions_for_optimization



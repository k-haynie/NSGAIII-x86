extern printf               ; doing this manually would be nightmarish

; LIFESAVERS
; https://en.wikibooks.org/wiki/X86_Assembly/X86_Architecture
; https://kobzol.github.io/davis/


section .data
    ; declare a list of n #  x-y double dword value pairs to be sorted
    listxy dd 3,6, 7,4, 4,8, 12,1, 9,7, 8,5, 3,3, 7,2


    
    ; save their count as n - 1
    count dd 8

    ; preserve an output format
    fmt: db "(%d, %d)", 10, 0


section .text
    global _start

; bubble sort
_start:
    mov edx, [count]                        ; initialize the count in edx
    mov edi, listxy

    outer:
        mov ecx, [count]                    ; duplicate the count in ecx
        mov esi, listxy                      ; move the list start pointer to esi

        inner:
            ; check if x1 > x2
            cmp edx, ecx
            je next                         ; if the two are equal, move on
            
            ;  cmp_x:
            mov eax, [esi]                  ; x1
            mov ebx, [edi]              ; x2

            cmp eax, ebx                    ; compare eax and ebx
            jl next                         ; if eax < ebx, no swap is needed - jump ahead

            cmp_y:
            mov eax, [esi + 4]              ; y1
            mov ebx, [edi + 4]             ; y2
            
            cmp eax, ebx                    ; compare eax, ebx
            jl next


            ; push dword [esi + 4]    ; push the top of the list reference
            ; push dword [esi]
            ; push fmt            ; push the format
            ; call printf         ; print nicely
            ; add esp, 12          ; increment the stack pointer

            mov dword [esi + 4], 100                    ; zero-out dominating solutions
            mov dword [esi], 100

            next:      
                           ; move the list pointer to the next dword
                
                
                
                ; push edx     ; push the top of the list reference
                ; push ecx
                ; push fmt            ; push the format
                ; call printf         ; print nicely
                ; add esp, 12          ; increment the stack pointer
                    
                add esi, 8
                dec ecx
                cmp ecx, 0
                jnz inner             ; repeat until ecx is met
        
        add edi, 8
        dec edx                       ; decrement edx (outer counter)
        cmp edx, 0
        jnz outer                           ; repeat until everything is done



mov ecx, [count]

print_loop:
    
    push dword [edi - 4]    ; push the top of the list reference
    push dword [edi - 8]
    push fmt            ; push the format
    call printf         ; print nicely

    add esp, 12          ; increment the stack pointer
    sub edi, 8 
    cmp edi, listxy
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
extern printf               ; doing this manually would be nightmarish

; LIFESAVERS
; https://en.wikibooks.org/wiki/X86_Assembly/X86_Architecture
; https://kobzol.github.io/davis/


section .data
    ; declare a list of n #  x-y double dword value pairs to be sorted
    count dd 8
    listxy dd 3,6,0,0,0,   4,8,0,0,0,  12,1,0,0,0,    9,7,0,0,0,    8,5,0,0,0,    3,3,0,0,0,    7,2,0,0,0,   7,4,0,0,0,  

    ; 2-dimenesional Das-Dennis reference directions, courtesy of pymoo
    ;dasdennis dd 0,1,0,   0.08333333,0.91666667,1,   0.16666667,0.83333333,2,   0.25,0.75,3,   0.33333333,0.66666667,4,   0.41666667,0.58333333,5,   0.5,0.5,6,   0.58333333,0.41666667,7,   0.66666667,0.33333333,8,   0.75,0.25,9,   0.83333333,0.16666667,10,   0.91666667,0.08333333,11,   1,0,12
    ; slope, id - 6 sig digits
    dasdennis dd 100000000,0,   11000000,1,   5000000,2,   3000000,3,   2000000,4,   1400000,5,   1000000,6,   0714285,7,   0500000,8,   0333333,9,   0199999,10, 0090909,11, 0000000,12

    refcount dd 12
    front dd 1
    changed dd 0
    bestref dd 100000000,0

    ; preserve an output format
    fmt: db "(%d, %d, %d, %d)", 10, 0
    fmtd: db "changed: (%d)", 10, 0
    fmtdd: db "dasdennis: (%d)", 10, 0
    fmts: db "slopediv: (%d)", 10, 0
    fmtf: db "changed: (%f)", 10, 0

    fmt3: db "1 (%f) 2 (%f)", 10, 0
    fmt4: db "(%d, %d) dominates (%d, %d) on front %d", 10, 0


section .text
    global _start


_start:
    mov edx, [count]                        ; initialize the count in edx
    mov edi, listxy

    outer_nds:
        mov ecx, [count]                    ; duplicate the count in ecx
        mov esi, listxy                      ; move the list start pointer to esi

        inner_nds:
            ; check if i = j, skip if so
            cmp edx, ecx
            je next                         ; if the two are equal, move on

            ; compare front values and ignore
            ; if either i or j are already dominated
            mov ebx, [front]
            dec ebx                         ; only reconsider items with a front a step down from the new potential
            mov eax, [esi + 8]
            cmp eax, ebx                    
            jnz next                        ; if the value already has a front, skip this value
            mov eax, [edi + 8]
            cmp eax, ebx
            jnz next
            
            ;  compare x:
            mov eax, [esi]                  ; x1
            mov ebx, [edi]                  ; x2
            cmp eax, ebx                    ; compare eax and ebx
            jl next                         ; if eax < ebx, no swap is needed - jump ahead

            ; compare y:
            mov eax, [esi + 4]              ; y1
            mov ebx, [edi + 4]              ; y2
            cmp eax, ebx                    ; compare eax, ebx
            jl next

            ; assign the current front value and increment the # of points assigned a value

            add dword [esi + 8], 1
            add dword [changed], 1

            next:
                add esi, 20
                dec ecx
                cmp ecx, 0
                jnz inner_nds               ; repeat until ecx is met
        
        add edi, 20
        dec edx                             ; decrement edx (outer counter)
        cmp edx, 0
        jnz outer_nds                       ; repeat until everything is done

; if no value was changed in the current iteration, jump to print
cmp dword [changed],0
jz post_nds

; reinitialize values to go back through all items
mov edx, [count]
mov edi, listxy

; reset values for the main loop
mov eax, [front]
inc eax
mov dword [front], eax
mov dword [changed], 0
jmp outer_nds

post_nds:
    ; figure out the closest ref_dir
    mov ecx, [count]
    mov esi, listxy

    outer_ref:
        
        mov edx, 0                      ; prep for div
        mov eax, [esi + 4]              ; move y to eax
        mov ebx, [esi]                  ; move x to ebx

        div ebx                 ; eax now holds the slope of point p

        mov edx, [refcount]             ; move the count of reference points to edx 

        mov edi, dasdennis              ; move pointer to ref_dirs

        inner_ref:
            mov ebx, [edi]              ; move the slope of the current reference point to ebx
            sub ebx, eax                ; subtract the ref slope from the point slope

            ; get the absolute value of the slope differences
            cmp ebx, 0

            jg no_negate
            neg dword ebx
            
            no_negate:
            cmp dword ebx, [bestref]          ; compare the abs(slope) with the best current reference

            jl no_replace               ; if the slope is greater than the current reference, no replace (minimize slope difference)
            
            mov dword [bestref], ebx    ; replace the bestref value with the new abs(slope)
            mov ebx, [edi + 4]
            ;mov dword [bestref + 4], ebx
            ; mov ebx, [bestref + 4]
            mov dword [bestref + 4], ebx; replace the bestref index

            no_replace:                 ; reset variables for inner loop
                add edi, 8                  ; increment edi pointer for next ref
                dec edx                     ; decrement edx

                cmp edx, 0                  ; reset if all the refs have been cycled through
                jnz inner_ref

        mov edx, [bestref + 4]          ; move the index to edx
        mov [esi + 12], edx         ; reset the v_ID
        mov edi, dasdennis          ; reset 
        mov edx, [refcount]

        ; increment outer loop
        add esi, 20
        dec ecx
        cmp ecx, 0
        jz start_print
        jmp outer_ref

start_print:
    mov edi, listxy
    mov ecx, [count]

print_loop:
    ; populate the stack with the front value, y, value, and x value
    push dword [edi - 8]
    push dword [edi - 12]
    push dword [edi - 16]
    push dword [edi - 20]
    push fmt            ; push the format
    call printf         ; print nicely

    add esp, 20          ; increment the stack pointer
    add edi, 20 
    dec ecx
    cmp ecx, 0
    jnz print_loop      ; loop if necessary

done_printing:          ; exit
    mov eax,1
    int 0x80


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
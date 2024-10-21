extern printf               ; doing this manually would be nightmarish
extern rand
extern srand

; LIFESAVERS
; https://en.wikibooks.org/wiki/X86_Assembly/X86_Architecture
; https://kobzol.github.io/davis/
; https://stats.stackexchange.com/questions/581426/how-pairs-of-actual-parents-are-formed-from-the-mating-pool-in-nsga-ii


section .data
    ; pad of 6 0's to accommodate no floats
    ; declare a list of n #  x-y double dword value pairs to be sorted
    count dd 8
    listxy dd 3,6,0,0,0,   4,8,0,0,0,  12,1,0,0,0,    9,7,0,0,0,    8,5,0,0,0,    3,3,0,0,0,    7,2,0,0,0,   7,4,0,0,0,
    listcxy dd 0,0,0,0,0,   0,0,0,0,0,  0,0,0,0,0,    0,0,0,0,0,    0,0,0,0,0,    0,0,0,0,0,    0,0,0,0,0,   0,0,0,0,0,  

    ; the last negative one means non-initialized
    parents dd 0,0,0,0,-1,    0,0,0,0,-1

    ; 2-dimenesional Das-Dennis reference directions, courtesy of pymoo
    ;dasdennis dd 0,1,0,   0.08333333,0.91666667,1,   0.16666667,0.83333333,2,   0.25,0.75,3,   0.33333333,0.66666667,4,   0.41666667,0.58333333,5,   0.5,0.5,6,   0.58333333,0.41666667,7,   0.66666667,0.33333333,8,   0.75,0.25,9,   0.83333333,0.16666667,10,   0.91666667,0.08333333,11,   1,0,12
    ; slope, id, appearance_in_gen - 6 sf
    dasdennis dd 1000000000,0,0,  11000000,1,0,   5000000,2,0,   3000000,3,0,   2000000,4,0,   1400000,5,0,   1000000,6,0,   714258,7,0,   500000,8,0,   333333,9,0,   19999,10,0, 9090,11,0, 0,12,0

    refcount dd 12
    front dd 1
    changed dd 0
    bestref dd 0,0

    ; preserve an output format
    fmt: db "(edx %d, ecx %d, absd %d, sl %d)", 10, 0
    fmto: db "(%d, %d, %d, %d, %d)", 10, 0
    fmtd: db "Pareto front comparison: (%d %d)", 10, 0
    fmtdd: db "dasdennis: (%d)", 10, 0
    fmts: db "slopediv: (%d)", 10, 0
    fmttie: db "tie, (%d %d)", 10 , 0
    ; fmtd: db "changed: (%d %d)", 10, 0
    fmtr: db "(%d %d %d)", 10, 0
    fmtrd: db "replaced: (br %d with %d)", 10, 0

    fmt3: db "1 (%f) 2 (%f)", 10, 0
    fmt4: db "(%d, %d) dominates (%d, %d) on front %d", 10, 0


section .text
    global _start


_start:
    ; initialize the randomness generator
    rdtsc 
    push eax
    call srand

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


; after the non-dominated sorting, assign closest vectors
post_nds:
    ; figure out the closest ref_dir
    mov ecx, [count]
    mov esi, listxy

    outer_ref:

        ; initialize the bestref with the first item's slope
        mov eax, [dasdennis]
        mov ebx, [dasdennis + 4]
        mov [bestref], eax
        mov [bestref + 4], ebx

        mov edx, 0                          ; prep for mult
        mov eax, [esi + 4]                  ; move y to eax
        push ecx
        mov ecx, 1000000
        mul ecx                             ; multiply y by 1000000 to evaluate pseudo-fp
        pop ecx                             ; restore ecx

        mov edx, 0                          ; prep for div
        mov ebx, [esi]                      ; move x to ebx

        div ebx                             ; eax now holds the slope of point p
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

            jg no_replace               ; if the slope is greater than the current reference, no replace (minimize slope difference)
                        
            mov [bestref], ebx    ; replace the bestref value with the new abs(slope)
            
            mov ebx, [edi + 4]          ; move the new vector index to ebx
            mov [esi + 12], ebx
            mov [bestref + 4], ebx    ; set the vector index for the current point

            no_replace:                 ; reset variables for inner loop
                add edi, 12                  ; increment edi pointer for next ref
                dec edx                     ; decrement edx

                cmp edx, 0                  ; reset if all the refs have been cycled through
                jnz inner_ref

        mov edi, dasdennis          ; reset 
        mov edx, [refcount]

        ; increment outer loop
        add esi, 20
        dec ecx
        jnz outer_ref

; initialize the randomness generator
rdtsc 
push eax
call srand


; initialize  ebx with a pointer to the parent array 
mov ebx, parents            

; initialize parent
; order by smallest pareto front, then if tie, by least represented vector ID
binary_tournament:
    ; choose p1-1
    ; choose p1-2
    ; decide

    ; to choose a p1
    ; randomly select a number modulo count
    ; multiply that number by 4
    ; add number to listxy base ptr to get ptr to current exp var
    ; push onto the stack
    ; repeat, but check and make sure the pointer is different otherwise regen

    call rand               ; rand value in eax
    mov edx, 0              ; clear edx
    div dword [count]    ; populate edx with modulo value

    mov eax, edx            ; move the modulo to eax
    mov edx, 0            ; zero out edx
    mov ecx, 20
    mul ecx                 ; store the modified pointer in eax

    ; mov eax, edx            ; move the random point ID to eax
    mov esi, listxy
    add esi, eax             ; increment the base ptr by the modulo amount
    push dword eax           ; store the offset in the stack

parent_two:
    
    call rand               ; rand value in eax
    mov edx, 0              ; clear edx
    div dword [count]       ; populate edx with modulo value

    mov eax, edx            ; move the modulo to eax
    mov edx, 0            ; zero out edx
    mov ecx, 20
    mul ecx                 ; store the modified pointer in eax
    cmp eax, [esp]          ; compare the offsets
    jz parent_two           ; if the same parent was retrieved, try again

    ; mov eax, edx            ; move the random point ID to eax
    mov esi, listxy
    add esi, eax             ; increment the base ptr by the modulo amount
    ; push dword eax           ; push to the stack

    mov edi, listxy
    add edi, [esp]           ; now edi and esi point to random points


    ; compare with pareto fronts
    mov eax, [esi + 8]
    cmp dword [edi + 8], eax
    jg esi_select
    jl edi_select
    jmp tie
    ; compare 

esi_select:
    push dword [esi + 8]
    push dword [edi + 8]
    push fmtd
    call printf
    pop eax
    pop eax
    pop eax

    ; copy the esi-point to parent one or two
    mov eax, [esi]
    mov dword [ebx], eax
    mov eax, [esi + 4]
    mov dword [ebx + 4], eax
    mov eax, [esi + 8]
    mov dword [ebx + 8], eax
    mov eax, [esi + 12]
    mov dword [ebx + 12], eax
    mov eax, [esi + 16]
    mov dword [ebx + 16], eax

    ; repeat the binary tournament if just one parent has been selected
    
    add ebx, 20
    cmp ebx, parents + 20                    
    jz binary_tournament
    jmp continue

edi_select:
    push dword [esi + 8]
    push dword [edi + 8]
    push fmtd
    call printf
    pop eax
    pop eax
    pop eax

    ; copy the edi-point to parent one or two
    mov eax, [edi]
    mov dword [ebx], eax
    mov eax, [edi + 4]
    mov dword [ebx + 4], eax
    mov eax, [edi + 8]
    mov dword [ebx + 8], eax
    mov eax, [edi + 12]
    mov dword [ebx + 12], eax
    mov eax, [edi + 16]
    mov dword [ebx + 16], eax

    ; repeat the binary tournament if just one parent has been selected
    add ebx, 20
    cmp ebx, parents + 20
    jz binary_tournament
    jmp continue

tie:
    ; save the pointers to the randomly selected items
    push dword edi                    
    push dword esi

    ; save the indices of the vectors in question
    push dword [edi + 12]
    push dword [esi + 12]

    ; print verification
    ; push fmttie
    ; call printf
    ; pop eax


    mov esi, dasdennis          ; save pointer to vector array
    pop eax                     ; move the index of esi to eax
    mov ecx, 12                 ; adjust the pointer to the reference vector of the proper ID
    mul ecx
    add esi, eax
    mov eax, [esi + 8]          ; load the frequency of value in eax
    mov edx, eax                ; replace the top stack value with the frequency of esi


    mov esi, dasdennis          ; save pointer to vector array
    pop eax                     ; move the index of edi to eax
    push edx                    ; push esi freq                 
    mov ecx, 12                 ; adjust the pointer to the reference vector of the proper ID
    mul ecx
    add esi, eax
    mov eax, [esi + 8]          ; load the frequency of value in eax
    push eax                    ; push the frequency of edi

    ; print verification
    ; push fmttie
    ; call printf
    ; pop eax

    pop eax                     ; frequency of use for esi's vector
    pop ecx                     ; frequency of use for edi's vector
    pop esi
    pop edi
    cmp eax, ecx
    jg edi_select               ; esi's vector is more common = use edi
    jmp esi_select              ; otherwise (or if a tie) = use esi

continue:

    push dword [parents + 16]
    push dword [parents + 12]
    push dword [parents + 8]
    push dword [parents + 4]
    push dword [parents]
    push fmto
    call printf
    pop eax
    pop eax
    pop eax
    pop ebx
    pop ebx
    pop eax

    push dword [parents + 36]
    push dword [parents + 32]
    push dword [parents + 28]
    push dword [parents + 24]
    push dword [parents + 20]
    push fmto
    call printf
    pop eax
    pop eax
    pop eax
    pop ebx
    pop ebx
    pop eax

    ; compare pareto
    ; compare represented vectors

    ; choose p2-1
    ; choose p2-2
    ; decide

    ; crossover

    ; mutate


mov edi, listxy
mov ebx, [count]

print_loop:
    ; populate the stack with the front value, y, value, and x value
    push dword [edi + 16]
    push dword [edi + 12]
    push dword [edi + 8]
    push dword [edi + 4]
    push dword [edi]
    push fmto            ; push the format
    call printf         ; print nicely

    add esp, 24          ; increment the stack pointer
    add edi, 20 
    
    sub ebx, 1
    cmp ebx, 0
    jnz print_loop       ; loop if necessary

done_printing:          ; exit
    mov eax,1
    xor ebx, ebx
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
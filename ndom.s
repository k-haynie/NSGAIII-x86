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
    childcount dd 8
    listxy dd 3,6,0,0,0,   4,8,0,0,0,  12,1,0,0,0,    9,7,0,0,0,    8,5,0,0,0,    3,3,0,0,0,    7,2,0,0,0,   7,4,0,0,0,
    listcxy dd 0,0,0,0,0,   0,0,0,0,0,  0,0,0,0,0,    0,0,0,0,0,    0,0,0,0,0,    0,0,0,0,0,    0,0,0,0,0,   0,0,0,0,0,  

    ; the last negative one means non-initialized
    parents dd 0,0,0,0,-1,    0,0,0,0,-1
    children dd 0,0,0,0,-1,    0,0,0,0,-1

    ; 2-dimenesional Das-Dennis reference directions, courtesy of pymoo
    ;dasdennis dd 0,1,0,   0.08333333,0.91666667,1,   0.16666667,0.83333333,2,   0.25,0.75,3,   0.33333333,0.66666667,4,   0.41666667,0.58333333,5,   0.5,0.5,6,   0.58333333,0.41666667,7,   0.66666667,0.33333333,8,   0.75,0.25,9,   0.83333333,0.16666667,10,   0.91666667,0.08333333,11,   1,0,12
    ; slope, id, appearance_in_gen - 6 sf
    dasdennis dd 1000000000,0,0,  11000000,1,0,   5000000,2,0,   3000000,3,0,   2000000,4,0,   1400000,5,0,   1000000,6,0,   714258,7,0,   500000,8,0,   333333,9,0,   19999,10,0, 9090,11,0, 0,12,0

    refcount dd 12
    front dd 1
    changed dd 0
    bestref dd 0,0
    m_rate dd 1

    ; preserve an output format
    fmt: db "(%b %b %b %b %b %b)", 10, 0
    fmto: db "(%d, %d, %d, %d, %d)", 10, 0
    fmtd: db "Pareto front comparison: (%d %d)", 10, 0
    fmtdd: db "dasdennis: (%d)", 10, 0
    fmts: db "(%d)", 10, 0
    fmttie: db "(%d %d %d)", 10 , 0
    ; fmtd: db "changed: (%d %d)", 10, 0
    fmtr: db "(%d %d %d %d)", 10, 0
    fmtrd: db "(%d %d)", 10, 0
    fmtb: db "(modified: %b original: %b mask: %b)", 10, 0

    fmt3: db "1 (%b) 2 (%b)", 10, 0
    fmt4: db "(%d, %d) dominates (%d, %d) on front %d", 10, 0
    line: db "------------", 10, 0
    fmtcmp: db "(%d, %d) crossed to (%d, %d)"


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
            je next                         ; make sure same vals are assigned to the same front

            ; compare y:
            mov eax, [esi + 4]              ; y1
            mov ebx, [edi + 4]              ; y2
            cmp eax, ebx                    ; compare eax, ebx
            jl next
            je next

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

        cmp ebx, 0
        jz replace_zero_parent

        div ebx                             ; eax now holds the slope of point p
        jmp resume_process_parent

    replace_zero_parent:
        mov eax, 10000000               ; prevent a division by 0, replace with arbitrary large number

    resume_process_parent:
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
add esp, 4

; initialize  ebx with a pointer to the parent array 
mov ebx, parents          

push dword [count]              ; push the count of children to the stack
push dword listcxy

; initialize parent
; order by smallest pareto front, then if tie, by least represented vector ID
binary_tournament:
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

    pop eax                  ; clear the stack from parent 1

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
    jmp crossover

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
    jmp crossover

tie:
    ; save the pointers to the randomly selected items
    push dword edi                    
    push dword esi

    ; save the indices of the vectors in question
    push dword [edi + 12]
    push dword [esi + 12]

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

    pop eax                     ; frequency of use for esi's vector
    pop ecx                     ; frequency of use for edi's vector
    pop esi
    pop edi
    cmp eax, ecx
    jl edi_select               ; esi's vector is more common = use edi
    jmp esi_select              ; otherwise (or if a tie) = use esi

crossover:
    
    call rand               ; rand value in eax
    mov edx, 0              ; clear edx

    ; I'm only using the bottom 8 bytes here because that is within reasonable scope
    ; for typical design points
    mov ecx, 8
    div ecx                   ; populate edx with modulo value

    mov ecx, edx
    mov eax, 255
    cmp ecx, 0
    jz mask_two

mask_one:
    shr eax, 1
    loop mask_one

mask_two:
    mov edx, eax            ; edx has one of the valuese
    xor eax, 255            ; eax has the other mask

    mov ecx, [parents]      ; move x1 to ecx
    mov edi, [parents + 20] ; move x2 to edi

    and ecx, edx
    and edi, eax
    or ecx, edi
    mov [children], ecx

    mov ecx, [parents + 4]      ; move y1 to ecx
    mov edi, [parents + 24]     ; move y2 to edi

    and ecx, edx
    and edi, eax
    or ecx, edi
    mov [children + 4], ecx

    mov ecx, [parents + 20]     ; move x2 to ecx
    mov edi, [parents]          ; move x1 to edi

    and ecx, edx
    and edi, eax
    or ecx, edi
    mov [children + 20], ecx

    mov ecx, [parents + 24]     ; move y2 to ecx
    mov edi, [parents + 4]      ; move y1 to edi

    and ecx, edx
    and edi, eax
    or ecx, edi
    mov [children + 24], ecx

    mov esi, children           ; assign children pointer to esi

mutation:
    call rand               ; rand value in eax
    mov edx, 0              ; clear edx
    mov ecx, 100
    div ecx                 ; populate edx with modulo value
    cmp edx, [m_rate]       ; compare with the mutation rate
    jg population_add

    call rand
    mov edx, 0
    mov ecx, 8
    div ecx                 ; edx now holds a num in range 0-7
    mov ecx, edx            ; move to ecx
    
    mov eax, 128            ; set the default mask to 10000000
    cmp ecx, 0
    jz no_mut_shr

; shift the bitmask over a random # of times
mut_shr:
    shr eax, 1
    loop mut_shr

no_mut_shr:
    mov ecx, eax

    mov eax, [esi]              ; move xm to ecx
    xor eax, ecx                ; flip the random bit
    mov [esi], eax

    add esi, 4                  ; bump pointer up to the y-value of child m

    mov eax, [esi + 4]          ; move ym to ecx
    xor eax, ecx                ; flip the random bit
    mov dword [esi + 4], eax

    mov eax, children
    add eax, 4

    cmp eax, esi
    jz c2_mut
    jmp population_add
    
c2_mut:
    add esi, 16                 ; make esi point to child 2
    jmp mutation                ; go through the mutation process again

population_add:
    pop esi
    push fmto
    call printf
    pop edx                     ; the pointer to the child point array
    pop edx                     ; the count of elements

    ; move all the points over to the child array
    mov ecx, [children]
    mov [esi], ecx
    mov ecx, [children + 4]
    mov [esi + 4], ecx
    mov ecx, [children + 20]
    mov [esi + 20], ecx
    mov ecx, [children + 24]
    mov [esi + 24], ecx

    sub edx, 2                  ; subtract 2 from the count of children
    cmp edx, 0
    jz continue

    push edx
    add esi, 40                 ; point to the next child point two points over
    push esi

    mov ebx, parents

    ; zero out the parent values
    mov dword [parents], 0
    mov dword [parents + 4], 0
    mov dword [parents + 8], 0
    mov dword [parents + 12], 0
    mov dword [parents + 16], -1

    mov dword [parents + 20], 0
    mov dword [parents + 24], 0
    mov dword [parents + 28], 0
    mov dword [parents + 32], 0
    mov dword [parents + 36], -1

    jmp binary_tournament
    

continue:
    ; reset all the parent weightings
    mov ecx, [count]
    mov edi, listxy
    mov dword [front], 1
    mov dword [changed], 0

clear_parent:
    mov dword [edi + 8], 0
    mov dword [edi + 12], 0
    mov dword [edi + 16], 0
    add edi, 20
    loop clear_parent

    mov edx, [count]                        ; initialize the count in edx
    shl edx, 1                              ; double the count since we'll be working with both parents AND children here
    mov edi, listxy

outer_nds_all:
    mov ecx, [count]                    ; duplicate the count in ecx
    shl ecx, 1 
    mov esi, listxy                      ; move the list start pointer to esi

    inner_nds_all:
        ; check if i = j, skip if so
        cmp edx, ecx
        je next_all                         ; if the two are equal, move on

        ; compare front values and ignore
        ; if either i or j are already dominated
        mov ebx, [front]
        dec ebx                         ; only reconsider items with a front a step down from the new potential
        mov eax, [esi + 8]
        cmp eax, ebx                    
        jnz next_all                        ; if the value already has a front, skip this value
        mov eax, [edi + 8]
        cmp eax, ebx
        jnz next_all
        
        ;  compare x:
        mov eax, [esi]                  ; x1
        mov ebx, [edi]                  ; x2
        cmp eax, ebx                    ; compare eax and ebx
        jl next_all                         ; if eax < ebx, no swap is needed - jump ahead
        je next_all

        ; compare y:
        mov eax, [esi + 4]              ; y1
        mov ebx, [edi + 4]              ; y2
        cmp eax, ebx                    ; compare eax, ebx
        jl next_all
        je next_all

        ; assign the current front value and increment the # of points assigned a value

        add dword [esi + 8], 1
        add dword [changed], 1

        next_all:
            add esi, 20
            dec ecx
            cmp [count], ecx
            jnz no_inner_correct
            mov esi, listcxy
        no_inner_correct:
            cmp ecx, 0
            jnz inner_nds_all               ; repeat until ecx is met
    
    add edi, 20
    dec edx                             ; decrement edx (outer counter)
    cmp [count], edx
    jnz no_outer_correct
    mov edi, listcxy
no_outer_correct:
    cmp edx, 0
    jnz outer_nds_all                       ; repeat until everything is done

; if no value was changed in the current iteration, jump to print
cmp dword [changed],0
jz post_nds_all

; reinitialize values to go back through all items
mov edx, [count]
shl edx, 1 
mov edi, listxy

; reset values for the main loop
mov eax, [front]
inc eax
mov dword [front], eax
mov dword [changed], 0
jmp outer_nds_all

; after the non-dominated sorting, assign closest vectors
post_nds_all:
    ; figure out the closest ref_dir
    mov ecx, [count]
    shl ecx, 1 
    mov esi, listxy

    outer_ref_all:

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
        cmp ebx, 0
        jz replace_zero

        div ebx                             ; eax now holds the slope of point p
        jmp resume_process

    replace_zero:
        mov eax, 10000000               ; prevent a division by 0, replace with arbitrary large number

    resume_process:
        mov edx, [refcount]             ; move the count of reference points to edx 
        mov edi, dasdennis              ; move pointer to ref_dirs

        inner_ref_all:

            mov ebx, [edi]              ; move the slope of the current reference point to ebx
            sub ebx, eax                ; subtract the ref slope from the point slope

            ; get the absolute value of the slope differences
            cmp ebx, 0

            jg no_negate_all
            neg dword ebx
            
            no_negate_all:
                cmp dword ebx, [bestref]    ; compare the abs(slope) with the best current reference

                jg no_replace_all           ; if the slope is greater than the current reference, no replace (minimize slope difference)
                            
                mov [bestref], ebx          ; replace the bestref value with the new abs(slope)
                
                mov ebx, [edi + 4]          ; move the new vector index to ebx
                mov [esi + 12], ebx
                mov [bestref + 4], ebx      ; set the vector index for the current point

            no_replace_all:                 ; reset variables for inner loop
                add edi, 12                 ; increment edi pointer for next ref
                dec edx                     ; decrement edx

                cmp edx, 0                  ; reset if all the refs have been cycled through
                jnz inner_ref_all

        mov edi, dasdennis          ; reset 
        mov edx, [refcount]

        ; increment outer loop
        add esi, 20
        dec ecx

        cmp ecx, [count]
        jnz not_them_younguns
        mov esi, listcxy

    not_them_younguns:
        cmp ecx, 0
        jnz outer_ref_all
   
mov edi, listxy
mov ebx, [count]
shl ebx, 1

tally_parent:
    mov eax, [edi+12]           ; move the ref dir index to eax
    mov ecx, 12                 ; prime ecx for multiplication
    mul ecx                     ; multiply by 4 bytes
    mov esi, dasdennis
    add esi, eax
    add esi, 8
    mov ecx, [esi]
    add ecx, 1
    mov [esi], ecx

    add edi, 20
    dec ebx
    cmp ebx, [count]
    jnz avoid_kids
    mov edi, listcxy

avoid_kids:
    cmp ebx, 0
    jnz tally_parent

; loop through parents and kids, tabulate # of represented ref dirs and save to refdirs
; find the top #count based on pareto fronts than least represented ref dir     

bubble_sort:
    mov edx, [count]
    shl edx, 1
    sub edx, 1

    outer:
        mov ecx, [count]
        shl ecx, 1
        sub ecx, 1
        mov esi, listxy
        mov edi, listxy
        add edi, 20

        inner:
            mov eax, [esi + 8]          ; move Pareto value to eax
            mov ebx, [edi + 8]         ; move Pareto value of next to ebx

            cmp eax, ebx
            jl no_swap

            cmp eax, ebx
            jg swap

        ; if they are equal, compare the frequency of their values and take the lesser one
        comp_refs:
            mov eax, [edi + 12]         ; move the ref ID to eax
            mov ebx, 12

            push edx             
            mul ebx
            pop edx
            
            mov ebx, dasdennis
            add ebx, eax
            add ebx, 8                  ; finish calculating the pointer to freq
            push dword [ebx]            ; push to stack 

            mov eax, [esi + 12]         ; do the same for second child
            mov ebx, 12

            push edx
            mul ebx
            pop edx

            mov ebx, dasdennis
            add ebx, eax
            add ebx, 8
            mov eax, [ebx]

            pop ebx                     ; restore from earlier
            cmp eax, ebx
            jl no_swap

        swap:
            ; swap out each of the design point values
            mov eax, [esi]
            mov ebx, [edi]
            mov [edi], eax
            mov [esi], ebx

            mov eax, [esi + 4]
            mov ebx, [edi + 4]
            mov [edi + 4], eax
            mov [esi + 4], ebx
            
            mov eax, [esi + 8]
            mov ebx, [edi + 8]
            mov [edi + 8], eax
            mov [esi + 8], ebx

            mov eax, [esi + 12]
            mov ebx, [edi + 12]
            mov [edi + 12], eax
            mov [esi + 12], ebx

            mov dword [esi + 16], 0
            mov dword [edi + 16], 0

        no_swap:
            add esi, 20
            add edi, 20
            
        no_set_kids_edi:
            dec ecx
            cmp ecx, 0
            jnz inner

    back_to_outer:
        dec edx
        cmp edx, 0
        jnz outer

preprint:

mov edi, listxy
mov ebx, [count]

print_loop_c:
    ; populate the stack with the front value, y, value, and x value
    push dword [edi + 16]
    push dword [edi + 12]
    push dword [edi + 8]
    push dword [edi + 4]
    push dword [edi]
    push fmto            ; push the format
    call printf         ; print nicely

                        ; eax now holds the slope of point p
    add esp, 24          ; increment the stack pointer
    add edi, 20 
    
    sub ebx, 1
    cmp ebx, 0
    jnz print_loop_c       ; loop if necessary

push line
call printf
add esp, 4


mov edi, listcxy
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
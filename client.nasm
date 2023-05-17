; TCP Client for server_lh_8080.nasm
; ISS Program at SADT, Southern Alberta Institute of Technology
; April, 2023
; x86-64, NASM

; **********************************
; Final Project - TCP Client
; Ezra, Mitchell, Mykola, Ulysses
; **********************************

; Goals:
;   1. Create a TCP client that connects to the server
;   2. Send the user input to the server
;   3. Receive the data from the server
;   4. Sort data using selection sort
;   5. Write the data to a file


; Imports
extern exit
extern malloc


; Structs
struc sockaddr_in_type
    ; defined in man ip(7) because it's dependent on the type of address
    .sin_family:        resw 1
    .sin_port:          resw 1
    .sin_addr:          resd 1
    .sin_zero:          resd 2 ; Padding
endstruc


; Static variables
section .data
    ; Network connection variables
    sockaddr_in:
            istruc sockaddr_in_type

                at sockaddr_in_type.sin_family,  dw 0x02            ; Family:      AF_INET   -> 2
                at sockaddr_in_type.sin_port,    dw 0x901F          ; Port Number: 8080      -> 0x901F     (Big Endian, Hex)
                at sockaddr_in_type.sin_addr,    dd 0x0100007F      ; IP Address:  127.0.0.1 -> 0x0100007F (Big Endian, Hex)
                at sockaddr_in_type.sin_zero,    dd 0x00            ; Padding

            iend

    sockaddr_in_l: equ $ - sockaddr_in                              ; Length of the sockaddr_in struct

    ; open() syscall variables
    first_open_param:        db "output.txt", 0x00                  ; File to open

    line_feed                db 0xA                                 ; Line feed character

    file_format_1:           db "START OF UNFORMATTED DATA", 0xA    ; File format message
    file_format_1_len       equ $-file_format_1                     ; Length of the file format message

    second_file_message:     db "START OF SORTED DATA", 0xA         ; Second file format message
    second_file_message_len equ $-second_file_message


; Uninitialized variables
section .bss
    amount  resb 4                                                  ; User input
    buffer  resb 10000                                              ; Buffer to store the data in
    buffer2 resb 200                                                ; Buffer to store the data in


; Code
section .text

global _start

_start:
    ; Entry point of the program
    jmp _create_file


_create_file:

    ; Create the file
    mov rax, 2                          ; open() syscall
    mov rdi, first_open_param           ; Set file name parameter
    mov rsi, 0777o                      ; Set file mode to 0777o for read, write, and execute access
    mov rdx, 0777o                      ; Set file creation mode to 0777o
    syscall                             ; Invoke syscall

    ; Open the file
    mov rax, 2                          ; open() syscall
    mov rdi, first_open_param           ; Set file name parameter
    mov rsi, 0666o                      ; Set file mode to 0666o for read and write access
    mov rdx, 0777o                      ; Set file creation mode to 0777o
    syscall                             ; Invoke syscall

    mov r13, rax                        ; Set file descriptor to r13

    ; Store header ("START OF UNFORMATTED DATA")
    mov rax, 1                          ; write() syscall
    mov rdi, r13                        ; Set file descriptor
    mov rsi, file_format_1              ; Set contents to write
    mov rdx, file_format_1_len          ; Set size of contents to write
    syscall                             ; Invoke syscall

    jmp _network_connection


_network_connection:

    mov rdi, 100000                     ; Set size of the memory to allocate
    call malloc                         ; Call malloc() to allocate the memory

    push rax                            ; there will be the address of allocated memory on the stack if needed

    mov rax, 0x29                       ; socket() syscall
    mov rdi, 0x02                       ; Set domain:   AF_INET = 2, AF_LOCAL = 1
    mov rsi, 0x01                       ; Set type:     SOCK_STREAM = 1
    mov rdx, 0x00                       ; Set protocol: IPPROTO_TCP = 0
    syscall                             ; Invoke syscall

    mov r12, rax                        ; Store the socket file descriptor in r12

    mov rax, 0x2A                       ; connect() syscall
    mov rdi, r12                        ; Set socket file descriptor
    mov rsi, sockaddr_in                ; Set sockaddr_in struct
    mov rdx, sockaddr_in_l              ; Set length of the sockaddr_in struct
    syscall                             ; Invoke syscall

    cmp rax, 0x0                        ; RAX contains the ret val of connect() which will be 0 if successful
    jne _exit                           ; If the connection failed, exit the program

    xor r10, r10                        ; Clear r10

    mov rax, 0x2d                       ; recvfrom() syscall
    mov rdi, r12                        ; Set socket file descriptor
    mov rsi, buffer2                    ; Set buffer to store the data in
    mov rdx, 0x5E                       ; Set length of the buffer
    mov r8, 0x00                        ; Set flags
    syscall                             ; Invoke syscall

    mov rax, 1                          ; write() syscall
    mov rdi, 1                          ; Set file descriptor to write to
    mov rsi, buffer2                    ; Set buffer to write from
    mov rdx, 0x5E                       ; Set length of the buffer
    syscall                             ; Invoke syscall


_store_user_input:
    mov rax, 0                          ; read() syscall
    mov rdi, 0                          ; Set file descriptor to read from
    mov rsi, amount                     ; Set buffer to read into
    mov rdx, 10                         ; Set length of the buffer
    syscall                             ; Invoke syscall

    xor rax, rax                        ; Clear rax
    mov rsi, amount                     ; Set buffer to read from

    algorithm:
        cmp byte [rsi+1], 0             ; Checking for end of string (+1 fixes the "a" problem)
        je _send_to_server

        shl rax, 4                      ; Shift left (multiplying by 16)
        movzx rcx, byte [rsi]           ; Move the current byte to rcx, zero fill the unused part of the buffer
        sub rcx, 0x30                   ; Convert ASCII character to a number
        or al, cl                       ; Combine number with the lower 4 bits of rax register --> this is a logical OR operation
                                        ; The OR line works because the RAX register is empty, and OR drops bits into place if EITHER
                                        ; al or cl has 1 at a given place. So, it essentially loads the bits into al
                                        ; This can be repeated for all characters because rax is shifted left every loop

        inc rsi                         ; Increment to next digit in the input string
        jmp algorithm                   ; Unconditional loop


_send_to_server:

    mov r15, rax                        ; Store the length of the user input in r15
    mov rcx, rax                        ; Store the length of the user input in rcx
    push rcx                            ; Push the length of the user input onto the stack

    xor r10, r10                        ; Clear r10

    mov rax, 0x2c                       ; sendto() syscall
    mov rdi, r12                        ; Set socket file descriptor
    mov rsi, amount                     ; Set buffer to send from (the user input)
    mov rdx, 10                         ; Set length of the buffer
    mov r8, sockaddr_in                 ; Set sockaddr_in struct
    mov r9, sockaddr_in_l               ; Set length of the sockaddr_in struct
    syscall                             ; Invoke syscall


_receive_from_server:

    mov rax, 0x2d                       ; recvfrom() syscall (receiving the data from the server)
    mov rdi, r12                        ; Set socket file descriptor
    mov rsi, buffer                     ; Set buffer to store the data in
    mov rdx, r15                        ; Set length of the buffer
    mov r8, 0x00                        ; Set flags
    syscall                             ; Invoke syscall

    mov rax, 1                          ; write() syscall (writing the data to the file)
    mov rdi, r13                        ; Set file descriptor to write to (file)
    mov rsi, buffer                     ; Set buffer to write from (data from server)
    mov rdx, r15                        ; Set length of the buffer
    syscall                             ; Invoke syscall

    mov rax, 0                          ; read() syscall (reading the user input)
    mov rdi, 0                          ; Set file descriptor to read from (stdin)
    mov rsi, amount                     ; Set buffer to read into (user input)
    mov rdx, 10                         ; Set length of the buffer
    syscall                             ; Invoke syscall

    xor r10, r10                        ; Clear r10

    mov rax, 0x2c                       ; sendto() syscall (sending the user input to the server)
    mov rdi, r12                        ; Set socket file descriptor
    mov rsi, amount                     ; Set buffer to send from (user input)
    mov rdx, 10                         ; Set length of the buffer
    mov r8, sockaddr_in                 ; Set sockaddr_in struct
    mov r9, sockaddr_in_l               ; Set length of the sockaddr_in struct
    syscall                             ; Invoke syscall


_writing:

    mov rax, 0x2d                       ; recvfrom() syscall (receiving the data from the server)
    mov rdi, r12                        ; Set socket file descriptor
    mov rsi, buffer                     ; Set buffer to store the data in
    mov rdx, r15                        ; Set length of the buffer
    mov r8, 0x00                        ; Set flags
    syscall                             ; Invoke syscall

    mov rax, 1                          ; write() syscall (writing the data to the file)
    mov rdi, r13                        ; Set file descriptor to write to (file)
    mov rsi, buffer                     ; Set buffer to write from (data from server)
    mov rdx, r15                        ; Set length of the buffer
    syscall                             ; Invoke syscall

    mov rax, 1                          ; write() syscall (writing the data to the file)
    mov rdi, r13                        ; Set file descriptor to write to (file)
    mov rsi, line_feed                  ; Set string to write
    mov rdx, 1                          ; Set length of the string
    syscall                             ; Invoke syscall

    ; Store Header ("START OF SORTED DATA")
    mov rax, 1                          ; write() syscall (writing the data to the file)
    mov rdi, r13                        ; Set file descriptor to write to (file)
    mov rsi, second_file_message        ; Set string to write
    mov rdx, second_file_message_len    ; Set length of the string
    syscall                             ; Invoke syscall

    mov r15, buffer                     ; Set buffer to r15 (for sorting)


_sorting:

    pop rcx                             ; put the length of the array in rcx
    dec rcx                             ; decrement length, as algorithm will loop n-1 times --> (length - 1)

    xor r10, r10                        ; cleaning the involved registers
    xor r11, r11
    xor r12, r12

    mov r10, 0x0                        ; this is 'i' --> outer loop increment
    mov r11, 0x1                        ; this is 'j' --> inner loop increment


_outer_loop:                            ; r10 is the offset of the smallest unsorted value (proceeding iterations are faster than earlier ones)

    cmp r10, rcx
    je _write_to_disk                   ; if the outer loop has executed n-1 times, leave and write modified array to file

    inc r10                             ; this is where the counters for the 'for loop' are handled
    mov r11, r10
    inc r11                             ; j = i + 1


_inner_loop:

    cmp r11, rcx                        ; if the inner loop counter is the same as the array length...
    jg _outer_loop                      ; move onto the next unsorted value

    mov bl, BYTE [r15 + r11]            ; mov the current offset to be compared into lowest 8 bits of 'b' register

    cmp bl, BYTE [r15 + r10]            ; if array[j] < array[i] --> compare that byte with the smallest unsorted value
    jl _new_lower                       ; if the current byte is smaller than the smallest unsorted value, go to swap function

    inc r11                             ; if not move onto the next byte in the array
    jmp _inner_loop                     ; and repeat the loop for that value


_new_lower:                             ; this function will be executed if the current byte being examined is smaller than the smallest unsorted value

    mov bl, BYTE [r15 + r10]            ; store the next unsorted value in bl
    mov al, BYTE [r15 + r11]            ; store the value smaller than that value in al

    mov BYTE [r15 + r10], al            ; put the smaller value at the smallest unsorted offset in the array
    mov BYTE [r15 + r11], bl            ; move the larger value to the offset position that the smaller value took up --> still needs to be sorted

    inc r11                             ; increment to the next unsorted byte in the array
    jmp _inner_loop


_write_to_disk:

    mov rax, 1                          ; write() syscall
    mov rdi, r13                        ; Set file descriptor (file)
    mov rsi, r15                        ; Set buffer to write from
    mov rdx, rcx                        ; Set length of the buffer
    syscall                             ; Invoke syscall

    mov rax, 3                          ; close() syscall
    mov rdi, r13                        ; Set file descriptor (file)
    syscall                             ; Invoke syscall


_exit:
    mov rdi, 0                          ; Set exit code to 0
    call exit                           ; Invoke exit


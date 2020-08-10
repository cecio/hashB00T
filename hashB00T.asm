;
; hashB00T
;
; Old-school anti tampering seal for the MBR
;
; If you modify the script in any place, remember to update the indexes
; for the EE bytes in "install_hb.py" (see comments PATCH1 and PATCH2)
;
; Assemble with:
;
;        nasm -f bin -o hash.bin hashB00T.asm -l hashB00T.lst
;
; @red5heep
;

  cpu 8086

  org 0x0000

init:

  cld
  xor ax,ax                            ; Initialize some stuff
  mov ss,ax
  mov sp,0x7C00                        ; Initialize stack
  mov ax,0x8000                        ; Load ES for disk reading
  mov es,ax
  mov ds,ax

  mov cx,0x0001                        ; CH: cylinder, CL: sector
  mov dx,0x0080                        ; DH=head, DL=drive (bit 7=hdd)
  mov bx,0x0000                        ; Data buffer, points to ES:BX
  call read_sector

  add bx,0x200
  mov cx,0xEEEE                        ; CH: cylinder, CL: sector
  mov dh,0xEE                          ; DH=head
                                       ; The 0xEE bytes will be patched by the installer (PATCH2)
  call read_sector

  push es                              ; Now we have relocated code at 0x8000:0x0000
  mov ax,main
  push ax
  retf                                 ; Jump to the relocated code (main)

main:
  mov ax,0x0003                        ; Set video mode 80x25
  int 0x10

  xor bx,bx                            ; Compute hash of the sector ES:BX
  mov cx,0x0400                        ; Len of the buffer (MBR + VBR)
  call djb2

  mov bx,[hash_l]
  and bx,0x000F
  jnz noblack                          ; If black, change color
  inc bx
noblack:
  mov word [color],bx                  ; Set output color

  xor dx,dx                            ; From the top-left...
  call set_pos

  call print_top                       ; ...print the "seal"
  mov cx,0x0009
lp0:
  call print_mid
  loop lp0

  call print_top

  mov dx,0x0509                       ; Put the start char 'S'
  call set_pos
  mov al,0x53
  call put_char

  mov ax,[hash_l]
  call drunken_path
  mov ax,[hash_h]
  call drunken_path
  mov al,0x45                         ; Put the 'E' at the end
  call put_char

  mov ah,0                            ; Wait a key
  int 16h

                                      ; Now load the original MBR
  xor ax,ax
  mov es,ax
  mov bx,0x7C00
  mov cx,0xEEEE                       ; CH: cylinder, CL: sector
  mov dx,0xEE80                       ; DH=head, DL=drive (bit 7=hdd)
                                      ; The 0xEE bytes will be patched by the installer (PATCH1)
  push es
  push bx
  call read_sector

  mov dx,0x0080                       ; Prepare to jump to original MBR
  retf

;
; read_sector
;      CX contains the cylinder/sector to read
;      DX contains the head/drive
;      Data buffer point to ES:BX
;

read_sector:

  mov ax,0x0201                        ; AH: function, AL: # of sec to read
  int 0x13

  ret

;
; drunken_path
; Extracts couples of 2 bits of the hashed value and
; writes the path
;               AX       Hash to be displayed
;
; It starts from the least significant bit: this saves
; a lot of space. This is actually a "customized" version
; of the original algorithm
;
drunken_path:
  mov bx,ax                           ; Saves the original value
  mov cx,0x0008
l2:
  and bx,0x0003                       ; Gets the 2 least significant bits
  call map_path                       ; Pass the read value to the drawing func
  mov bx,ax
  shr bx,1                            ; Shift the value (remove the two read bits)
  shr bx,1
  mov ax,bx
  loop l2

  ret

;
; Draw the bishop path
;               BL          path coming from the hash
;
map_path:
  push ax
  push bx
  push cx

  call get_pos                        ; Get current cursor position in DX

  cmp bl,0x00
  je hash_00
  cmp bl,0x01
  je hash_01
  cmp bl,0x02
  je hash_10

  add dh,1                            ; Move down-right
  add dl,1
  jmp hash_out

hash_00:
  sub dh,1                            ; Move up-left
  sub dl,1
  jmp hash_out
hash_01:
  sub dh,1                            ; Move up-right
  add dl,1
  jmp hash_out
hash_10:
  sub dl,1                            ; Move down-left
  add dh,1
hash_out:
                                      ; Check for bounds and force values
  cmp dh,0x09                         ; Row (DH)
  jle bl0
  mov dh,0x09
bl0:
  cmp dh,0x00
  jg bl1
  mov dh,0x01
bl1:
  cmp dl,0x11                         ; Column (DL)
  jle bl2
  mov dl,0x11
bl2:
  cmp dl,0x00
  jg bl3
  mov dl,0x01
bl3:

  call set_pos

  call get_char                       ; Now we need to read the current char (AL)
  cmp al,0x53                         ; Check if 'S'
  je chout                            ; Do nothing
  cmp al,0x20                         ; If 'Space'...
  je ch0                              ; ...put the firs char in sequence
  add al,0x01                         ; ...otherwise go to the next
  cmp al,0xb2
  jle chout
  mov al,0xdb                         ; Cap the value to solid block
  jmp chout

ch0:                                  ; Different chars if the place has already been visited
  mov al,0xb0
  jmp chout

chout:
  call put_char

  pop cx
  pop bx
  pop ax
  ret

;
; Set cursor position
; Coords in     DX    DH = Row, DL = Column
;
set_pos:
  mov ah,0x02
  mov bh,0x00
  int 0x10
  ret

;
; Get cursor position
; Coords in     DX    DH = Row, DL = Column
;
get_pos:
  mov ah,0x03
  mov bh,0x00
  int 0x10
  ret

;
; Get char at cursor position
; Returns      AL     char
;
get_char:
  mov ah,0x08
  mov bh,0x00
  int 0x10
  ret

;
; Put char at cursor position
; Expects      AL     char
;              BL     color
;
put_char:
  mov ah,0x09
  mov cx,0x0001
  mov bx,[color]
  int 0x10
  ret

;
; Print functions
;

; Print the char in teletype mode
printch:
  mov ah,0x0e
  int 0x10
  ret

; Print Top line of the "seal"
print_top:
  mov al,'#'
  mov cx,0x13
pt0:
  call printch
  loop pt0

  call print_newline
  ret

; Print the mid line of the "seal"
print_mid:
  push cx

  mov al,'|'
  call printch
  call get_pos
  add dl,0x11
  call set_pos
  call printch

  call print_newline
  pop cx
  ret

print_newline:
  mov al,0x0a
  call printch
  mov al,0x0d
  call printch

  ret

;
; Compute djb2 hash of given buffer
;
;       ES:BX      Address of buffer
;       CX         Buffer length
;
;       Returns the HASH in hash_h:hash_l
;

djb2:
  push ax
  push dx
  push si

  mov ax,[hash_l]
  mov dx,[hash_h]

hash_loop:
  push cx                             ; Save buffer length
  mov cx,5                            ; loop for SHL 5
shl5_loop:
  shl ax,1
  rcl dx,1                            ; Put the carry in DX
  loop shl5_loop
  pop cx                              ; Restore the buffer length
  add ax,[hash_l]                     ; Add the additional entry
  adc dx,[hash_h]
  mov si,[byte es:bx]                 ; Move in SI to get the single byte
  and si,0x00FF
  add ax,si                           ; Add the buffer char
  adc dx,0x0

  mov [hash_l],ax
  mov [hash_h],dx

  inc bx                              ; Go to the next byte in buffer
  loop hash_loop                      ; Repeat for the total length

  pop si
  pop dx
  pop ax
  ret

;
; Variables section
;

; Some output variables
char:       db 0,0
color:      dw 0x0000                  ; It defines also BH, which is page 0 (never changes)

; Variables used for hashing
hash_l:    dw 0x1505                   ; Initialize hash with 5381 decimal
hash_h:    dw 0x0000

; Place the fake partition table
times 1BEH-($-$$) db 254
partition_table:
	db 0x80                			         ; Active partition
	db 01,02,03
	db 0x55                			         ; Filler
	times 59 db 0

; Now the MBR signature
	db 55h,0aah

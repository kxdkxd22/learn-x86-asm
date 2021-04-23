jmp near start

data1 db 0x05,0xff,0x80,0xf0,0x97,0x30
data2 dw 0x90,0xfff0,0xa0,0x1235,0x2f,0xc0,0xc5bc

number db 0,0

start:

      mov ax,0x7c0
      mov ds,ax
      mov ax,0xb800
      mov es,ax
      mov si,0

      mov cx,6
      mov di,0
      mov bx,data1

cmp_data1:
          xor ax,ax
          mov al,[bx+si]
          inc si
          cmp al,0
          jl minus_data1

data1_loop:
          loop cmp_data1
          mov ax,di
          add al,0x30
          mov byte [es:0x00],al
          mov byte [es:0x01],0x04
          jmp cmp_data22

minus_data1:
          inc di
          jmp data1_loop


cmp_data22:
          mov cx,7
          mov di,0
          mov si,0
          mov bx,data2
cmp_data2:
          xor ax,ax
          mov ax,[bx+si]
          inc si
          inc si
          cmp ax,0
          jl minus_data2

data2_loop:
           loop cmp_data2
           mov ax,di
           add al,0x30
           mov [es:0x02],al
           mov byte[es:0x03],0x04
           jmp near $

minus_data2:
            inc di
            jmp data2_loop

times 510-($-$$) db 0
      db 0x55,0xaa









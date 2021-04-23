mov cx,0
delay:loop delay

mov ax,0
mov bx,1
add ax,bx

mov dx,0xb800
mov es,dx
add al,0x30
mov byte[es:0x00],al
mov byte[es:0x01],0x04

times 510-($-$$) db 0
db 0x55,0xaa




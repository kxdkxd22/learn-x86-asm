mov ax,0xb800
mov es,ax
mov byte [es:0x00],'a'
mov byte [es:0x01],0x07
mov byte [es:0x02],'s'
mov byte [es:0x03],0x07
mov byte [es:0x04],'m'
mov byte [es:0x05],0x07
jmp $

times 510-($-$$) db 0
dw 0xaa55

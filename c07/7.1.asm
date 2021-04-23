mov ax,0x7c0
mov ds,ax
mov ax,0xfff0
and [data],ax
and ax,[data]
data db 0x55,0xaa

times 510-($-$$) db 0
db 0x55,0xaa


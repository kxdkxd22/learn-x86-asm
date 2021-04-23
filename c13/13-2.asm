core_code_seg_sel equ 0x38            ;内核代码段，段选择子
core_data_seg_sel equ 0x30            ;内核数据段，段选择子
sys_routine_seg_sel equ 0x28          ;内核公用例程段，段选择子
video_ram_seg_sel equ 0x20            ;显示缓冲区段选择子
core_stack_seg_sel equ 0x18           ;内核堆栈段选择子
mem_0_4_gb_seg_sel equ 0x08           ;0~4g内存段选择子

;内核的总长度
core_length dd core_end

;内核公用例程段的位置0x04
sys_routine_seg dd section.sys_routine.start


;内核数据段位置0x08
core_data_seg  dd section.core_data.start


;内核代码段位置0x0c
core_code_seg  dd section.core_code.start


;核心代码段入口0x10
code_entry  dd start
            dw core_code_seg_sel

            [bits 32]


;内核公用例程代码段
SECTION sys_routine vstart=0


;显示字符串例程,输入：DS:EBX=串地址
put_string:
           push ecx

.getc:
           mov cl,[ebx]
           or cl,cl
           jz .exit
           call put_char
           inc ebx
           jmp .getc

.exit:
           pop ecx
           retf

;在当前光标处显示一个字符，并推进
;输入：CL=字符ASCII码
put_char:
           pushad

           mov dx,0x3d4
           mov al,0x0e
           out dx,al
           inc dx
           in al,dx
           mov ah,al

           dec dx
           mov al,0x0f
           out dx,al
           inc dx
           in al,dx
           mov bx,ax

           cmp cl,0x0d             ;回车符
           jnz .put_0a
           mov ax,bx
           mov bl,80
           div bl
           mul bl
           mov bx,ax
           jmp .set_cursor

.put_0a:
           cmp cl,0x0a             ;换行符
           jnz .put_other
           add bx,80
           jmp .roll_screen

.put_other:
           push es
           mov eax,video_ram_seg_sel
           mov es,eax
           shl bx,1
           mov [es:bx],cl
           pop es

           shr bx,1
           inc bx

.roll_screen:
             cmp bx,2000
             jl .set_cursor

             push ds
             push es

             mov eax,video_ram_seg_sel
             mov ds,eax
             mov es,eax
             cld
             mov esi,0x0a          ;小心！32位模式下movsb/w/d
             mov edi,0x00          ;使用的是esi/edi/ecx
             mov ecx,1920
             rep movsd
             mov bx,3840
             mov ecx,80           ;清除屏幕最后一行

.cls:
             mov word[es:bx],0x0720
             add bx,2
             loop .cls

             pop es
             pop ds

             mov bx,1920

.set_cursor:
            mov dx,0x3d4
            mov al,0x0e
            out dx,al
            inc dx
            mov al,bh
            out dx,al
            dec dx
            mov al,0x0f
            out dx,al
            inc dx
            mov al,bl
            out dx,al

            popad
            ret



;从硬盘读取一个逻辑扇区
;EAX=逻辑扇区号
;DS：EBX=目标缓冲区地址     返回：EBX=EBX+512
read_hard_disk_0:
                 push eax
                 push ecx
                 push edx

                 push eax

                 mov dx,0x1f2
                 mov al,1
                 out dx,al      ;读取的扇区数

                 inc dx
                 pop eax
                 out dx,al      ;0x1f3,LBA地址7~0

                 inc dx
                 mov cl,8
                 shr eax,cl
                 out dx,al      ;0x1f4,LBA地址15~8

                 inc dx
                 shr eax,cl
                 out dx,al      ;0x1f5,LBA地址23~16

                 inc dx
                 shr eax,cl
                 or al,0xe0
                 out dx,al      ;0x1f6

                 inc dx
                 mov al,0x20
                 out dx,al

.waits:
                 in al,dx
                 and al,0x88
                 cmp al,0x08
                 jnz .waits

                 mov ecx,256
                 mov dx,0x1f0

.readw:
                 in ax,dx
                 mov [ebx],ax
                 add ebx,2
                 loop .readw

                 pop edx
                 pop ecx
                 pop eax

                 retf

;帮助调试的例程
;输入：EDX=要转换并显示的数字
put_hex_dword:
              pushad
              push ds

              mov ax,core_data_seg_sel
              mov ds,ax

              mov ebx,bin_hex
              mov ecx,8

.xlt:
              rol edx,4
              mov eax,edx
              and eax,0x0000000f
              xlat

              push ecx
              mov cl,al
              call put_char
              pop ecx
              loop .xlt

              pop ds
              popad
              retf


;分配内存
;输入：ECX=希望分配的字节数量
;输出：ECX=起始线性地址
allocate_memory:

                push ds
                push eax
                push ebx

                mov eax,core_data_seg_sel
                mov ds,eax

                mov eax,[ram_alloc]
                add eax,ecx               ;下一次分配时的起始地址

                mov ecx,[ram_alloc]       ;返回分配的起始地址

                mov ebx,eax
                and ebx,0xfffffffc
                add ebx,4
                test eax,0x00000003
                cmovnz eax,ebx
                mov [ram_alloc],eax

                pop ebx
                pop eax
                pop ds

                retf


;在GDT内安装一个新的描述符
;输入：EDX：EAX=描述符    输出：CX=描述符的选择子
set_up_gdt_descriptor:
                      push eax
                      push ebx
                      push edx

                      push ds
                      push es

                      mov ebx,core_data_seg_sel
                      mov ds,ebx

                      sgdt [pgdt]

                      mov ebx,mem_0_4_gb_seg_sel
                      mov es,ebx

                      movzx ebx,word [pgdt]     ;GDT界限
                      inc bx
                      add ebx,[pgdt+2]     ;下一个描述符的线性地址

                      mov [es:ebx],eax
                      mov [es:ebx+4],edx

                      add word [pgdt],8

                      lgdt [pgdt]

                      mov ax,[pgdt]
                      xor dx,dx
                      mov bx,8
                      div bx
                      mov cx,ax
                      shl cx,3

                      pop es
                      pop ds

                      pop edx
                      pop ebx
                      pop eax

                      retf

;构造段描述符
;输入：EAX=线性基址，EBX=段界限，ECX=属性
;返回：EDX：EAX=描述符
make_seg_descriptor:
                    mov edx,eax
                    shl eax,16
                    or ax,bx

                    and edx,0xffff0000
                    rol edx,8
                    bswap edx

                    xor bx,bx
                    or edx,ebx

                    or edx,ecx

                    retf


;内核数据段
SECTION core_data vstart=0

        pgdt      dw 0
                  dd 0

        ram_alloc dd 0x00100000  ;下次分配内存的起始地址

        ;符号地址检索表
        salt:
        salt_1         db '@PrintString'
                       times 256-($-salt_1) db 0
                       dd put_string
                       dw sys_routine_seg_sel

        salt_2         db '@ReadDiskData'
                       times 256-($-salt_2) db 0
                       dd read_hard_disk_0
                       dw sys_routine_seg_sel

        salt_3         db '@PrintDwordAsHexString'
                       times 256-($-salt_3) db 0
                       dd put_hex_dword
                       dw sys_routine_seg_sel

        salt_4         db '@TerminateProgram'
                       times 256-($-salt_4) db 0
                       dd return_point
                       dw core_code_seg_sel

        salt_item_len  equ $-salt_4
        salt_items  equ  ($-salt)/salt_item_len


        message_1 db '  If you seen this message,that means we '
                  db 'are now in project mode,and the system '
                  db 'core is loaded,and the video display '
                  db 'routine works perfectly.',0x0d,0x0a,0


        message_5 db '        Loading user program...',0

        do_status db 'Done.',0x0d,0x0a,0

        message_6 db 0x0d,0x0a,0x0d,0x0a,0x0d,0x0a
                  db '   User program terminated,control returned.',0

        bin_hex db '0123456789ABCDEF'

        core_buf times 2048 db 0   ;内核用的缓冲区

        esp_pointer  dd 0

        cpu_brnd0 db 0x0d,0x0a,' ',0
        cpu_brand times 52 db 0
        cpu_brnd1 db 0x0d,0x0a,0x0d,0x0a,0


;内核代码段
SECTION core_code vstart=0



;加载并重定位用户程序
;输入：ESI=起始逻辑扇区号
;返回：AX=指向用户程序头部的选择子
load_relocate_program:
                      push ebx
                      push ecx
                      push edx
                      push esi
                      push edi

                      push ds
                      push es

                      ;切换DS到内核数据段
                      mov eax,core_data_seg_sel
                      mov ds,eax

                      ;读取程序头部数据
                      mov eax,esi
                      mov ebx,core_buf
                      call sys_routine_seg_sel:read_hard_disk_0


                      ;以下判断程序有多大
                      mov eax,[core_buf]
                      mov ebx,eax
                      and ebx,0xfffffe00
                      add ebx,512
                      test eax,0x000001ff
                      cmovnz eax,ebx

                      mov ecx,eax        ;实际要申请的内存数量
                      call sys_routine_seg_sel:allocate_memory
                      mov ebx,ecx        ;申请到的内存首地址
                      push ebx
                      xor edx,edx
                      mov ecx,512
                      div ecx
                      mov ecx,eax        ;总扇区数

                      mov eax,mem_0_4_gb_seg_sel
                      mov ds,eax
                      mov eax,esi        ;起始扇区号

.b1:
                      call sys_routine_seg_sel:read_hard_disk_0
                      inc eax
                      loop .b1

                      ;建立程序头部段描述符
                      pop edi        ;用户程序首地址
                      mov eax,edi          ;程序头部起始线性地址
                      mov ebx,[edi+0x04]   ;段长度
                      dec ebx              ;段界限
                      mov ecx,0x00409200
                      call sys_routine_seg_sel:make_seg_descriptor
                      call sys_routine_seg_sel:set_up_gdt_descriptor
                      mov [edi+0x04],cx

                      ;建立程序代码段描述符
                      mov eax,edi
                      add eax,[edi+0x14]           ;代码段起始线性地址
                      mov ebx,[edi+0x18]           ;段长度
                      dec ebx                      ;段界限
                      mov ecx,0x00409800
                      call sys_routine_seg_sel:make_seg_descriptor
                      call sys_routine_seg_sel:set_up_gdt_descriptor
                      mov [edi+0x14],cx

                      ;建立程序数据段描述符
                      mov eax,edi
                      add eax,[edi+0x1c]           ;数据段起始线性地址
                      mov ebx,[edi+0x20]           ;段长度
                      dec ebx                      ;段界限
                      mov ecx,0x00409200
                      call sys_routine_seg_sel:make_seg_descriptor
                      call sys_routine_seg_sel:set_up_gdt_descriptor
                      mov [edi+0x1c],cx

                      ;建立程序堆栈段描述符
                      ;mov ecx,[edi+0x0c]
                      ;mov ebx,0x000fffff
                      ;sub ebx,ecx            ;段界限
                      ;mov eax,4096
                      ;mul dword [edi+0x0c]
                      ;mov ecx,eax              ;准备为堆栈分配的内存
                      ;call sys_routine_seg_sel:allocate_memory
                      ;add eax,ecx        ;堆栈的高端物理地址
                      ;mov ecx,0x00c09600
                      ;call sys_routine_seg_sel:make_seg_descriptor
                      ;call sys_routine_seg_sel:set_up_gdt_descriptor
                      ;mov [edi+0x08],cx

                      ;书后习题，用户程序自己建立堆栈段
                      mov ecx,[edi+0x0c]
                      mov ebx,0x000fffff
                      sub ebx,ecx          ;段界限

                      mov eax,4096
                      mul dword [edi+0x0c]
                      mov edx,edi
                      add edx,[edi+0x08]
                      add eax,edx              ;堆栈的高端物理地址

                      mov ecx,0x00c09600
                      call sys_routine_seg_sel:make_seg_descriptor
                      call sys_routine_seg_sel:set_up_gdt_descriptor
                      mov [edi+0x08],cx


                      ;重定位SALT
                      mov eax,[edi+0x04]           ;用户程序头部选择子
                      mov es,eax
                      mov eax,core_data_seg_sel
                      mov ds,eax

                      cld

                      mov ecx,[es:0x24]            ;用户程序的SALT条目数
                      mov edi,0x28                 ;用户程序内的SALT位于头部内0x28处


.b2:
                      push ecx
                      push edi

                      mov ecx,salt_items     ;内核SALT表的表项个数
                      mov esi,salt          ;内核SALT表的起始位置

.b3:
                      push edi
                      push esi
                      push ecx

                      mov ecx,64
                      repe cmpsd
                      jnz .b4
                      mov eax,[esi]       ;若匹配ESI恰好指向其后的地址数据
                      mov [es:edi-256],eax
                      mov ax,[esi+4]
                      mov [es:edi-252],ax

.b4:
                      pop ecx
                      pop esi
                      add esi,salt_item_len
                      pop edi
                      loop .b3

                      pop edi
                      add edi,256
                      pop ecx
                      loop .b2

                      mov ax,[es:0x04]

                      pop es
                      pop ds

                      pop edi
                      pop esi
                      pop edx
                      pop ecx
                      pop ebx

                      ret

start:
      ;使ds指向内核数据段
      mov ecx,core_data_seg_sel
      mov ds,ecx

      mov ebx,message_1
      call sys_routine_seg_sel:put_string


      ;显示处理器信息
      mov eax,0x80000002
      cpuid
      mov [cpu_brand+0x00],eax
      mov [cpu_brand+0x04],ebx
      mov [cpu_brand+0x08],ecx
      mov [cpu_brand+0x0c],edx


      mov eax,0x80000003
      cpuid
      mov [cpu_brand+0x10],eax
      mov [cpu_brand+0x14],ebx
      mov [cpu_brand+0x18],ecx
      mov [cpu_brand+0x1c],edx


      mov ebx,0x80000004
      cpuid
      mov [cpu_brand+0x20],eax
      mov [cpu_brand+0x24],ebx
      mov [cpu_brand+0x28],ecx
      mov [cpu_brand+0x2c],edx

      mov ebx,cpu_brnd0
      call sys_routine_seg_sel:put_string
      mov ebx,cpu_brand
      call sys_routine_seg_sel:put_string
      mov ebx,cpu_brnd1
      call sys_routine_seg_sel:put_string

      mov ebx,message_5
      call sys_routine_seg_sel:put_string
      mov esi,50                          ;用户程序位于逻辑50扇区
      call load_relocate_program

      mov ebx,do_status
      call sys_routine_seg_sel:put_string

      mov [esp_pointer],esp        ;临时保存堆栈指针

      mov ds,ax

      jmp far [0x10]

return_point:
             mov eax,core_data_seg_sel
             mov ds,eax

             mov eax,core_stack_seg_sel
             mov ss,eax
             mov esp,[esp_pointer]

             mov ebx,message_6
             call sys_routine_seg_sel:put_string

      hlt

SECTION core_trail

core_end:


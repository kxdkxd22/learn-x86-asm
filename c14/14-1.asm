core_code_seg_sel equ 0x38      ;内核代码段选择子
core_data_seg_sel equ 0x30      ;内核数据段选择子
sys_routine_seg_sel equ 0x28    ;系统公共例程段的选择子
video_ram_seg_sel equ 0x20      ;视频显示缓冲区的选择子
core_stack_seg_sel equ 0x18     ;内核堆栈段选择子
mem_0_4_gb_seg_sel equ 0x08     ;整个0-4GB内存的段选择子


;以下是系统核心的头部，用于加载核心程序

core_length dd core_end  ;核心程序总长度#00

sys_routine_seg dd section.sys_routine.start  ;系统公用例程段#04

core_data_seg dd section.core_data.start  ;核心数据段位置#08

core_code_seg dd section.core_code.start  ;核心代码段位置#0c

core_entry dd start  ;核心代码段入口点#10
           dw core_code_seg_sel


[bits 32]

SECTION sys_routine vstart=0


;字符串显示例程
;显示0终止的字符串并移动光标
;输入：DS:EBX=串地址
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

         ;获取光标位置
         mov dx,0x3d4
         mov al,0x0e
         out dx,al
         inc dx        ;0x3d5
         in al,dx      ;高字
         mov ah,al

         dec dx        ;0x3d4
         mov al,0x0f
         out dx,al
         inc dx        ;0x3d5
         in al,dx      ;低字
         mov bx,ax     ;BX=代表光标位置的16位数

         cmp cl,0x0d   ;回车符
         jnz .put_0a
         mov ax,bx
         mov bl,80
         div bl
         mul bl
         mov bx,ax
         jmp .set_cursor

.put_0a:
        cmp cl,0x0a      ;换行符
        jnz .put_other
        add bx,80
        jmp .roll_screen

.put_other:               ;显示正常地字符
           push es
           mov eax,video_ram_seg_sel
           mov es,eax
           shl bx,1
           mov [es:bx],cl
           pop es

           ;将光标位置推进一个字符
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
             mov esi,0xa0
             mov edi,0x00
             mov ecx,960
             rep movsd
             mov bx,3840
             mov ecx,80

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
            inc dx                 ;0x3d5
            mov al,bh
            out dx,al
            dec dx                 ;0x3d4
            mov al,0x0f
            out dx,al
            inc dx                 ;0x3d5
            mov al,bl
            out dx,al

            popad

            ret

;从硬盘读取一个逻辑扇区
;EAX=逻辑扇区号
;DS:EBX=目标缓冲区地址
;返回：EBX=EBX+512
read_hard_disk_0:
                 ;push eax
                 ;push ecx
                 ;push edx
                 ;push ebp

                 ;逻辑扇区号（参数）
                 ;数据段选择子（参数）
                 ;段内偏移（参数）
                 ;CS
                 ;EIP
                 ;8个通用寄存器
                 ;DS

                 pushad


                 push ds

                 ;mov edx,ebp
                 ;call sys_routine_seg_sel:put_hex_dword

                 mov ebp,esp


                 mov ax,[ebp+10*4]   ;提取调用者的CS
                 mov bx,[ebp+12*4]   ;提取调用者的数据段选择子
                 arpl bx,ax
                 mov ds,bx

                 mov eax,[ebp+13*4]   ;逻辑扇区号
                 mov ebx,[ebp+11*4]   ;段内偏移

                 push eax

                 mov dx,0x1f2
                 mov al,1
                 out dx,al      ;读取的扇区数

                 inc dx         ;0x1f3
                 pop eax
                 out dx,al      ;LBA地址7~0

                 inc dx         ;0x1f4
                 mov cl,8
                 shr eax,cl
                 out dx,al      ;LBA地址15~8

                 inc dx         ;0x1f5
                 shr eax,cl
                 out dx,al      ;LBA地址23~16

                 inc dx         ;0x1f6
                 shr eax,cl
                 or al,0xe0     ;LBA地址27~24
                 out dx,al

                 inc dx         ;0x1f7
                 mov al,0x20    ;读命令
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

                 ;pop ds

                 ;pop ebp
                 ;pop edx
                 ;pop ecx
                 ;pop eax

                 pop ds
                 popad


                 ;add ebx,512

                 ;mov edx,esp
                 ;call sys_routine_seg_sel:put_hex_dword

                 retf 12


;分配内存
;输入：ECX=希望分配的字节数
;输出：ECX=起始线性地址
allocate_memory:
                push ds
                push eax
                push ebx

                mov eax,core_data_seg_sel
                mov ds,eax

                mov eax,[ram_alloc]
                add eax,ecx

                mov ecx,[ram_alloc]

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

;帮助调试的例程
;在当前光标处以16进制形式显示一个双字，并推进光标
;输入：EDX=要转换并显示的数字
;输出：无
put_hex_dword:

              pushad
              push ds

              mov eax,core_data_seg_sel
              mov ds,eax

              mov ebx,bin_hex      ;指向核心数据段的转换表
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

;构造存储器和系统的段描述符
;输入：EAX=线性基地址    EBX=段界限   ECX=属性
;返回：EDX:EAX=描述符
make_seg_descriptor:
                    mov edx,eax
                    shl eax,16
                    or ax,bx         ;描述符低32位构造完毕

                    and edx,0xffff0000
                    rol edx,8
                    bswap edx          ;装配基址31~24和23~16

                    xor bx,bx
                    or edx,ebx              ;装配段界限高4位

                    or edx,ecx       ;装配属性

                    retf


;在GDT内安装一个新的描述符
;输入：EDX:EAX=描述符
;输出：CX=描述符的选择子
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

                      movzx ebx,word[pgdt]  ;GDT界限
                      inc bx                ;下一个描述符的偏移地址
                      add ebx,[pgdt+2]      ;下一个描述符的线性地址

                      mov [es:ebx],eax
                      mov [es:ebx+4],edx

                      add word [pgdt],8

                      lgdt [pgdt]

                      mov ax,[pgdt]
                      xor dx,dx
                      mov bx,8
                      div bx
                      mov cx,ax
                      shl cx,3         ;RPL=0,TI=0:在GDT表中

                      pop es
                      pop ds

                      pop edx
                      pop ebx
                      pop eax

                      retf




;构造门描述符(调用门等)
;输入：EAX=门代码在段内偏移地址
;BX=门代码所在段的选择子
;CX=段类型及属性
;返回：EDX:EAX=完整的描述符
make_gate_descriptor:
                     push ebx
                     push ecx

                     mov edx,eax
                     and edx,0xffff0000
                     or dx,cx

                     and eax,0x0000ffff
                     shl ebx,16
                     or eax,ebx

                     pop ecx
                     pop ebx

                     retf


sys_routine_end:


SECTION core_data vstart=0

        pgdt dw 0              ;用于设置和修改GDT
             dd 0

        ram_alloc dd 0x00100000  ;下次分配内存的起始地址


        ;符号地址检索表
        salt:
        salt_1         db '@PrintString'
                       times 256-($-salt_1) db 0
                       dd put_string
                       dw sys_routine_seg_sel
                       db 0

        salt_2         db '@ReadDiskData'
                       times 256-($-salt_2) db 0
                       dd read_hard_disk_0
                       dw sys_routine_seg_sel
                       db 3

        salt_3         db '@PrintDwordAsHexString'
                       times 256-($-salt_3) db 0
                       dd put_hex_dword
                       dw sys_routine_seg_sel
                       db 0

        salt_4         db '@TerminateProgram'
                       times 256-($-salt_4) db 0
                       dd return_point
                       dw core_code_seg_sel
                       db 0

        salt_item_len  equ $-salt_4
        salt_items     equ ($-salt)/salt_item_len

        message_1        db  '  If you seen this message,that means we '
                          db  'are now in protect mode,and the system '
                          db  'core is loaded,and the video display '
                          db  'routine works perfectly.',0x0d,0x0a,0

        message_2        db  '  System wide CALL-GATE mounted.',0x0d,0x0a,0

        message_3        db  0x0d,0x0a,'  Loading user program...',0

        do_status db 'Done.',0x0d,0x0a,0

        message_6 db 0x0d,0x0a,0x0d,0x0a,0x0d,0x0a
                   db ' User program terminated,control returned.',0

        esp_pointer dd 0

        bin_hex db '0123456789ABCDEF'

        core_buf times 2048 db 0     ;内核用的缓冲区


        cpu_brnd0 db 0x0d,0x0a,' ',0
        cpu_brand times 52 db 0
        cpu_brnd1 db 0x0d,0x0a,0x0d,0x0a,0

        tcb_chain dd 0

core_data_end:

SECTION core_code vstart=0

;在LDT内装配一个新的描述符
;输入：EDX:EAX=描述符    EBX=TCB基地址
;输出：CX=描述符的选择子
fill_descriptor_in_ldt:
                       push eax
                       push edx
                       push edi
                       push ds

                       mov ecx,mem_0_4_gb_seg_sel
                       mov ds,ecx

                       mov edi,[ebx+0x0c]      ;获得LDT基地址

                       xor ecx,ecx
                       mov cx,[ebx+0x0a]       ;获得LDT界限
                       inc cx

                       mov [edi+ecx+0x00],eax
                       mov [edi+ecx+0x04],edx   ;安装描述符

                       add cx,8
                       dec cx              ;得到新的LDT界限

                       mov [ebx+0x0a],cx   ;更新LDT界限值

                       mov ax,cx
                       xor dx,dx
                       mov cx,8
                       div cx

                       mov cx,ax
                       shl cx,3                          ;左移3位
                       or cx,0000_0000_0000_0100B  ;使TI位=1，指向LDT，RPL=00

                       pop ds
                       pop edi
                       pop edx
                       pop eax

                       ret



;加载并重定位用户程序
;输入 PUSH逻辑扇区号  PUSH任务控制块基地址
;输出：无
load_relocate_program:
                      pushad

                      push ds
                      push es

                      mov ebp,esp  ;为了访问通过堆栈传递参数做准备

                      mov ecx,mem_0_4_gb_seg_sel
                      mov es,ecx

                      mov esi,[ebp+11*4]   ;从堆栈中取得TCB基地址


                      ;以下申请创建LDT所需要的内存
                      mov ecx,160      ;准许安装20个LDT描述符
                      call sys_routine_seg_sel:allocate_memory
                      mov [es:esi+0x0c],ecx       ;登记LDT基地址到TCB中
                      mov word [es:esi+0x0a],0xffff  ;登记LDT初始界限到TCB中


                      ;以下开始加载用户程序
                      mov eax,core_data_seg_sel
                      mov ds,eax

                      mov eax,[ebp+12*4]  ;从堆栈中取出用户程序的起始扇区号
                      mov ebx,core_buf    ;读取程序头部数据
                      push eax
                      push ds
                      push ebx
                      call sys_routine_seg_sel:read_hard_disk_0

                      ;以下判断程序大小
                      mov eax,[core_buf]       ;程序尺寸

                      mov ebx,eax
                      and ebx,0xfffffe00       ;512字节对齐
                      add ebx,512
                      test eax,0x000001ff
                      cmovnz eax,ebx

                      mov ecx,eax            ;实际需要申请的内存数量
                      call sys_routine_seg_sel:allocate_memory
                      mov [es:esi+0x06],ecx     ;登记程序加载基地址到TCB中

                      mov ebx,ecx        ;ebx 申请到的内存首地址
                      xor edx,edx
                      mov ecx,512
                      div ecx
                      mov ecx,eax       ;总扇区数


                      mov eax,mem_0_4_gb_seg_sel
                      mov ds,eax


                      mov eax,[ebp+12*4]   ;起始扇区数
.b1:
                      push eax
                      push ds
                      push ebx
                      call sys_routine_seg_sel:read_hard_disk_0

                      add ebx,0x200


                      inc eax
                      loop .b1

                      mov edi,[es:esi+0x06]    ;获得程序加载基地址

                      ;建立程序头部段描述符
                      mov eax,edi               ;程序头部起始线性地址
                      mov ebx,[edi+0x04]        ;段长度
                      dec ebx                   ;段界限
                      mov ecx,0x0040f200        ;字节粒度的数据段描述符，特权级为3
                      call sys_routine_seg_sel:make_seg_descriptor

                      ;安装头部段描述符到LDT中
                      mov ebx,esi                  ;TCB的基地址
                      call fill_descriptor_in_ldt

                      or cx,0000_0000_0000_0011B  ;设置选择子的特权级为3
                      mov [es:esi+0x44],cx      ;登记程序头部段选择子到TCB
                      mov [edi+0x04],cx         ;登记程序头部段选择子到头部内

                      ;建立程序代码段描述符
                      mov eax,edi           ;程序头部起始线性地址
                      add eax,[edi+0x14]    ;代码段起始线性地址
                      mov ebx,[edi+0x18]    ;段长度
                      dec ebx               ;段界限
                      mov ecx,0x0040f800    ;字节粒度的代码段描述符，特权级为3
                      call sys_routine_seg_sel:make_seg_descriptor
                      mov ebx,esi            ;TCB基地址
                      call fill_descriptor_in_ldt
                      or cx,0000_0000_0000_0011B  ;设置选择子的特权级为3
                      mov [edi+0x14],cx   ;登记代码段选择子到程序头部内

                      ;建立程序数据段描述符
                      mov eax,edi
                      add eax,[edi+0x1c]  ;数据段起始线性地址
                      mov ebx,[edi+0x20]  ;段长度
                      dec ebx             ;段界限
                      mov ecx,0x0040f200  ;字节粒度的数据段描述符，特权级为3
                      call sys_routine_seg_sel:make_seg_descriptor
                      mov ebx,esi         ;TCB的基地址
                      call fill_descriptor_in_ldt
                      or cx,0000_0000_0000_0011B    ;设置选择子的特权级为3
                      mov [edi+0x1c],cx

                      ;建立程序堆栈段描述符
                      mov ecx,[edi+0x0c]
                      mov ebx,0x000fffff
                      sub ebx,ecx         ;段界限
                      mov eax,4096
                      mul ecx
                      mov ecx,eax
                      call sys_routine_seg_sel:allocate_memory
                      add eax,ecx    ;得到栈的高端地址
                      mov ecx,0x00c0f600
                      call sys_routine_seg_sel:make_seg_descriptor
                      mov ebx,esi
                      call fill_descriptor_in_ldt
                      or cx,0000_0000_0000_0011B
                      mov [edi+0x08],cx

                      ;重定位SALT
                      mov eax,mem_0_4_gb_seg_sel
                      mov es,eax

                      mov eax,core_data_seg_sel
                      mov ds,eax

                      cld

                      mov ecx,[es:edi+0x24]   ;用户程序SALT条目数
                      add edi,0x28            ;用户SALT在4GB段内的偏移

.b2:
                      push ecx
                      push edi

                      mov ecx,salt_items
                      mov esi,salt
.b3:
                      push edi
                      push esi
                      push ecx

                      mov ecx,64
                      repe cmpsd
                      jnz .b4
                      mov eax,[esi]
                      mov [es:edi-256],eax ;将用户程序SALT字符串改成偏移地址
                      mov ax,[esi+4]
                      or ax,0000000000000011B
                      mov [es:edi-252],ax    ;回填用户门选择子

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

                      mov esi,[ebp+11*4]  ;从堆栈中取得TCB的基地址

                      ;创建0特权级堆栈
                      mov ecx,4096
                      mov eax,ecx   ;为生成堆栈的高端地址做准备
                      mov [es:esi+0x1a],ecx
                      shr dword [es:esi+0x1a],12  ;登记0特权级堆栈尺寸到TCB
                      call sys_routine_seg_sel:allocate_memory
                      add eax,ecx         ;堆栈使用高端地址做基地址
                      mov [es:esi+0x1e],eax  ;登记0特权级堆栈基地址到TCB
                      mov ebx,0xffffe       ;段长度（界限）
                      mov ecx,0x00c09600    ;4KB粒度，读写，特权级为0
                      call sys_routine_seg_sel:make_seg_descriptor
                      mov ebx,esi    ;TCB的基地址
                      call fill_descriptor_in_ldt
                      ;or cx,0000_0000_0000_0000B
                      mov [es:esi+0x22],cx  ;登记0特权级堆栈选择子到TCB
                      mov dword [es:esi+0x24],0 ;登记0特权级堆栈初始ESP到TCB

                      ;创建1特权级堆栈
                      mov ecx,4096
                      mov eax,ecx
                      mov [es:esi+0x28],ecx
                      shr [es:esi+0x28],12      ;登记1特权级堆栈尺寸到TCB
                      call sys_routine_seg_sel:allocate_memory
                      add eax,ecx           ;堆栈必须使用高端地址为基地址
                      mov [es:esi+0x2c],eax  ;登记1特权级的堆栈基地址到TCB
                      mov ebx,0xffffe       ;段长度（段界限）
                      mov ecx,0x00c0b600     ;4KB粒度，读写，特权级为1
                      call sys_routine_seg_sel:make_seg_descriptor
                      mov ebx,esi           ;TCB的基地址
                      call fill_descriptor_in_ldt
                      or cx,0000_0000_0000_0001   ;设置选择子的特权级为1
                      mov [es:esi+0x30],cx      ;登记1特权级堆栈选择子到TCB
                      mov dword [es:esi+0x32],0  ;登记1特权级堆栈初始ESP到TCB

                      ;创建2特权级堆栈
                      mov ecx,4096
                      mov eax,ecx
                      mov [es:esi+0x36],ecx
                      shr [es:esi+0x36],12
                      call sys_routine_seg_sel:allocate_memory
                      add eax,ecx
                      mov [es:esi+0x3a],eax
                      mov ebx,0xffffe
                      mov ecx,0x00c0d600
                      call sys_routine_seg_sel:make_seg_descriptor
                      mov ebx,esi
                      call fill_descriptor_in_ldt
                      or cx,0000_0000_0000_0010
                      mov [es:esi+0x3e],cx
                      mov dword[es:esi+0x40],0

                      ;在GDT中登记LDT描述符
                      mov eax,[es:esi+0x0c]        ;LDT起始线性地址
                      movzx ebx,word[es:esi+0x0a]   ;LDT段界限
                      mov ecx,0x00408200           ;LDT描述符，特权级0
                      call sys_routine_seg_sel:make_seg_descriptor
                      call sys_routine_seg_sel:set_up_gdt_descriptor
                      mov [es:esi+0x10],cx        ;登记LDT选择子到TCB中

                      ;创建用户程序的TSS
                      mov ecx,104           ;TSS基本尺寸
                      mov [es:esi+0x12],cx
                      dec word [es:esi+0x12]   ;登记TSS界限值到TCB
                      call sys_routine_seg_sel:allocate_memory
                      mov [es:esi+0x14],ecx     ;登记TSS基地址到TCB

                      ;登记基本的TSS表格内容
                      mov word [es:ecx+0],0     ;反向链=0

                      mov edx,[es:esi+0x24]     ;登记0特权级堆栈初始ESP到TSS
                      mov [es:ecx+4],edx

                      mov dx,[es:esi+0x22]      ;登记0特权级堆栈选择子到TSS
                      mov [es:ecx+8],dx

                      mov edx,[es:esi+0x32]     ;登记1特权级堆栈初始ESP到TSS
                      mov [es:ecx+12],edx

                      mov dx,[es:esi+0x30]
                      mov [es:ecx+16],dx        ;登记1特权级堆栈选择子到TSS

                      mov edx,[es:esi+0x40]     ;登记2特权级堆栈初始ESP到TSS
                      mov [es:ecx+20],edx

                      mov dx,[es:esi+0x3e]      ;登记2特权级堆栈选择子到TSS
                      mov [es:ecx+24],dx

                      mov dx,[es:esi+0x10]      ;登记任务LDT选择子到TSS
                      mov [es:ecx+96],dx

                      mov dx,[es:esi+0x12]      ;登记任务I/O位图偏移到TSS
                      mov [es:ecx+102],dx

                      mov word [es:ecx+100],0         ;T=0

                      ;在GDT中登记TSS描述符
                      mov eax,[es:esi+0x14]      ;TSS的起始线性地址
                      movzx ebx,word[es:esi+0x12]    ;段界限（段长度）
                      mov ecx,0x00408900          ;TSS描述符特权级为0
                      call sys_routine_seg_sel:make_seg_descriptor
                      call sys_routine_seg_sel:set_up_gdt_descriptor
                      mov [es:esi+0x18],cx      ;登记TSS选择子到TCB中

                      pop es
                      pop ds

                      popad

                      ret 8



;在TCB链上追加任务控制块
;输入：ECX=TCB线性基地址
append_to_tcb_link:
                   push eax
                   push edx
                   push ds
                   push es

                   mov eax,core_data_seg_sel
                   mov ds,eax                 ;ds指向内核数据段 DPL=0
                   mov eax,mem_0_4_gb_seg_sel
                   mov es,eax                 ;es指向0~4GB DPL=0

                   mov dword [es:ecx+0x00],0  ;当前TCB指针指针域清零
                                              ;以指示这是最后一个指针

                   mov eax,[tcb_chain]        ;TCB表头指针
                   or eax,eax
                   jz .notcb                  ;链表为空

.searc:
                   mov edx,eax
                   mov eax,[es:edx+0x00]
                   or eax,eax
                   jnz .searc

                   mov [es:edx+0x00],ecx
                   jmp .retpc

.notcb:
                   mov [tcb_chain],ecx        ;若为空表，直接令表头指针指向TCB

.retpc:
                   pop es
                   pop ds
                   pop edx
                   pop eax

                   ret



start:
      mov ecx,core_data_seg_sel ;使ds指向核心数据段
      mov ds,ecx

      mov ebx,message_1
      call sys_routine_seg_sel:put_string

      mov eax,0x80000002
      cpuid
      mov [cpu_brand+0x00],eax
      mov [cpu_brand+0x04],ebx
      mov [cpu_brand+0x08],ecx
      mov [cpu_brand+0x0c],edx

      mov eax,0x80000003
      cpuid
      mov [cpu_brand + 0x10],eax
      mov [cpu_brand + 0x14],ebx
      mov [cpu_brand + 0x18],ecx
      mov [cpu_brand + 0x1c],edx

      mov eax,0x80000004
      cpuid
      mov [cpu_brand + 0x20],eax
      mov [cpu_brand + 0x24],ebx
      mov [cpu_brand + 0x28],ecx
      mov [cpu_brand + 0x2c],edx

      mov ebx,cpu_brnd0 ;显示处理器品牌信息
      call sys_routine_seg_sel:put_string
      mov ebx,cpu_brand
      call sys_routine_seg_sel:put_string
      mov ebx,cpu_brnd1
      call sys_routine_seg_sel:put_string


      mov edi,salt              ;内核符号地址检索表起始位置
      mov ecx,salt_items        ;内核符号地址检索表条目数

.b3:
      push ecx
      mov eax,[edi+256]         ;该条目入口点的32位偏移地址
      mov bx,[edi+260]          ;该条目入口点的段选择子
      mov cx,1_11_0_1100_000_00000B   ;DPL=3的调用门描述符

      or cl,[edi+262]
      call sys_routine_seg_sel:make_gate_descriptor
      call sys_routine_seg_sel:set_up_gdt_descriptor
      mov [edi+260],cx  ;将返回的门描述符选择子回填到C-SALT表中
      add edi,salt_item_len
      pop ecx
      loop .b3

      ;对门进行测试
      mov ebx,message_2
      call far [salt_1+256]      ;偏移量将被被忽略

      mov ebx,message_3
      call sys_routine_seg_sel:put_string  ;在内核中调用例程不需要通过门

      ;创建任务控制块，这不是处理器的要求
      mov ecx,0x46
      call sys_routine_seg_sel:allocate_memory
      call append_to_tcb_link         ;将任务块追加到TCB链表

      push dword 50         ;用户程序起始逻辑扇区
      push ecx              ;TCB起始线性地址

      call load_relocate_program

      mov ebx,do_status
      call sys_routine_seg_sel:put_string

      mov eax,mem_0_4_gb_seg_sel
      mov ds,eax

      ltr [ecx+0x18]         ;加载TSS
      lldt [ecx+0x10]        ;加载LDT

      mov eax,[ecx+0x44]
      mov ds,eax             ;切换到用户程序头部

      push dword [0x08]      ;调用前堆栈段选择子
      push dword 0            ;调用前堆栈段初始ESP

      push dword [0x14]      ; 调用前用户程序代码段选择子
      push dword [0x10]       ;偏移地址

      retf

return_point:
             mov eax,core_data_seg_sel
             mov ds,eax

             mov ebx,message_6
             call sys_routine_seg_sel:put_string

             hlt

core_code_end:


SECTION core_trail
core_end:





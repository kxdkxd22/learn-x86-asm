SECTION header vstart=0

        program_length dd program_end    ;程序的总长度0x00

        head_len dd header_end           ;程序头部的长度 0x04

        stack_seg  dd 0;section.stack.start               ;用于接收堆栈段选择子0x08
        stack_len  dd 1;(stack_end-stack_start)/(4*1024)  ;程序建议的堆栈大小，4KB为单位

        prgentry   dd start          ;程序入口0x10
        code_seg   dd section.code.start   ;代码段位置0x14
        code_len   dd code_end          ;代码段长度0x18

        data_seg   dd section.data.start    ;数据段位置0x1c
        data_len   dd data_end              ;数据段长度0x20

        ;符号地址检索表
        salt_items dd (header_end-salt)/256   ;0x24

        salt:
             PrintString   db '@PrintString'
                           times 256-($-PrintString) db 0

             TerminateProgram db '@TerminateProgram'
                              times 256-($-TerminateProgram) db 0

             ReadDiskData  db '@ReadDiskData'
                           times 256-($-ReadDiskData) db 0

header_end:

;SECTION stack vstart=0
;stack_start:
;            times 4096 db 0
;stack_end:

SECTION data vstart=0
        buffer times 1024 db 0

        message_1  db 0x0d,0x0a,0x0d,0x0a
                   db '*******User program is running********'
                   db 0x0d,0x0a,0
        message_2  db '    Disk data:',0x0d,0x0a,0

data_end:

         [bits 32]

SECTION code vstart=0
start:
      mov eax,ds
      mov fs,eax

      mov eax,[stack_seg]
      mov ss,eax
      mov esp,0

      mov eax,[data_seg]
      mov ds,eax

      mov ebx,message_1
      call far [fs:PrintString]

      mov eax,100
      ;mov ebx,buffer
      push eax
      push ds
      push buffer
      call far [fs:ReadDiskData]

      mov ebx,message_2
      call far [fs:PrintString]

      mov ebx,buffer
      call far [fs:PrintString]

      call far [fs:TerminateProgram]

code_end:

SECTION trail
program_end:

;SECTION stack vstart=0
;stack_start:
;          times 4096 db 0
;stack_end:

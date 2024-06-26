format PE native 0.05
entry START
use32
        DEBUG                   = 1
        __DEBUG__               = 1
        __DEBUG_LEVEL__         = 1  ; 1 = verbose, 2 = errors only
section '.flat' code readable writable executable
include 'drivers/proc32.inc'
include 'drivers/struct.inc'
include 'drivers/macros.inc'
include 'drivers/peimport.inc'
include 'drivers/fdo.inc'
struct IMPORT_SDIO_FUNC
        reg_sdio      rd 1
        unreg_sdio    rd 1
        scan_dev      rd 1
        cmd52         rd 1
        cmd53         rd 1
ends
proc START c, state:dword, cmdline:dword
        push    esi ebx
        cmp     [state], DRV_ENTRY
        jne     .stop_drv
        DEBUGF  1,"SDIO-TEST: Loading driver\n"
        invoke  GetService, sdhci_str
        DEBUGF  1,"SDIO-TEST: Get service %x\n", eax
        test    eax, eax
        jz      .err
        mov     [sdhci_handle], eax ; get import sdio func
        invoke  ServiceHandler, ioctl_get_export
        test    eax, eax
        jnz     .err
        DEBUGF  1,"SDIO-TEST: import table %x\n", [ptr_import_table]
        mov     eax, [ptr_import_table]  ; reg sdio
        stdcall [eax + IMPORT_SDIO_FUNC.reg_sdio], drv_table_func
        DEBUGF  1,"SDIO-TEST: Reg sdio %x\n", eax
        test    eax, eax
        jz      .err
        mov     [sdio_hand], eax
        invoke  RegService, drv_name, 0  ; reg driver
        pop     ebx esi
        ret
.stop_drv:
.err:
        pop     ebx esi
        xor     eax, eax
        ret
endp
proc    check_dev stdcall ptr_slot: dword
        push    esi ebx edi
        DEBUGF  1,"SDIO-TEST: Check SDIO dev\n"
        mov     esi, [ptr_slot]
        mov     edi, [ptr_import_table]
        mov     ecx, 0
        call    [edi + IMPORT_SDIO_FUNC.cmd52]
        mov     ecx, eax
        shr     al, 4
        and     cl, 0xfF
        and     al, 0xff
        DEBUGF  1,"SDIO-TEST: SDIO ver= %d CCCR ver = %d\n", al, cl
        mov     ecx, (0x100 shl 9)
        call    [edi + IMPORT_SDIO_FUNC.cmd52]
        and     al, 0xff
        DEBUGF  1,"SDIO-TEST: FBR interface code= %d\n", al
        mov     ecx, (0x109 shl 9)
        call    [edi + IMPORT_SDIO_FUNC.cmd52]
        and     al, 0xff
        DEBUGF  1,"SDIO-TEST: 0x109: %d\n", al
        mov     ecx, (0x10a shl 9)
        call    [edi + IMPORT_SDIO_FUNC.cmd52]
        and     al, 0xff
        DEBUGF  1,"SDIO-TEST: 0x10a: %d\n", al
        mov     ecx, (0x10b shl 9)
        call    [edi + IMPORT_SDIO_FUNC.cmd52]
        and     al, 0xff
        DEBUGF  1,"SDIO-TEST: 0x10b: %d\n", al

        pop     edi ebx esi
        mov     eax,[ptr_slot]
        ret
endp
proc    int_handle stdcall pdata: dword
        ret
endp
proc    close_dev stdcall pdata: dword
        DEBUGF  1,"SDIO-TEST: Close sdio device\n"
        ret
endp

ioctl_get_export:
sdhci_handle: dd 0
              dd 3
              dd 0
              dd 0
              dd ptr_import_table
              dd 4
ptr_import_table:       dd 0
sdio_hand:              dd 0
PDATA_STRUCT:           dd 0
drv_table_func:
        dd check_dev
        dd int_handle
        dd close_dev
sdhci_str:      db 'SDHCI',0
drv_name:       db 'SDIO-TEST',0

align 4
data fixups
end data
include_debug_strings
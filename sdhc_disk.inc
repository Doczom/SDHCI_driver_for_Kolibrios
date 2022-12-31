; Functions for this driver

proc add_card_disk

        ret
endp
proc del_card_disk

        ret
endp

; Functions for kernel

proc    sdhci_read stdcall pdata: dword, buffer: dword, startsector: qword, numsectors_ptr:dword
        mov     esi, [pdata]
        mov     eax, [esi + SDHCI_CONTROLLER.base_reg_map]

        ret
endp
proc    sdhci_write stdcall pdata: dword, buffer: dword, startsector: qword, numsectors_ptr:dword
        mov     esi, [pdata]
        mov     eax, [esi + SDHCI_CONTROLLER.base_reg_map]

        ;call    [write_functions + ]

        ret
endp

; чтоб можно было DMA режим менять на лету
read_functions:
        dd      0 ; no dma
        dd      0 ; sdma
        dd      0 ; adma1
        dd      adma2_read_sectors ; adma2
write_functions:
        dd      0 ; no dma
        dd      0 ; sdma
        dd      0 ; adma1
        dd      adma2_write_sectors ; adma2


align 4
sdhci_callbacks:
    dd  sdhci_callbacks.end - sdhci_callbacks
    dd  0   ; no close function
    dd  0   ; no closemedia function
    dd  0;ahci_querymedia
    dd  sdhci_read
    dd  sdhci_write
    dd  0   ; no flush function
    dd  0   ; use default cache size
.end:

sdcard_disk_name:       db 'sdcard00',0
mmccard_disk_name:      db 'MMCcard00',0
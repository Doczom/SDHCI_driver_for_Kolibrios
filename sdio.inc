;;      Copyright (C) 2022, Michael Frolov(aka Doczom)
;; SDIO subsystem SDHCI driver. Base functons for working.


;   Список внешних SDIO модулей ядра
sdio_drv_list:
        dd sdio_drv_list
        dd sdio_drv_list


struct  SDIO_SERVICE
        next            rd 1
        prev            rd 1
        sdio_func       rd 1 ;ptr
ends


struct  SDIO_SERVICE_FUNC
        check_fbr       rd 1
        ; stdcall void* check_fbr(SDHCI_SLOT* slot_str)
        ; Called for find driver to this card. Function rerturning
        ; DWORD or zero. Return value - pdata for calling func
        int_handler     rd 1
        ; stdcall int int_handler(void* pdata)
        ; This function calling in sdhc_irq() when geting
        ; card interrupt
        close_card      rd 1
        ; stdcall int close_card(void* pdata)
        ; Calling when card removed.
ends


export_sdio_api:
        dd      REG_SDIO_SERVICE
        dd      UNREG_SDIO_SERVICE
        dd      SCAN_SDIO_DEV
        dd      IO_RW_DIRECT   ;cmd52
        dd      IO_RW_EXTENDED ; cmd53


proc    REG_SDIO_SERVICE stdcall sdio_func: dword
        ; alloc new item list
        mov     eax, sizeof.SDIO_SERVICE
        invoke  Kmalloc
        test    eax, eax
        jz      .exit

        mov     ecx, [sdio_func]
        mov     [eax + SDIO_SERVICE.sdio_func], ecx
        cli

        mov     ecx, [sdio_drv_list]
        mov     [eax], ecx
        mov     [eax + SDIO_SERVICE.prev], sdio_drv_list
        mov     [ecx + SDIO_SERVICE.prev], eax
        mov     [sdio_drv_list], eax
        sti
.exit:
        ret
endp

proc    UNREG_SDIO_SERVICE stdcall sdio_hand: dword

        ; del in list
        mov     eax, [sdio_hand]
        mov     edx, [eax]
        mov     ecx, [eax + SDIO_SERVICE.prev]
        mov     [edx + SDIO_SERVICE.prev], ecx
        mov     [ecx], edx

        ; find all slots, using this service

        ; free struct
        mov     eax, [sdio_hand]
        invoke  Kfree
        ret
endp

proc    SCAN_SDIO_DEV stdcall sdio_hand: dword


        ret
endp
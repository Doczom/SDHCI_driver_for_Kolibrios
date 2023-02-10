; Functions for this driver

;„тобы не ставить парные push/pop при входе и выходе из функции, можно писать так:
;proc GET_SDSC_SIZE uses ecx edx
;proc GET_SDSC_SIZE uses ecx edx, _param1, _param2

proc    GET_SDSC_SIZE
        ;  memory capacity = BLOCKNR * BLOCK_LEN   ; shl BSF block_len
        ;  BLOCKNR = (C_SIZE + 1) * MULT           ; shl ecx, BSF (C_SIZE_MULT + 2)
        ;  MULT = 2^(C_SIZE_MULT + 2)
        ;  BLOCK_LEN = 2^LEN_BL_READ
        push    ecx edx
        mov     ecx, dword[esi + SDHCI_CONTROLLER.card_reg_csd + 4] ; C_SIZE_MULT
        shr     ecx, 7; 39 - 32 = 7
        and     ecx, 111b
        add     ecx, 2

        mov     edx, dword[esi + SDHCI_CONTROLLER.card_reg_csd + 6] ; C_SIZE    48/8
        shr     edx, 6 ; 48 + 6
        and     edx, 0xFFF ; data in 12 low bits
        inc     edx
        shl     edx, cl

        movzx   ecx, byte[esi + SDHCI_CONTROLLER.card_reg_csd + 9] ; LEN_BL_READ  72/8
        and     ecx, 0x0f
        shl     edx, cl
        ; get sectors = edx / 512 <- sectorsize for kernel
        shr     edx, BSF 512
        mov     dword[esi + SDHCI_CONTROLLER.sector_count], edx
        mov     dword[esi + SDHCI_CONTROLLER.sector_count + 4], 0
        pop     edx ecx
        ret
endp

proc    GET_SDHC_SIZE
        ; 22 bit  [40:61]
        ; ((C_SIZE + 1) * 512Kbyte ) / sectorsize
        push    ebx
        mov     ebx, dword[esi + SDHCI_CONTROLLER.card_reg_csd + 5]
        and     ebx, not 0xFFC00000  ; обнул€ем старшие биты
        mov     dword[esi + SDHCI_CONTROLLER.sector_count + 4], 0
        inc     edx ; C_SIZE + 1
        shl     ebx, 10 ; *512Kbyte / sectorsize(512)
        mov     dword[esi + SDHCI_CONTROLLER.sector_count], ebx
        ;bt      dword[esi + SDHCI_CONTROLLER.card_reg_csd + 4], 29 ; read 22 bit C_SIZE
        adc     dword[esi + SDHCI_CONTROLLER.sector_count + 4], 0
        pop     ebx
        ret
endp

proc    GET_SDUC_SIZE
        ; 28 bit   [40:67]  40bit=5*8bit
        ; ((C_SIZE + 1) * 512Kbyte ) / sectorsize
        push    ebx
        mov     ebx, dword[esi + SDHCI_CONTROLLER.card_reg_csd + 5]
        and     ebx, not 0xC0000000  ; обнул€ем старшие биты
        inc     edx
        mov     dword[esi + SDHCI_CONTROLLER.sector_count], ebx
        shr     ebx, 31-10 ; get hign LBA addr
        mov     dword[esi + SDHCI_CONTROLLER.card_reg_csd + 4], ebx
        shl     dword[esi + SDHCI_CONTROLLER.sector_count], 10
        pop     ebx
        ret
endp

proc    GET_MMC_SIZE
        ; тут жуть, в ж*пу

        ret
endp


proc add_card_disk stdcall, hd_name:dword

        invoke  DiskAdd, sdhci_callbacks, [hd_name], esi, 0
        test    eax, eax
        jz      .disk_add_fail

        invoke  DiskMediaChanged, eax, 1 ; system will scan for partitions on disk

        ret

.disk_add_fail:
        DEBUGF  1, "Failed to add disk\n"
        ret
endp
proc del_card_disk

        ret
endp

; Functions for kernel
; ѕо€снение к реализации чтени€/записи секторов:
;   Ётот драйвер должен обрабатывать SD карты разных версий,
; SDIO карты(в том числе и совмещЄнные) и MMC(eMMC) карты.
;   ¬о всех вариантах карт чтение и запись происходить при помощи
; одних и тех же команд(17,18,24,25), при чЄм последовательность
; остальных команд также схожа.
;   ѕо этому различатьс€ будут только методы работы с контроллером,
; это либо использование SDMA или ADMA2 или, если этого нет, то
; работа через порт буфера
proc    sdhci_read stdcall pdata: dword, buffer: dword, startsector: qword, numsectors_ptr:dword
        mov     esi, [pdata]
        mov     eax, [esi + SDHCI_CONTROLLER.base_reg_map]

        cmp     dword[numsectors_ptr], 1
        ja      .multiple

        ; get phys addr
        mov     eax, [buffer]
        invoke  GetPhysAddr


        ; send CMD 17

        ret
.multiple:
        ; get phys addr table

        ; send CMD 18

        ; send CMD 12

        ret
endp
proc    sdhci_write stdcall pdata: dword, buffer: dword, startsector: qword, numsectors_ptr:dword
        mov     esi, [pdata]
        mov     eax, [esi + SDHCI_CONTROLLER.base_reg_map]

        cmp     dword[numsectors_ptr], 1
        ja      .multiple

        ; get phys addr
        mov     eax, [buffer]
        invoke  GetPhysAddr

        ; send CMD 24

        ret
.multiple:
        ; get phys addr table

        ; send CMD 25

        ; send CMD 12

        ret
endp

struct DISKMEDIAINFO
        Flags      dd ?
        SectorSize dd ?
        Capacity   dq ?
ends

proc   sdhci_querymedia stdcall, pdata, mediainfo
        push    ecx edx
        mov     eax, [mediainfo]
        mov     edx, [pdata]
        mov     [eax + DISKMEDIAINFO.Flags], 0
        mov     [eax + DISKMEDIAINFO.SectorSize], 512
        mov     ecx, dword[edx + SDHCI_CONTROLLER.sector_count]
        mov     dword [eax + DISKMEDIAINFO.Capacity], ecx
        mov     ecx, dword[edx + SDHCI_CONTROLLER.sector_count + 4]
        mov     dword [eax + DISKMEDIAINFO.Capacity + 4], ecx
        pop     edx ecx
        xor     eax, eax
        ret
endp

; UPD: ¬се эти режимы передачи данных не пересекаютс€ и их можно разместить в одной функции
; в обработке регистра int_status
; чтоб можно было DMA режим мен€ть на лету
;read_functions:
;        dd      0 ; no dma
;        dd      0 ; sdma
;        dd      0 ; adma1
;        dd      0 ;adma2_read_sectors ; adma2
;write_functions:
;        dd      0 ; no dma
;        dd      0 ; sdma
;        dd      0 ; adma1
;        dd      0 ;adma2_write_sectors ; adma2
;

align 4
sdhci_callbacks:
    dd  sdhci_callbacks.end - sdhci_callbacks
    dd  0   ; no close function
    dd  0   ; no closemedia function
    dd  sdhci_querymedia  ; +
    dd  sdhci_read    ; -
    dd  sdhci_write   ; -
    dd  0   ; no flush function
    dd  0   ; use default cache size
.end:

sdcard_disk_name:       db 'sdcard00',0
mmccard_disk_name:      db 'MMC00',0
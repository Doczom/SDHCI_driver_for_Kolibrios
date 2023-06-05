; Functions for this driver

;Чтобы не ставить парные push/pop при входе и выходе из функции, можно писать так:
;proc GET_SDSC_SIZE uses ecx edx
;proc GET_SDSC_SIZE uses ecx edx, _param1, _param2

proc    GET_SDSC_SIZE
        ;  memory capacity = BLOCKNR * BLOCK_LEN   ; shl BSF block_len
        ;  BLOCKNR = (C_SIZE + 1) * MULT           ; shl ecx, BSF (C_SIZE_MULT + 2)
        ;  MULT = 2^(C_SIZE_MULT + 2)
        ;  BLOCK_LEN = 2^LEN_BL_READ
        push    ecx edx
        mov     ecx, dword[esi + SDHCI_SLOT.card_reg_csd + 4] ; C_SIZE_MULT
        shr     ecx, 7; 39 - 32 = 7
        and     ecx, 111b
        add     ecx, 2

        mov     edx, dword[esi + SDHCI_SLOT.card_reg_csd + 6] ; C_SIZE    48/8
        shr     edx, 6 ; 48 + 6
        and     edx, 0xFFF ; data in 12 low bits
        inc     edx
        shl     edx, cl

        movzx   ecx, byte[esi + SDHCI_SLOT.card_reg_csd + 9] ; LEN_BL_READ  72/8
        and     ecx, 0x0f
        shl     edx, cl
        ; get sectors = edx / 512 <- sectorsize for kernel
        shr     edx, BSF 512
        mov     dword[esi + SDHCI_SLOT.sector_count], edx
        mov     dword[esi + SDHCI_SLOT.sector_count + 4], 0
        pop     edx ecx
        ret
endp

proc    GET_SDHC_SIZE
        ; 22 bit  [40:61]
        ; ((C_SIZE + 1) * 512Kbyte ) / sectorsize
        push    ebx
        mov     ebx, dword[esi + SDHCI_SLOT.card_reg_csd + 5]
        and     ebx, not 0xFFC00000  ; обнуляем старшие биты
        mov     dword[esi + SDHCI_SLOT.sector_count + 4], 0
        inc     edx ; C_SIZE + 1
        shl     ebx, 10 ; *512Kbyte / sectorsize(512)
        mov     dword[esi + SDHCI_SLOT.sector_count], ebx
        ;bt      dword[esi + SDHCI_CONTROLLER.card_reg_csd + 4], 29 ; read 22 bit C_SIZE
        adc     dword[esi + SDHCI_SLOT.sector_count + 4], 0
        pop     ebx
        ret
endp

proc    GET_SDUC_SIZE
        ; 28 bit   [40:67]  40bit=5*8bit
        ; ((C_SIZE + 1) * 512Kbyte ) / sectorsize
        push    ebx
        mov     ebx, dword[esi + SDHCI_SLOT.card_reg_csd + 5]
        and     ebx, not 0xC0000000  ; обнуляем старшие биты
        inc     edx
        mov     dword[esi + SDHCI_SLOT.sector_count], ebx
        shr     ebx, 31-10 ; get hign LBA addr
        mov     dword[esi + SDHCI_SLOT.card_reg_csd + 4], ebx
        shl     dword[esi + SDHCI_SLOT.sector_count], 10
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
        mov     dword[esi + SDHCI_SLOT.disk_hand], eax
        invoke  DiskMediaChanged, eax, 1 ; system will scan for partitions on disk
        ret
.disk_add_fail:
        DEBUGF  1, "Failed to add disk\n"
        ret
endp


; Functions for kernel
proc    sdhci_read stdcall pdata: dword, buffer: dword, startsector: qword, numsectors_ptr:dword
        pusha

        mov     esi, [pdata]
        mov     eax, [esi + SDHCI_SLOT.base_reg_map]
        mov     ebx, dword[startsector]
        mov     edx, [numsectors_ptr]
        mov     edx, [edx]
        mov     edi, [buffer]
        ;DEBUGF  1,"SDHCI: read sector=%x num=%x \n", ebx, edx
        cmp     edx, 1
        ja      .multiple

        call    READ_SIGLE_BLOCK

        popa
        mov     eax, 0
        ret
.multiple:
        push    edx ebx edi
@@:
        mov     edx, dword[esp + 8]
        mov     ebx, dword[esp + 4]
        mov     edi, dword[esp]
        cmp     dword[esp + 8], 0xFFFF
        jbe      .send

        mov     edx, 0xFFFF
        sub     dword[esp + 8], edx
        add     dword[esp + 4], edx
        shl     edx, 9
        add     dword[esp], edx
        shr     edx, 9
.send:
        push    edx
        call    READ_MULTIPLE_BLOCK
        pop     edx
        cmp     edx, dword[esp + 8]
        jnz     @b

        pop     edi ebx edx

        popa
        mov     eax, 0
        ret
endp
proc    sdhci_write stdcall pdata: dword, buffer: dword, startsector: qword, numsectors_ptr:dword
        pusha
        mov     esi, [pdata]
        mov     eax, [esi + SDHCI_SLOT.base_reg_map]

        mov     ebx, dword[startsector]
        mov     edx, [numsectors_ptr]
        mov     edx, [edx]
        mov     edi, [buffer]
        ;DEBUGF  1,"SDHCI: write sector=%x num=%x \n", ebx, edx
        cmp     edx, 1
        ja      .multiple

        call    WRITE_BLOCK

        popa
        mov     eax, 0
        ret
.multiple:
        push    edx ebx edi
@@:
        mov     edx, dword[esp + 8]
        mov     ebx, dword[esp + 4]
        mov     edi, dword[esp]
        cmp     dword[esp + 8], 0xFFFF
        jbe      .send

        mov     edx, 0xFFFF
        sub     dword[esp + 8], edx
        add     dword[esp + 4], edx
        shl     edx, 9
        add     dword[esp], edx
        shr     edx, 9
.send:
        push    edx
        call    WRITE_MULTIPLE_BLOCK
        pop     edx
        cmp     edx, dword[esp + 8]
        jnz     @b

        pop     edi ebx edx

        popa
        mov     eax, 0
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
        mov     [eax + DISKMEDIAINFO.SectorSize], SD_BLOCK_SIZE
        mov     ecx, dword[edx + SDHCI_SLOT.sector_count]
        mov     dword [eax + DISKMEDIAINFO.Capacity], ecx
        mov     ecx, dword[edx + SDHCI_SLOT.sector_count + 4]
        mov     dword [eax + DISKMEDIAINFO.Capacity + 4], ecx
        pop     edx ecx
        xor     eax, eax
        ret
endp

proc    sdhci_close

        ret
endp

align 4
sdhci_callbacks:
    dd  sdhci_callbacks.end - sdhci_callbacks
    dd  0  ;sdhci_close       ; close function   -
    dd  0  ; closemedia function
    dd  sdhci_querymedia  ; +
    dd  sdhci_read        ; +
    dd  sdhci_write       ; +
    dd  0   ; no flush function
    dd  0   ; use default cache size
.end:
;                                           ; /sdhciXXXS/1
;sdhci_disk_name:        db 'sdhci0000',0,0 ; xxx - number of controller
;                                           ; s - number slot in select controller
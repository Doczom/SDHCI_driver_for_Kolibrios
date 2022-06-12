;;      Copyright (C) 2022, Michail Frolov(aka Doczom)
;; SDHC commands

; in: eax - reg map, esi - struct controller
;     ebx - arg 32 bit в готовом виде ecx - write/read edx - command reg with flags
proc  send_sdhc_command
@@:
        test    dword[eax + SDHC_PRSNT_STATE], 0x07 ; check cmd_inhid_cmd + cmd_inhibit_dat + DAT Line Active
        jnz     @b
        mov     dword[eax + SDHC_CMD_ARG], ebx
        ;подготавливаем данные для формирования команды
        shl     ecx, 4
        shl     edx, 16
        add     edx, ecx
        mov     dword[esi + SDHCI_CONTROLLER.flag_command_copmlate], -1
        DEBUGF  1,"SDHCI: Command send\n"
        mov     dword[eax + SDHC_CMD_TRN], edx ; начало выполнения команды
@@:
        ;test    dword[esi + SDHCI_CONTROLLER.flag_command_copmlate], -1
        test    dword[eax + SDHC_INT_STATUS], 0x01
        jnz     @b
        or      dword[eax + SDHC_INT_STATUS], 0x01
        DEBUGF  1,"SDHCI: Command is out\n"
        DEBUGF  1,"SDHCI: resp1=%x resp2=%x \n", [eax + SDHC_RESP1_0], [eax + SDHC_RESP3_2]
        ret
endp

;basic commands

;cmd0 - Resets all cards to idle state
proc  GO_IDLE_SATTE
        xor     ebx, ebx
        mov     ecx, 0x00
        mov     edx, 0x00
        call    send_sdhc_command
        ret
endp
;cmd2 - Asks any card to send the CID numbers on the CMD line
;resp = R2
proc    ALL_SEND_CID

    ret
endp
;cmd3 - Ask the card to publish a new relative address(RCA)
;resp = R6
proc    SEND_RCA

    ret
endp
;cmd4 - programs the DSR of all cards
proc    SET_DSR

    ret
endp
proc    cmd7
    ret
endp
;cmd8 -
;resp = R7
proc    SEND_IF_COUND
    ret
endp


;acmd41 -
;resp = R3
proc    SD_SEND_OP_COND
    ret
endp
; block read/write

;cmd16 -
;arg = 0-31 - block Length
;resp = R1
proc    SET_BLOCKLEN
    ret
endp
; block  read

;cmd17 -
;arg = 0-31 - data address
;resp = R1
proc    READ_SIGLE_BLOCK
    ret
endp
;cmd18 -
;arg = 0-31 - data address
;resp = R1
proc    READ_MULTIPLE_BLOCK
    ret
endp

; block write

;cmd24 -
;arg = 0-31 - data address
;resp = R1
proc    WRITE_BLOCK
    ret
endp
;cmd25 -
;arg = 0-31 - data address
;resp = R1
proc    WRITE_MULTIPLE_BLOCK
    ret
endp
;cmd27 - Programming of the programmable bits of the CSD
;resp = R1
proc   PROGRAM_CSD
    ret
endp
; SDIO mode

;cmd5 - как ACMD41 но только для SDIO
proc    IO_SEND_OP_COND

    ret
endp
;cmd52 -
proc    IO_RW_DIRECT

    ret
endp
;cmd53 -
proc    IO_RW_EXTENDED

    ret
endp
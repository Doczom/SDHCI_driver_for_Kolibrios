;;      Copyright (C) 2022, Michael Frolov(aka Doczom)
;; SDHC commands

RESP_TYPE:
        .not = 00000b + 00b
        .R1  = 11000b + 10b
        .R1b = 11000b + 11b
        .R2  = 01000b + 01b
        .R3  = 00000b + 10b
        .R4  = .R3
        .R5  = .R1
        .R5b = .R1b
        .R6  = .R1
        .R7  = .R1

CMD_TYPE:     ; 6-7 bits
        .Normal  = 00000000b ; other command
        .Suspend = 10000000b ; CMD12, CMD52 for writing "Bus Suspend" in CCCR
        .Resume  = 01000000b ; CMD52 for writing "Function Select" in CCCR
        .Abort   = 11000000b ; CMD52 for writing "I/O Abort" in CCCR
        ; for 0xc
        .Single   = 000000b
        .Multiple = 100010b
        .Infinite = 100000b

DATA_PRSNT = 100000b ; set for using DAT line for transfer

;Transfer_type:
;        .Single   = 000000b
;        .Multiple = 100010b
;        .Infinite = 100000b
DATA_DIR:
        .Write = 00000b
        .Read  = 10000b

DMA_EN = 1b ; reg 0x0C
ACMD12_EN = 100b ;send acmd12 for end transfer blocks

DMA_SELECT: ; 3-4 bits SDHC_CTRL1 reg
        .SDMA     =  00000b
        .ADMA1    =  010000b
        .ADMA2_32 =  100000b
        .ADMA2_64 =  110000b

SD_BLOCK_SIZE = 0x200 ;standart sector = 512

R1_APP_CMD = 100000b ; карта ожидает ACMD команду
R1_READY_FOR_DATA = 100000000b ; 0x100 соответсятвует сигналу о пустом буфере на шине
; in: eax - reg map, esi - struct controller
;     ebx - arg 32 bit в готовом виде edx - 0x0C register ;command reg with flags
proc  send_sdhc_command
@@:
        test    dword[eax + SDHC_PRSNT_STATE], 0x07 ; check cmd_inhid_cmd + cmd_inhibit_dat + DAT Line Active
        jnz     @b
        mov     dword[eax + SDHC_CMD_ARG], ebx
        mov     dword[esi + SDHCI_CONTROLLER.int_status], 0
        DEBUGF  1,"SDHCI: Command send\n"
        mov     dword[eax + SDHC_CMD_TRN], edx ; начало выполнения команды
@@:
        hlt
        cmp     dword[esi + SDHCI_CONTROLLER.int_status], 0
        ;hlt
        jz     @b
        DEBUGF  1,"SDHCI: resp1=%x resp2=%x \n", [eax + SDHC_RESP1_0], [eax + SDHC_RESP3_2]
        ret
endp

; in: eax - reg map, esi - struct controller
;     ebx - arg 32 bit в готовом виде ecx - 0x0C register edx - command reg with flags
proc  send_sdhc_transfer_command stdcall, arg:dword, _block_size:word, _block_count:word,\
                                          reg0c:dword, virt_addr:dword, phys_addr:dword
@@:
        test    dword[eax + SDHC_PRSNT_STATE], 0x07
        jnz     @b ; check cmd_inhid_cmd + cmd_inhibit_dat + DAT Line Active

        ; (1) Set Block Size Reg
        ; (2) Set Block Count Reg
        ; (3) Set Argument Reg
        ; (4) Set Transfer Mode Reg
        ; (5) Set Command Reg

@@:
        cmp     dword[esi + SDHCI_CONTROLLER.int_status], 0
        hlt
        jz      @b
        DEBUGF  1,"SDHCI: resp1=%x resp2=%x \n", [eax + SDHC_RESP1_0], [eax + SDHC_RESP3_2]

        cmp     dword[esi + SDHCI_CONTROLLER.int_status], 0x01 ; comand complate
        jnz     .err

        ; wait interrupt
.wait_int:
        mov     dword[esi + SDHCI_CONTROLLER.int_status], 0
        hlt
        cmp     dword[esi + SDHCI_CONTROLLER.int_status], 0
        jz      .wait_int

        cmp     dword[esi + SDHCI_CONTROLLER.int_status], 1000b ; DMA intr
        jnz     .no_sdma
        ; set new addr
        jmp     .wait_int
.no_sdma:
        cmp     dword[esi + SDHCI_CONTROLLER.int_status], 10000b ; port write
        jnz     .no_w_port

        ; get phys addr

        jmp     .wait_int
.no_w_port:
        cmp     dword[esi + SDHCI_CONTROLLER.int_status], 100000b ; port read
        jnz     .no_r_port

        ;
        mov     ecx, [eax + SDHC_BUFFER]
        jmp     .wait_int
.no_w_port:
        cmp     dword[esi + SDHCI_CONTROLLER.int_status], 10b ; Transfer complate
        jz      .good_transfer

        cmp     dword[esi + SDHCI_CONTROLLER.int_status], (10b shl 8) shl 16 ; ADMA Error
        jz      .adma_error

.good_transfer:
        DEBUGF 1,"SDHCI: GOOD COMMAND\n"
        ret
.undefined_err:
        DEBUGF 1,"SDHCI: UNDEFINED ERROR\n"
.adma_error:
.err:
        DEBUGF 1,"SDHCI: ERROR TRANSFER COMMAND\n"
        ret
endp

;basic commands

;cmd0 - Resets all cards to idle state
macro   GO_IDLE_SATTE {
        xor     ebx, ebx
        mov     edx, (RESP_TYPE.not) shl 16
        call    send_sdhc_command
        ;ret
}
;cmd2 - Asks any card to send the CID numbers on the CMD line
;resp = R2
;args =
macro   ALL_SEND_CID {
        xor     ebx, ebx  ;arg
        mov     edx, ((2 shl 8) + RESP_TYPE.R2 ) shl 16
        call    send_sdhc_command
        ; save CID
        mov     ecx, [eax + SDHC_RESP1_0]
        mov     ebx, [eax + SDHC_RESP3_2]
        mov     edx, [eax + SDHC_RESP5_4]
        mov     edi, [eax + SDHC_RESP7_6]
        mov     [esi + SDHCI_CONTROLLER.card_reg_cid], ecx
        mov     [esi + SDHCI_CONTROLLER.card_reg_cid + 4], ebx
        mov     [esi + SDHCI_CONTROLLER.card_reg_cid + 8], edx
        mov     [esi + SDHCI_CONTROLLER.card_reg_cid + 12], edi
        DEBUGF  1,"SDHCI: resp3=%x resp4=%x \n", [eax + SDHC_RESP5_4], [eax + SDHC_RESP7_6]
        ;ret
}
;cmd3 - Ask the card to publish a new relative address(RCA)
;resp = R6
;args =
proc    SEND_RCA
        xor     ebx, ebx  ;arg
        mov     edx, ((3 shl 8) + RESP_TYPE.R6 ) shl 16
        call    send_sdhc_command

        mov     ecx, [eax + SDHC_RESP1_0]
        shr     ecx, 16
        mov     word[esi + SDHCI_CONTROLLER.card_reg_rca], cx
        ret
endp
;cmd4 - programs the DSR of all cards
;resp =
;args =
proc    SET_DSR

    ret
endp
;cmd7 - select card for switch in transfer state
;resp =  R1b , ZF - good; not ZF - error
;args =  RCA in ebx
proc    SELECT_CARD
        mov     bx, word[esi + SDHCI_CONTROLLER.card_reg_rca]
        shl     ebx, 16
        mov     edx, ((7 shl 8) + RESP_TYPE.R1b ) shl 16
        call    send_sdhc_command

        test    dword[esi + SDHCI_CONTROLLER.int_status],0x8000
        ret
endp
;cmd7 - switch card in stable state
;resp =  R1b , ZF - good; not ZF - error
proc    DESELECT_CARD
        xor     ebx, ebx
        mov     edx, ((7 shl 8) + RESP_TYPE.R1b ) shl 16
        call    send_sdhc_command

        test    dword[esi + SDHCI_CONTROLLER.int_status],0x8000
        ret
endp
;cmd8 - проверка вольтажа карты для версии 2.0 и выше. Используется для определения версии.
;resp = R7
;args = флаг напряжения питания + маска для проверки, рекомендуется 10101010b
; передаётся выбранное сейчас напряжение питания, если оно подходит, то карточка
; вернёт тоже самое(ну или же своё поддерживаемое напряжение(нет)) в ответе, если нет,
; то ошибка таймаут
; Примечание: Если не вызывать эту команду то карта выдаст ошибку инициализации при ACMD41
proc    SEND_IF_COUND
        mov     ebx, (0001b shl 8) + 10101010b

        cmp     byte[eax + 0x29],1011b
        jnz     @f
        mov     ebx, (0010b shl 8) + 10101010b   ;0001b - уровень напряжения, см спеку физического
@@:                                              ;уровня, стр 51. 2.7V-3.6V=0001b 1.8V=0010b
        mov     edx, ((8 shl 8) + RESP_TYPE.R7 ) shl 16
        call    send_sdhc_command
        ;cmp     word[eax + SDHC_RESP1_0], bx;(0001b shl 8) + 10101010b
        ret
endp

;cmd9 =  get CSD for this card
;resp = R2
;args = [16:31]RCA card
proc    SEND_CSD
        ;DEBUGF  1,"SDHCI: get CSD reg\n"
        mov     bx, word[esi + SDHCI_CONTROLLER.card_reg_rca]
        shl     ebx, 16
        mov     edx, ((9 shl 8) + RESP_TYPE.R2 ) shl 16
        call    send_sdhc_command
        ; save CID
        mov     ecx, [eax + SDHC_RESP1_0]
        mov     ebx, [eax + SDHC_RESP3_2]
        mov     edx, [eax + SDHC_RESP5_4]
        mov     edi, [eax + SDHC_RESP7_6]
        mov     [esi + SDHCI_CONTROLLER.card_reg_csd], ecx
        mov     [esi + SDHCI_CONTROLLER.card_reg_csd + 4], ebx
        mov     [esi + SDHCI_CONTROLLER.card_reg_csd + 8], edx
        mov     [esi + SDHCI_CONTROLLER.card_reg_csd + 12], edi
        DEBUGF  1,"SDHCI: resp3=%x resp4=%x \n", [eax + SDHC_RESP5_4], [eax + SDHC_RESP7_6]
        ret
endp
;cmd10 =  get CID for this card
;resp = R2
;args = [16:31]RCA card
proc    SEND_CID
        ;DEBUGF  1,"SDHCI: get CID reg\n"
        mov     bx, word[esi + SDHCI_CONTROLLER.card_reg_rca]
        shl     ebx, 16
        mov     edx, ((10 shl 8) + RESP_TYPE.R2 ) shl 16
        call    send_sdhc_command
        ; save CID
        mov     ecx, [eax + SDHC_RESP1_0]
        mov     ebx, [eax + SDHC_RESP3_2]
        mov     edx, [eax + SDHC_RESP5_4]
        mov     edi, [eax + SDHC_RESP7_6]
        mov     [esi + SDHCI_CONTROLLER.card_reg_cid], ecx
        mov     [esi + SDHCI_CONTROLLER.card_reg_cid + 4], ebx
        mov     [esi + SDHCI_CONTROLLER.card_reg_cid + 8], edx
        mov     [esi + SDHCI_CONTROLLER.card_reg_cid + 12], edi
        DEBUGF  1,"SDHCI: resp3=%x resp4=%x \n", [eax + SDHC_RESP5_4], [eax + SDHC_RESP7_6]
        ret
endp
;cmd55 = switch to ACMD mode command
;resp = R1
;args = [31:16]RCA [15:0]stuff bits
; команда сообщает карте, что сдудующая команда будет acmd
; WARNING!!! При отключении карты или других ошибках вызывает зависание
proc    APP_CMD
        push    ecx edx ebx
@@:
        mov     bx, word[esi + SDHCI_CONTROLLER.card_reg_rca]
        shl     ebx, 16
        mov     edx, ((55 shl 8) + RESP_TYPE.R1 ) shl 16
        call    send_sdhc_command
        ; тут как я понимаю надо проверять состояние
        cmp     dword[eax + SDHC_RESP1_0], 0x120 ; из исходников embox, это 1 флага
        jnz     @b                               ; по спеке(физ уровень, стр 63(74))
                                                 ; это флаги APP_CMD и READY_FOR_DATA
        ;TODO: сделать выход при ошибке!!!
        pop     ebx edx ecx
        ret
endp

;acmd41 -
;resp = R3
;args = [31]reserved bit [30]HCS(OCR[30]) [29:24]reserved bits
;       [23:0]Vdd Voltage Window(OCR[23:0])
;IN: ebx - argument command
proc    SD_SEND_OP_COND
        call    APP_CMD

        mov     edx, ((41 shl 8) + RESP_TYPE.R3 ) shl 16
        call    send_sdhc_command
        mov     ecx, [eax + SDHC_RESP1_0]
        mov     [esi + SDHCI_CONTROLLER.card_reg_ocr], ecx
        test    dword[esi + SDHCI_CONTROLLER.int_status],0x8000
        ret
endp
; block read/write

;cmd16 -
;arg = 0-31 - block Length
;resp = R1
; IN: ebx - 32bit  block length
proc    SET_BLOCKLEN
        DEBUGF  1,"SDHCI: SET_BLOCKLEN 0x%x\n", ebx
        mov     edx, ((16 shl 8) + RESP_TYPE.R1 ) shl 16
        call    send_sdhc_command
        mov     ecx, [eax + SDHC_RESP1_0]
        mov     [esi + SDHCI_CONTROLLER.card_reg_ocr], ecx
        test    dword[esi + SDHCI_CONTROLLER.int_status],0x8000
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
;proc   PROGRAM_CSD
;    ret
;endp
; SDIO mode
; Отличия от SD memory:
; - CID регистр отсутствует
; -

;cmd5 - как ACMD41 но только для SDIO
;arg = 0-31 - voltage mask, zero to check sdio
;resp = R4
;IN: ebx - argument
proc    IO_SEND_OP_COND
        mov     edx, ((5 shl 8) + RESP_TYPE.R4 ) shl 16

        call    send_sdhc_command
        mov     ecx, [eax + SDHC_RESP1_0]
        mov     [esi + SDHCI_CONTROLLER.card_reg_ocr], ecx
        test    dword[esi + SDHCI_CONTROLLER.int_status],0x8000
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
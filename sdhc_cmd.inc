;;      Copyright (C) 2022, Michael Frolov(aka Doczom)
;; SDHC commands

RESP_TYPE:
        .not = (00000b + 00b)
        .R1  = (11000b + 10b)
        .R1b = (11000b + 11b)
        .R2  = (01000b + 01b)
        .R3  = (00000b + 10b)
        .R4  = .R3
        .R5  = .R1
        .R5b = .R1b
        .R6  = .R1
        .R7  = .R1

CMD_TYPE:     ; 6-7 bits  for 0x0E
        .Normal  = 00000000b ; other command
        .Suspend = 10000000b ; CMD12, CMD52 for writing "Bus Suspend" in CCCR
        .Resume  = 01000000b ; CMD52 for writing "Function Select" in CCCR
        .Abort   = 11000000b ; CMD52 for writing "I/O Abort" in CCCR
        ; for 0x0C
        .Single   = 000000b
        .Multiple = 100010b
        .Infinite = 100000b
        .Write    =  00000b
        .Read     =  10000b

DATA_PRSNT = 100000b ; set for using DAT line for transfer reg 0x0C

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
CMD55_VALID_RESP = R1_READY_FOR_DATA + R1_APP_CMD
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
        jz     @b
        DEBUGF  1,"SDHCI: resp1=%x resp2=%x \n", [eax + SDHC_RESP1_0], [eax + SDHC_RESP3_2]
        ret
endp

; in: eax - reg map, esi - struct controller
;     ebx - argument 32 bit  ecx - 0x0C register
;     edx - (block_count shl 16) + block_size edi - virtual addr ; save in stack
proc  send_sdhc_transfer_command
        push    edx
        push    edi
        push    edi ; virt addr
        sub     esp, 4 ; for save ADMA2\ADMA1 table
@@:
        test    dword[eax + SDHC_PRSNT_STATE], 0x07
        jnz     @b ; check cmd_inhid_cmd + cmd_inhibit_dat + DAT Line Active

        ; (1) Set Block Size Reg
        ; (2) Set Block Count Reg
        mov     dword[eax + SDHX_BLK_CS], edx
        ; (3) Set Argument Reg
        mov     dword[eax + SDHC_CMD_ARG], ebx

        ; set addr
        mov     ebx, dword[eax + SDHC_CTRL1]
        and     ebx, 0x18 ; 3-4 bits
        cmp     ebx, DMA_SELECT.SDMA
        jnz     @f

        xchg    eax, edi
        invoke  GetPhysAddr
        xchg    eax, edi
        mov     [eax + SDHC_SYS_ADDR], edi
        jmp     .end_set_addr
@@:
        cmp     ebx, DMA_SELECT.ADMA2_32
        jnz     .err ;  other DMA mods not supported

        shr     edx, 16
        call    create_adma2_table
        mov     dword[eax + SDHC_ADMA_SAD], edi
        mov     dword[esp], edi

.end_set_addr:
        mov     dword[esi + SDHCI_CONTROLLER.int_status], 0
        ; (4) Set Transfer Mode Reg
        ; (5) Set Command Reg
        mov     dword[eax + SDHC_CMD_TRN], ecx
@@:
        hlt
        cmp     dword[esi + SDHCI_CONTROLLER.int_status], 0
        jz      @b

        cmp     dword[esi + SDHCI_CONTROLLER.int_status], INT_STATUS.CMD_DONE
        jnz     .err
        ; wait interrupt transfer
.wait_int:
        mov     dword[esi + SDHCI_CONTROLLER.int_status], 0
@@:
        hlt
        cmp     dword[esi + SDHCI_CONTROLLER.int_status], 0
        jz      @b;.wait_int

        test    dword[esi + SDHCI_CONTROLLER.int_status], INT_STATUS.ERROR
        jnz     .dat_err

        test   dword[esi + SDHCI_CONTROLLER.int_status], INT_STATUS.DAT_DONE ; Transfer complate
        jnz     .good_transfer

        test    dword[esi + SDHCI_CONTROLLER.int_status], INT_STATUS.DMA_EVT ; DMA intr
        jz      .no_sdma
        ; SDMA add addr and set new phys addr
        and     dword[esp + 4], -4096
        add     dword[esp + 4], 4096
        mov     ecx, dword[esp + 4]
        xchg    eax, ecx
        invoke  GetPhysAddr
        xchg    eax, ecx
        mov     dword[eax + SDHC_SYS_ADDR], ecx
        jmp     .wait_int
.no_sdma:
        test    dword[esi + SDHCI_CONTROLLER.int_status], INT_STATUS.BUF_WR_RDY ; port write
        jz      .no_w_port

        jmp     .wait_int
.no_w_port:
        test    dword[esi + SDHCI_CONTROLLER.int_status], INT_STATUS.BUF_RD_RDY ; port read
        jz      .wait_int  ; undefined interrupt

        mov     ecx, [eax + SDHC_BUFFER]
        jmp     .wait_int

.good_transfer:
        DEBUGF 1,"SDHCI: GOOD COMMAND\n"
        add    esp, 4*4
        ret
.dat_err:
        DEBUGF 1,"SDHCI: ERROR CMD COMMAND\n"
        add    esp, 4*4
        ret
.err:
        DEBUGF 1,"SDHCI: ERROR DAT COMMAND\n"
        add    esp, 4*4
        ret
endp

;basic commands

;cmd0 - Resets all cards to idle state
macro   GO_IDLE_SATTE {
        xor     ebx, ebx
        mov     edx, (RESP_TYPE.not) shl 16
        call    send_sdhc_command
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
;OUT:  ZF - good ; NO ZF - error timeout
; WARNING!!! При отключении карты или других ошибках вызывает зависание
proc    APP_CMD
        push    ecx edx ebx
        dec     esp
        mov     byte[esp], 0
@@:
        inc     byte[esp]
        mov     bx, word[esi + SDHCI_CONTROLLER.card_reg_rca]
        shl     ebx, 16
        mov     edx, ((55 shl 8) + RESP_TYPE.R1 ) shl 16
        call    send_sdhc_command
        ; тут как я понимаю надо проверять состояние
        cmp     dword[eax + SDHC_RESP1_0], CMD55_VALID_RESP
        jz      .good                               ; по спеке(физ уровень, стр 63(74))
        test    byte[esp], 0x80                     ; это флаги APP_CMD и READY_FOR_DATA
        jz      @b
.good:
        lea     esp, [esp + 1]
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
; IN: ebx - addr LBA
;     edi - virt addr data
proc    READ_SIGLE_BLOCK
        ; switch in SDMA mode
        and     dword[eax + SDHC_CTRL1], not 11000b ; set SDMA mode
        mov     edx, SD_BLOCK_SIZE
        mov     ecx, (((17 shl 8) + DATA_PRSNT + RESP_TYPE.R1 ) shl 16) + CMD_TYPE.Single \
                                                                        + CMD_TYPE.Read \
                                                                        + DMA_EN
        call    send_sdhc_transfer_command
        ret
endp
;cmd18 -
;arg = 0-31 - data address
;resp = R1
; IN: ebx - addr LBA
;     edi - virt addr data
;     edx - block count
proc    READ_MULTIPLE_BLOCK
        and     dword[eax + SDHC_CTRL1], not 11000b ; set SDMA mode
        ; TODO: switch in ADMA2 mode
        shl     edx, 16
        add     edx, SD_BLOCK_SIZE
        mov     ecx, (((18 shl 8) + DATA_PRSNT + RESP_TYPE.R1 ) shl 16) + CMD_TYPE.Multiple \
                                                                        + CMD_TYPE.Read \
                                                                        + ACMD12_EN \
                                                                        + DMA_EN
        call    send_sdhc_transfer_command
        ret
endp

; block write

;cmd24 -
;arg = 0-31 - data address
;resp = R1
; IN: ebx - addr LBA
;     edi - virt addr data
proc    WRITE_BLOCK
        ; switch in SDMA mode
        and     dword[eax + SDHC_CTRL1], not 11000b ; set SDMA mode
        mov     edx, SD_BLOCK_SIZE
        mov     ecx, (((24 shl 8) + DATA_PRSNT + RESP_TYPE.R1 ) shl 16) + CMD_TYPE.Single \
                                                                        + CMD_TYPE.Read \
                                                                        + DMA_EN
        call    send_sdhc_transfer_command
        ret
endp
;cmd25 -
;arg = 0-31 - data address
;resp = R1
; IN: ebx - addr LBA
;     edi - virt addr data
;     edx - block count
proc    WRITE_MULTIPLE_BLOCK
        and     dword[eax + SDHC_CTRL1], not 11000b ; set SDMA mode
        ; TODO: switch in ADMA2 mode
        shl     edx, 16
        add     edx, SD_BLOCK_SIZE
        mov     ecx, (((25 shl 8) + DATA_PRSNT + RESP_TYPE.R1 ) shl 16) + CMD_TYPE.Multiple \
                                                                        + CMD_TYPE.Read \
                                                                        + ACMD12_EN \
                                                                        + DMA_EN
        call    send_sdhc_transfer_command
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
; - CSD регистр отсутствует

;cmd5 - как ACMD41 но только для SDIO
;arg = 0-31 - voltage mask, zero to check sdio
;resp = R4
;IN: ebx - argument
; OUT: ZF - good ; not ZF - error
proc    IO_SEND_OP_COND
        mov     edx, ((5 shl 8) + RESP_TYPE.R4 ) shl 16

        call    send_sdhc_command
        mov     ecx, [eax + SDHC_RESP1_0]
        mov     [esi + SDHCI_CONTROLLER.card_reg_ocr], ecx
        test    dword[esi + SDHCI_CONTROLLER.int_status], INT_STATUS.ERROR
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
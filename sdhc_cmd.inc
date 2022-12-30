;;      Copyright (C) 2022, Michael Frolov(aka Doczom)
;; SDHC commands

; Response Bir Definition and Each Response type
;  R1,R1b (normal response)    - Card Status                  - REP[0:31]
;  R1b (Auto CMD12 response)   - Card Status for Auto CMD12   - REP[96:127]
;  R1 (Auto CMD23 response)    - Card Status for Auto CMD23   - REP[96:127]
;  R2 (CID, CSD register)      - CID or CSD reg. incl.        - REP[0:119]
;  R3 (OCR register)           - OCR register for memory      - REP[0:31]
;  R4 (OCR register)           - OCR register for I/O etc     - REP[0:31]
;  R5, R5b                     - SDIO response                - REP[0:31]
;  R6 (Published RCA response) - New published RCA[16:31] etc - REP[0:31]
;  R7 (return CMD8)            - Voltage flags + mask protect - REP[0:31]
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
;      OCR register
;   bit   |  data
;---------|----------------------------;
;   0-6   |  reserved                  ;
;    7    |  Low Voltage Range (1.8V)  ;
;   8-14  |  reserved                  ;
;    15   |  2.7 - 2.8V                ;
;    16   |  2.8 - 2.9V                ;
;    17   |  2.9 - 3.0V                ;
;    18   |  3.0 - 3.1V                ;
;    19   |  3.1 - 3.2V                ;
;    20   |  3.2 - 3.3V                ;
;    21   |  3.3 - 3.4V                ;
;    22   |  3.4 - 3.5V                ;
;    23   |  3.5 - 3.6V                ;
;    24   |  reserved                  ;  <- only to UHS-I "switching to 1.8 Accepted (S18A)"
;  25-26  |  reserved                  ;
;    27   |  reserved                  ;  <- only to SDUC "Over to 2TB support Status (CO2T)"
;    28   |  reserved                  ;
;    29   |  reserved                  ;  <- UHS-II Card Status
;    30   |  Card Capacity Status(CCS) ;
;    31   |  Card power up status bit  ; (busy)
;--------------------------------------;

;     I/O OCR register
;   bit   |  data
;---------|----------------------------;
;   0-7   |  reserved                  ;
;    8    |  2.0 - 2.1V                ;
;    9    |  2.1 - 2.2V                ;
;    10   |  2.2 - 2.3V                ;
;    11   |  2.3 - 2.4V                ;
;    12   |  2.4 - 2.5V                ;
;    13   |  2.5 - 2.6V                ;
;    11   |  2.6 - 2.7V                ;
;    15   |  2.7 - 2.8V                ;
;    16   |  2.8 - 2.9V                ;
;    17   |  2.9 - 3.0V                ;
;    18   |  3.0 - 3.1V                ;
;    19   |  3.1 - 3.2V                ;
;    20   |  3.2 - 3.3V                ;
;    21   |  3.3 - 3.4V                ;
;    22   |  3.4 - 3.5V                ;
;    23   |  3.5 - 3.6V                ;
;    24   |  switching to 1.8 Accepted ;  <- "switching to 1.8 Accepted (S18A)"
;  25-26  |  reserved                  ;
;    27   |  Memory Present            ;  <- 1 усли карта содержит SD память, 0 если только I/O
;  28-30  |  Number of I/O Functions   ;  <- не включаем общую область функции 0 (подробнее в SDIO спеке)
;    31   |  Card power up status bit  ; (busy)
;--------------------------------------;
; CID register
;

R1_APP_CMD = 100000b ; карта ожидает ACMD команду
R1_READY_FOR_DATA = 100000000b ; 0x100 соответсятвует сигналу о пустом буфере на шине
; in: eax - reg map, esi - struct controller
;     ebx - arg 32 bit в готовом виде ecx - 0x0C register edx - command reg with flags
proc  send_sdhc_command
@@:
        test    dword[eax + SDHC_PRSNT_STATE], 0x07 ; check cmd_inhid_cmd + cmd_inhibit_dat + DAT Line Active
        jnz     @b
        mov     dword[eax + SDHC_CMD_ARG], ebx
        ;подготавливаем данные для формирования команды
        shl     edx, 16
        add     edx, ecx
        mov     dword[esi + SDHCI_CONTROLLER.int_status], 0
        DEBUGF  1,"SDHCI: Command send\n"
        mov     dword[eax + SDHC_CMD_TRN], edx ; начало выполнения команды
@@:
        cmp     dword[esi + SDHCI_CONTROLLER.int_status], 0
        hlt
        jz     @b
        DEBUGF  1,"SDHCI: resp1=%x resp2=%x \n", [eax + SDHC_RESP1_0], [eax + SDHC_RESP3_2]
        ret
endp

;basic commands

;cmd0 - Resets all cards to idle state
macro   GO_IDLE_SATTE {
        xor     ebx, ebx
        mov     ecx, 0x00;0x02 ; read mull
        mov     edx, RESP_TYPE.not
        call    send_sdhc_command
        ;ret
}
;cmd2 - Asks any card to send the CID numbers on the CMD line
;resp = R2
;args =
macro   ALL_SEND_CID {
        xor     ebx, ebx  ;arg
        mov     ecx, 0x00;0x02 ; read mull
        mov     edx, (2 shl 8) + RESP_TYPE.R2 ;01000b + 01b
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
        mov     ecx, 0x00;0x02 ; read mull
        mov     edx, (3 shl 8) + RESP_TYPE.R6 ;01000b + 01b
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
proc    cmd7
    ret
endp
;cmd8 - проверка вольтажа карты для версии 2.0 и выше. Используется для определения версии.
;resp = R7
;args = флаг напряжения питания + маска для проверки, рекомендуется 10101010b
; передаётся выбранное сейчас напряжение питания, если оно подходит, то карточка
; вернёт тоже самое(ну или же своё поддерживаемое напряжение(нет)) в ответе, если нет,
; то ошибка таймаут
proc    SEND_IF_COUND

        mov     ebx, (0001b shl 8) + 10101010b   ;0001b - уровень напряжения, см спеку физического
                                                 ;уровня, стр 51. 2.7V-3.6V=0001b 1.8V=0010b
        mov     ecx, 0x00;0x02 ; read mull
        mov     edx, (8 shl 8) + RESP_TYPE.R7 ;01000b + 11b
        call    send_sdhc_command
        cmp     word[eax + SDHC_RESP1_0], (0001b shl 8) + 10101010b
        ret
endp

;cmd9 =  get CSD for this card
;resp = R2
;args = [16:31]RCA card
proc    SEND_CSD

        ret
endp
;cmd55 = switch to ACMD mode command
;resp = R1
;args = [31:16]RCA [15:0]stuff bits
; команда сообщает карте, что сдудующая команда будет acmd
proc    APP_CMD
        push    ecx edx ebx
@@:
        mov     bx, word[esi + SDHCI_CONTROLLER.card_reg_rca]
        shl     ebx, 16
        mov     ecx, 0x00;0x02 ; read mull
        mov     edx, (55 shl 8) + RESP_TYPE.R1;11000b + 11b
        call    send_sdhc_command
        ; тут как я понимаю надо проверять состояние
        cmp     dword[eax + SDHC_RESP1_0], 0x120 ; из исходников embox, это 1 флага
        jnz     @b                               ; по спеке(физ уровень, стр 63(74))
                                                 ; это флаги APP_CMD и READY_FOR_DATA
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

        mov     ecx, 0x00;0x02 ; read mull
        mov     edx, (41 shl 8) + RESP_TYPE.R3
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
;arg = 0-31 - voltage mask, zero to check sdio
;resp = R4
;IN: ebx - argument
proc    IO_SEND_OP_COND

        mov     ecx, 0x00;0x02 ; read mull
        mov     edx, (5 shl 8) + RESP_TYPE.R4;00000b + 10b ;TODO

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
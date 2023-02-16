;;      Copyright (C) 2022-2023, Michael Frolov aka Doczom
;; SD host controller driver.
;;
;;                 !!!!ВНИМАНИЕ!!!!
;;  Драйвер работает только по спецификации 2.0 и тестируется только на
;; контроллере данной версии. Для контроллеров более новой версии драйвер
;; будет работать как с контроллером по спецификации версии 2.0. Функции
;; контроллера из за этого могут ограничены.

format PE native
entry START
use32

        DEBUG                   = 1
        __DEBUG__               = 1
        __DEBUG_LEVEL__         = 1             ; 1 = verbose, 2 = errors only


        API_VERSION             = 0  ;debug
        STRIDE                  = 4      ;size of row in devices table

        SRV_GETVERSION          = 0

; base SD registers
SDHC_SYS_ADDR   = 0x00
SDHX_BLK_CS     = 0x04
; Аргумент SD команды, подробнее в специфиации физического уровня
SDHC_CMD_ARG    = 0x08
SDHC_CMD_TRN    = 0x0c

;0x10-0x1f - Response
SDHC_RESP1_0    = 0x10
SDHC_RESP3_2    = 0x14
SDHC_RESP5_4    = 0x18
SDHC_RESP7_6    = 0x1C

SDHC_BUFFER     = 0x20

SDHC_PRSNT_STATE = 0x24  ;word (12-15 , 26 Rsvd)
PRSNT_STATE:
  .CMD_INHIB_CMD = 0x01 ; for test [eax + SDHC_PRSNT_STATE], SDHC_PRSNT_STATE.CMD_INHIB_CMD
  .CMD_INHIB_DAT = 0x02
  .DAT_LINE_ACTIVE = 0x04
  .WR_TX_ACTIVE    = 0x100
  .RD_TX_ACTIVE    = 0x200
  .BUF_WR_EN       = 0x400
  .BUF_RD_EN       = 0x800
  .CARD_INS        = 0x10000
  .CARD_STABLE     = 0x20000
  .CD_LEVEL        = 0x40000
  .WP_LEVEL        = 0x80000
  .DAT_LEVEL       = 0xf00000 ; 4 bits
  .CMD_LEVEL       = 0x1000000

SDHC_CTRL1      = 0x28
  Power_control = 0x29  ; byte (using 0-3 bits)
  block_gap_control = 0x2a ;byte (using 0-3 bits)
  Wekeup_control = 0x2b  ;byte (using 0-2 bits)

SDHC_CTRL2      = 0x2C
  clock_control = 0x2c ;word
  timeout_control = 0x2e ;byte (using 0-3 bits)
  software_reset = 0x2f ;byte (using 0-2 bits)
    .software_reset_for_all             = 0x01  ;1-reset 0-work
    .saftware_reset_for_cmd_line        = 0x02  ;1-reset 0-work
    .software_reset_for_dat_line        = 0x04  ;1-reset 0-work

;0x30-0x3d - Interrupt Controls
SDHC_INT_STATUS = 0x30
SDHC_INT_MASK   = 0x34
SDHC_SOG_MASK   = 0x38
INT_STATUS:
    .CMD_DONE       = 0x01
    .DAT_DONE       = 0x02
    .BLOCK_GAP_EVT  = 0x04
    .DMA_EVT        = 0x08
    .BUF_WR_RDY     = 0x10
    .BUF_RD_RDY     = 0x20
    ; Если появилось прерывания вставки или вытаскивания карты, нужно проверить это через регистр 0x24 .
    ;для отключения генерации прерываний записать в нужный бит единицу(через or например).
    .CARD_INS       = 0x40
    .CARD_REM       = 0x80
    .SDIO           = 0x0100
    .INT_A          = 0x0200 ; in 2 version not used
    .INT_B          = 0x0400 ; in 2 version not used
    .INT_C          = 0x0800 ; in 2 version not used
    ;.re_tuning_event = 0x1000
    ;.FX_event        = 0x2000
    ; 14 bit reserved
    .ERROR          = 0x8000   ;есть во всех версиях спеки
    ; error interupt
    .ALL_ERROR      = 0xFFFF0000 ; set all type error
    .CMD_TO_ERR     = 0x01   ; (SD mode only)
    .CMD_CRC_ERR    = 0x02   ; 1=crc error generation 0=no error (sd mode only)
    .CMD_END_ERR    = 0x04   ; 1=end_bit_error_generation 0=no error (sd mode only)
    .CMD_IDX_ERR    = 0x08   ; (SD mode only)
    .DAT_TO_ERR     = 0x10   ; 1=time out 0= no error (sd mode only)
    .DAT_CRC_ERR    = 0x20   ; (SD mode only)
    .DAT_END_ERR    = 0x40   ; (SD mode only)
    ;.current_limit_error = 0x80   ; 1=Power_fail 0=no_error
    .ACMD12_ERR     = 0x0100 ; (SD mode only)
    .ADMA_ERR       = 0x0200 ; появляется во 2 версии спеки
    ;.tuning_error  = 0x0400 ; 1=error 0=no error (UHS-I only)
    ;.response_error = 0x0800 ; (SD mode only) in 4.00 version
    ;.vendor_specific_error_status = 0xf000
SDHC_ACMD12_ERR = 0x3C
ACMD12_ERR:
    .EXE_ERR    = 0x01 ; 1=not_executed 0=executed
    .TO_ERR     = 0x02 ; 1=time out 0=no_error
    .CRC_ERR    = 0x04 ; 1=crc error generation 0=no_error
    .END_ERR    = 0x08 ; 1=end_bit_error_generated  0=no_error
    .INDEX_ERR  = 0x10 ; 1=error 0=no_error
    ;.auto_cmd_response_error = 0x20 1=error 0=no_error
    ; 5-6 bit is reserved
    .CMD_ERR    = 0x80 ; 1=Not_issued 0=no_error

;0x3e-0x3f - Host Control 2 ;spec version 3
SDHC_HOST_CONTROL_2_REG = 0x3e   ; word

SDHC_CAPABILITY = 0x40 ;qword
SDHC_CURR_CAPABILITY = 0x48 ; qword (using 0-23 32-39)

SDHC_FORCE_EVT  = 0x50
  force_event_register = 0x50 ;word (using 0-7 bits)
  force_event_register_for_interrupt_status = 0x52 ; word

SDHC_ADMA_ERR   = 0x54 ; byte (using 0-2 bits)
SDHC_ADMA_SAD   = 0x58

SDHC_VER_SLOT   = 0xfc ; block data
 SLOT_INTRPT     = 0xfc ;Slot interapt status register 1 byte; 0xfd - reserved
 SPEC_VERSION = 0xfe ; in map register controller(15-8 - vendor version; 7-0 - spec version)
 VENDOR_VERSION = 0xff

; PCI reg
pci_class_sdhc  = 0x0805 ;basic_class=0x08 sub_class=05
PCI_BAR0        = 0x10
PCI_BAR1        = 0x14
PCI_BAR2        = 0x18
PCI_BAR3        = 0x1C
PCI_BAR4        = 0x20
PCI_BAR5        = 0x14
PCI_IRQ_LINE    = 0x3C

PCI_slot_information = 0x40 ;0-2 first BAR 4-6 - number of Slots(counter BAR?)


section '.flat' code readable writable executable

include 'drivers/proc32.inc'
include 'drivers/struct.inc'
include 'drivers/macros.inc'
include 'drivers/peimport.inc'
include 'drivers/fdo.inc'


include 'sdhc_cmd.inc'
include 'sdhc_disk.inc'
include 'sdhci_adma.inc'
; structures
struct  SDHCI_CONTROLLER
        fd      rd 1   ; next controller
        bk      rd 1   ; pref controller

        dev     rd 1   ;
        bus     rd 1   ;

        base_reg_map    rd 1 ;pointer to registers controller
        base_sdhc_reg   rd 1 ; offset for BAR
        count_bar_reg   rd 1 ; count BAR for this register

        ver_spec        rb 1 ; using 0 - 4  bits
        flag_pci_dma    rb 1 ; 0 - no DMA, 1 - yes DMA

        irq_line        rd 1 ;rb
        Capabilities    rd 2 ; qword - save Capabilities
        max_slot_amper  rd 2

        divider400KHz   rd 1 ; for SDCLK frequency Select
        divider25MHz    rd 1
        divider50MHz    rd 1
        timeout_reg     rd 1 ; offset 0x2e in reg map

        type_card       rd 1 ; 0 - no card 1 - SDIO 2 - MMC(eMMC) 4 - standart flash card  5+ - other
        card_mode       rd 1 ; 1 - spi 2 - sd bus  3+ - other
        dma_mode        rd 1 ; 0-no dma 1-sdma 2-adma1 3 adma2

        card_reg_ocr    rd 1 ; 32 bit  card voltage
        card_reg_cid    rd 4 ; 128 bit 120 bit
        card_reg_csd    rd 4 ; 128 bit (регистр может быть 2 версий)
        card_reg_rca    rw 1 ; rw 1   ; 16 bit
        card_reg_dsr    rw 1 ; rw 1 ;16 bit (optional)
        card_reg_scr    rd 2 ; 64 bits
        card_reg_ssr    rd 16 ; 512bit

        sector_count    rq 1  ; count rw sectors on SD\SDIO\MMC card

        program_id      rd 1 ; tid thread for working with no memory cards

        flag_command_copmlate rd 1 ; flag interrapt command complate 00 - interrapt is geting
        flag_transfer_copmlate rd 1 ; flag interrapt transfer complate 00 -interrapt is geting
        int_status      rd 1 ; copy SDHC_INT_STATUS
                        rd 4 ; reserved
        status_control  rd 1 ; flags status controller(0x01 - get irq AND int_status good)
                             ; status for write\read  disk, global flags

ends

struct  SDHCI_SLOT
        reg_map         rd 1; pointer to register map
        Capabilities    rd 2 ; qword - save Capabilities
        divider400KHz   rd 1 ; for SDCLK frequency Select
        divider25MHz    rd 1
        divider50MHz    rd 1
        max_slot_amper  rd 2
ends;
count_controller:       dd 0
list_controllers:
.fd:       dd list_controllers ; pointer to first item list
.bk:       dd list_controllers ; pointer to last item list

root_PCIList:       dd 0

proc START c, state:dword, cmdline:dword
        cmp     [state], DRV_ENTRY
        push    ebx esi edi ebp
        jne     .stop_drv

        ;detect controller
        DEBUGF  1,"SDHCI: Loading driver\n"
        invoke  GetPCIList
        mov     [root_PCIList], eax
        push    eax
.next_dev:
        pop     eax
        mov     eax, [eax+PCIDEV.fd]
        cmp     eax, [root_PCIList]
        push    eax
        jz      .end_find

        cmp     word[eax + PCIDEV.class + 1], 0x0805
        jnz     .next_dev

        mov     esi, eax
        invoke  KernelAlloc, sizeof.SDHCI_CONTROLLER
        test    eax, eax
        jz      .not_memory

        mov     ecx, [list_controllers.bk]
        mov     [eax + SDHCI_CONTROLLER.bk], ecx
        mov     [ecx + SDHCI_CONTROLLER.fd], eax
        mov     [eax + SDHCI_CONTROLLER.fd], list_controllers

        ;push    eax
        push    eax
        call    sdhci_init  ; in: eax - structure esi - pointer to PCIDEV ;return 0 - good ; other - error code
        pop     esi
        DEBUGF  1,"SDHCI_INIT: error code =%d bus: %d devfn: %d \n", eax, [esi + SDHCI_CONTROLLER.bus], [esi + SDHCI_CONTROLLER.dev]
        inc     dword[count_controller]
        test    eax, eax
        mov     eax, esi;pop     eax ; structure SDHCI_CONTROLLER
        jz     .next_dev

        DEBUGF  1,"ERROR: Contriller not init\n"
        mov     ecx, [eax + SDHCI_CONTROLLER.fd]
        mov     edx, [eax + SDHCI_CONTROLLER.bk]
        mov     [ecx + SDHCI_CONTROLLER.bk], edx
        mov     [edx + SDHCI_CONTROLLER.fd], ecx
        dec     dword[count_controller]

        invoke  KernelFree, eax  ; free structure when error code not zero
        jmp     .next_dev
.not_memory:
        DEBUGF  1,"ERROR: can't alloc memory for structure SDHC_CONTROLLER\n"
        jmp     .next_dev
.end_find:
        pop     eax
        xor     eax, eax
        cmp     eax, [count_controller]
        jz      .not_found

        DEBUGF  1,"SDHCI: Found %d controllers\n", [count_controller]
        invoke  RegService, drv_name, 0 ;service_proc
        pop     ebp edi esi ebx
        ret
.not_found:
        DEBUGF  1,"SDHCI: Contriller not found\n"
        mov     eax, 0
        pop     ebp edi esi ebx
        ret
.stop_drv:
        ; deattach  irq
        ; stop power devise
        ; free struct
           ; free reg_map
           ; free memory for DMA

        DEBUGF  1, "SDHCI: Stop working driver\n"
        xor     eax, eax
        pop     ebp edi esi ebx
        ret
endp

;init controller, set base value, add interrupt function, set stucture for controller
; in: eax - pointer to structure controller; esi - pointer to PCIDEV structure
; out: eax - error code 0 - good; other - error init
proc sdhci_init
        ;set base data in SDHCI_CONTROLLER structure
        movzx   ebx, [esi + PCIDEV.devfn]
        mov     [eax + SDHCI_CONTROLLER.dev], ebx
        movzx   ebx, [esi + PCIDEV.bus]
        mov     [eax + SDHCI_CONTROLLER.bus], ebx
        ;controller found and init
        mov     bl, byte [esi + PCIDEV.class] ; get interface code
        mov     [eax + SDHCI_CONTROLLER.flag_pci_dma], bl  ; 0-not use dma 1-use dma 2 -Vendor unique SD hoet controller
        DEBUGF  1,"DMA using: %x \n",[eax + SDHCI_CONTROLLER.flag_pci_dma]

        mov     esi, eax

        invoke  PciRead32, [esi + SDHCI_CONTROLLER.bus], [esi + SDHCI_CONTROLLER.dev], dword 4
        test    eax, 0x4 ; Test Master bit
        jnz     @f
        or      eax, 0x4 ; Set Master bit
        movi    ebx, 0x6
        and     ebx, eax
        cmp     ebx, 0x6 ; Test Master and Memory bits
        jz      @f
        or      eax, 0x6 ; Set Master and Memory bits
        invoke  PciWrite32, [esi + SDHCI_CONTROLLER.bus], [esi + SDHCI_CONTROLLER.dev], dword 4, eax
        invoke  PciRead32, [esi + SDHCI_CONTROLLER.bus], [esi + SDHCI_CONTROLLER.dev], dword 4
@@:
        DEBUGF  1,"Status: %x \n", eax

        ;get slot information and get base register sd host controller
        invoke  PciRead8, [esi + SDHCI_CONTROLLER.bus], dword[esi + SDHCI_CONTROLLER.dev], PCI_slot_information
        movzx   edx, al
        and     edx, 111b
        mov     [esi + SDHCI_CONTROLLER.base_sdhc_reg], edx   ;save offset base register sdhc
        ;mov     ebx, edx ;save offset for get base addr reg sdhc
        shr     eax, 4
        and     eax, 111b
        mov     [esi + SDHCI_CONTROLLER.count_bar_reg], eax   ;save count working basical addres register
        DEBUGF  1,"SDHCI: base BAR: %x count BAR: %x\n",[esi + SDHCI_CONTROLLER.base_sdhc_reg], [esi + SDHCI_CONTROLLER.count_bar_reg]

        ;get base addr reg sdhc and open mmio on 256 byte(standart size for sdhc)
        add     edx, PCI_BAR0 ; get base pci_bar  controller
        invoke  PciRead32, dword [esi + SDHCI_CONTROLLER.bus], dword [esi + SDHCI_CONTROLLER.dev], edx
        and     al, not 0Fh   ;? not 0xff
        invoke  MapIoMem, eax, 0x100, PG_SW+PG_NOCACHE  ;?
        test    eax, eax
        jz      .fail

        DEBUGF  1,"SDHCI: base address = %x \n", eax
        mov     [esi + SDHCI_CONTROLLER.base_reg_map], eax
        mov     cl, [eax + SPEC_VERSION] ; get specification version
        mov     [esi + SDHCI_CONTROLLER.ver_spec], cl
        DEBUGF  1,"Version specification: %x \n",[esi + SDHCI_CONTROLLER.ver_spec]

        DEBUGF  1,"SLOT_INTRPT: %x \n", [eax + SLOT_INTRPT]


        ;reset controller (all)
        mov     eax, [esi + SDHCI_CONTROLLER.base_reg_map]
        inc     byte[eax + software_reset]
@@:
        test    byte[eax + software_reset], 0xFF
        jnz     @b
        ;TODO: add settings controller

        ; Сохранить регистр Capabiliti и max Current Capabilities
        mov     ebx, [eax + SDHC_CAPABILITY]
        mov     [esi + SDHCI_CONTROLLER.Capabilities], ebx
        mov     ebx, [eax + SDHC_CAPABILITY + 4]
        mov     [esi + SDHCI_CONTROLLER.Capabilities + 4], ebx
        DEBUGF  1,"SDHCI:Capabilities %x %x\n",[esi + SDHCI_CONTROLLER.Capabilities + 4],[esi + SDHCI_CONTROLLER.Capabilities]

        mov     ebx, [eax + SDHC_CURR_CAPABILITY]
        mov     [esi + SDHCI_CONTROLLER.max_slot_amper], ebx
        mov     ebx, [eax + SDHC_CURR_CAPABILITY + 4]
        mov     [esi + SDHCI_CONTROLLER.max_slot_amper + 4], ebx
        DEBUGF  1,"SDHCI:Max current capabilities %x %x\n",[esi + SDHCI_CONTROLLER.max_slot_amper + 4],[esi + SDHCI_CONTROLLER.max_slot_amper]

        ; получить DMA режим : 0 - no dma   1 - sdma  2 - adma1   3 - adma2-32bit   4 - adma2-64bit(не нужно, так как ос 32 бита)
        mov     ebx, [eax + SDHC_CAPABILITY]
        mov     ecx, 3
        bt      ebx, 19  ; support adma2
        jc      @f
        dec     ecx
        bt      ebx, 20  ; support adma1
        jc      @f
        dec     ecx
        bt      ebx, 22  ; support sdma
        jc      @f
        dec     ecx
@@:
        mov     [esi + SDHCI_CONTROLLER.dma_mode], ecx
        DEBUGF  1,"SDHCI: DMA mode: %x \n", [esi + SDHCI_CONTROLLER.dma_mode]
        test    ecx, ecx
        jz      @f
        dec     ecx
@@:
        shl     ecx, 3
        ;and     ecx, not 0x111 ;не нужно так как shl ecx,3 и так запишет эти биты в ноль
        or      dword[eax + SDHC_CTRL1], ecx
        ; байт 0x28 установлен в начальное значение

        ; получить значения делителей частоты
        push    eax
        mov     eax, [esi + SDHCI_CONTROLLER.Capabilities]
        shr     eax, 8
        and     eax, 11111111b  ; 1111 1111
        mov     ebx, 25
        xor     edx, edx
        div     ebx ; 25 мгц
        bsr     ecx, eax
        xor     edx, edx
        bsf     edx, eax
        cmp     ecx, edx
        jnz     @f
        dec     ecx
@@:
        xor     edi, edi
        bts     edi, ecx
        mov     dword[esi + SDHCI_CONTROLLER.divider25MHz], edi
        DEBUGF  1,'25MHz : %u\n', edi
        shr     edi, 1   ; +- десять
        mov     dword[esi + SDHCI_CONTROLLER.divider50MHz], edi
        DEBUGF  1,'50MHz : %u\n', edi
        imul    eax, 63  ; примерно

        bsr     ecx, eax
        xor     edx, edx
        bsf     edx, eax
        cmp    ecx, edx
        jnz     @f
        dec     ecx
@@:
        xor     edi, edi
        bts     edi, ecx
        mov     dword[esi + SDHCI_CONTROLLER.divider400KHz], edi
        DEBUGF  1,'400KHz : %u\n', edi

        pop     eax
        ; Установить значения в Host Control Register
        ; на этом вроде настройка завершина

        ;прочитать регистр 0х0-0х4f
        ;установить значения в host control 2
        ;set 0x2e

        mov     dword[eax + SDHC_INT_STATUS], 0x00

        ; set Wekeup_control
        or      byte[eax + Wekeup_control], 111b

        ; save and attach IRQ
        and     dword[eax + SDHC_INT_MASK], 0
        and     dword[eax + SDHC_SOG_MASK], 0

        invoke  PciRead8, dword [esi + SDHCI_CONTROLLER.bus], dword [esi + SDHCI_CONTROLLER.dev], PCI_IRQ_LINE ;al=irq
        movzx   eax, al
        mov     [esi + SDHCI_CONTROLLER.irq_line], eax ;save irq line
        invoke  AttachIntHandler, eax, sdhc_irq, esi ;esi = pointre to controller struct

        mov     eax, [esi + SDHCI_CONTROLLER.base_reg_map]
        or      dword[eax + SDHC_INT_MASK], INT_STATUS.CARD_INS + INT_STATUS.CARD_REM
        or      dword[eax + SDHC_SOG_MASK], INT_STATUS.CARD_INS + INT_STATUS.CARD_REM
        DEBUGF  1,'SDHCI: Enable insert and remove interrupt\n'

        ; Детектим карты
        ;mov     eax, [esi + SDHCI_CONTROLLER.base_reg_map]
        test    dword[eax + SDHC_PRSNT_STATE], 0x10000 ; check 16 bit in SDHC_PRSNT_STATE.CARD_INS
        jz      @f
        call    card_init ; eax - REGISTER MAP esi - SDHCI_CONTROLLER
@@:

        xor     eax, eax
        ret
.fail:
        DEBUGF  1,"SDHC_INIT: RUNTIME ERROR"
        mov     eax, 1
        ret
endp

; eax - map reg
; ebx - divider Clock base
proc set_SD_clock
        and     dword[eax + SDHC_CTRL2], not 100b  ; stop clock


        and     dword[eax + SDHC_CTRL2], 0xffff0000 ; clear
        cmp     ebx, 0x80
        jbe     @f

        push    ebx
        shr     ebx, 8
        and     ebx, 11b
        shl     ebx, 6
        or      dword[eax + SDHC_CTRL2], ebx
        pop     ebx
@@:
        and     ebx, 0xff
        shl     ebx, 8
        or      ebx, 0x01 ; start internal clock
        or      dword[eax + SDHC_CTRL2], ebx
        DEBUGF  1,'SDHCI: Set clock divider\n'
@@:
        test    dword[eax + SDHC_CTRL2], 0x02; check stable
        jz      @b
        DEBUGF  1,'SDHCI: Clock stable \n'
        or      dword[eax + SDHC_CTRL2], 0x04 ; set SD clock enable
        ret
endp


proc card_init
        DEBUGF  1,'SDHCI: Card inserted\n'
        and     dword[esi + SDHCI_CONTROLLER.card_reg_rca], 0 ; обнуляем адрес карты
        ;включаем прерывания 0х01
        or      dword[eax + SDHC_INT_MASK], 0xFFFF0001
        or      dword[eax + SDHC_SOG_MASK], 0xFFFF0001
        ; Включить питание (3.3В - не всегда) максимально возможное для хоста
        ; дай бог чтоб не сгорело ничего
        mov     ebx, [esi + SDHCI_CONTROLLER.Capabilities]
        shr     ebx, 24
        and     ebx, 111b ;26bit - 1.8  25bit - 3.0  24bit - 3.3
        bsf     ecx, ebx  ;ecx= 0 for 3.3, 1 for 3.0 , 2 for 1.8
        jz      .err
        mov     edx, 111b
        sub     edx, ecx  ; see format data this register in specs
        shl     edx, 1
        or      edx, 0x01   ; для активации наприяжения
        shl     edx, 8 ; offset 0x29
        or      dword[eax + SDHC_CTRL1], edx
        DEBUGF  1,'SDHCI: SDHC_CTRL1= %x \n',[eax + SDHC_CTRL1]
        DEBUGF  1,'SDHCI: Питание включено, дай бог чтоб ничего не сгорело \n'

        ; включить генератор частот контроллера и установим базовые значения регистров
        ; генератор на 400 КГц
        mov     ebx, [esi + SDHCI_CONTROLLER.divider400KHz]
        call    set_SD_clock
        ; очищает SDHC_CTRL1
        and     dword[eax + SDHC_CTRL1], 11000b + 0x0f00 ;оставляем только dma режим и power control

        ;; !!! Начинается алгоритм инициализации карты !!!

        ; cmd0 - reset card
        GO_IDLE_SATTE  ; ok
        ;выбираем режим работы(sd bus, spi) - но это не точно  ; Это не тут, ниже

        ; cmd5 voltage window = 0 - check sdio
        ;DEBUGF  1,"SDHCI: CMD5 - check SDIO\n"
        xor     ebx, ebx ; arg cmd, zero to get voltage mask and to check SDIO functions
        call    IO_SEND_OP_COND; 0 - test voltage mask to check SDIO interface, ZF=1-sdio
        jz      .sdio

        ;DEBUGF  1,"SDHCI: CMD8 - check SDHC card\n"
        call    SEND_IF_COUND
        ;DEBUGF  1,"SDHCI: ACMD41 - get OCR\n"
        mov     [esi + SDHCI_CONTROLLER.card_reg_ocr], 1 shl 30 ; set HSP
.set_acmd41:
        ; TODO: Добавить задержку на 10мс, как в embox
        call    get_ocr_mask
        ; acmd41  - с нужной маской вольтажа
        ; первый вызов возвращает OCR, следующие устанавливают вольтаж
        call    SD_SEND_OP_COND
        jnz     .mmc
        test    dword[eax + SDHC_RESP1_0], 0x80000000 ; check 31 bit
        jz      .set_acmd41
        ; for no sdio card  : cmd2 - get_CID
        ALL_SEND_CID           ; пока выбрасывает ошибку таймаута, а в виду отсутствия
                               ; правильной проверки irq всё виснит
        ; for all init card : cmd3 - get RCA
        call    SEND_RCA

        call    SEND_CSD

        call    SELECT_CARD

        test    [esi + SDHCI_CONTROLLER.card_reg_ocr], 0x40000000
        jnz     @f

        mov     ebx, 0x200 ; 512 byte
        call    SET_BLOCKLEN
@@:

        ; get size device  TODO: заменить на определения метода через OCR регистр
        test    dword[esi + SDHCI_CONTROLLER.card_reg_csd + 12], 0x400000  ;check version SCD ver2
        jz      @f

        call    GET_SDHC_SIZE
        jmp     .end_get_size
@@:
        test    dword[esi + SDHCI_CONTROLLER.card_reg_csd + 12], 0x800000  ;check version SCD ver3
        jz      @f

        call    GET_SDUC_SIZE
        jmp     .end_get_size
@@:
        test    dword[esi + SDHCI_CONTROLLER.card_reg_csd + 12], 0xC00000  ;check version SCD ver3
        jnz     .err ; no get size device

        call    GET_SDSC_SIZE

.end_get_size:
        DEBUGF  1,"SDHCI: Sectors card = %d:%d\n",[esi + SDHCI_CONTROLLER.sector_count + 4],\
                                                  [esi + SDHCI_CONTROLLER.sector_count]

        mov     ebx, [esi + SDHCI_CONTROLLER.divider25MHz]
        call    set_SD_clock

        ; set timeout reg
        mov     byte[eax + 0x2E], 1110b ; set max

        ;DEBUGF  1,"SDHCI: TEST1 SDMA - read first sector\n"
        ;call    TEST_SDMA_R

        ;DEBUGF  1,"SDHCI: TEST2 SDMA - read first sector\n"
        ;call    TEST_SDMA_R_MUL

        ; Инициализация карты завершена. Изменение настроек интерфейса
        ; set 4bit mode else card and controler suppoted it mode.

        ; set bus speed mode

        ; set new clock. до 50 МГц


        ; set interrupt TODO: Сделать нормально!!!
        or      dword[eax + SDHC_INT_MASK], 0xFFFFFFFF
        or      dword[eax + SDHC_SOG_MASK], 0xFFFFFFFF


        ;TODO: get SCR register

        stdcall add_card_disk, sdcard_disk_name
        mov     [esi + SDHCI_CONTROLLER.type_card], 2
        DEBUGF  1,'SDHCI: Card init - Memory card\n'
        ret

; SDIO initalization
.sdio:
        xor     ebx, ebx
        call    get_ocr_mask
        jz      .err
@@:
        ; SDIO initialization (cmd5)set voltage window
        call    IO_SEND_OP_COND
        jnz     .err
        test    dword[eax + SDHC_RESP1_0], 0x80000000 ; check 31 bit
        jz      @b

        call    SEND_RCA

        mov     [esi + SDHCI_CONTROLLER.type_card], 1 ; sdio card
        DEBUGF  1,'SDHCI: Card init - SDIO card\n'
        DEBUGF  1,'SDHCI: SDIO card not supported. Power and clock stoped\n'
        and     dword[eax + SDHC_CTRL1], not 0x0100  ; stop power
        and     dword[eax + SDHC_CTRL2], not 0x04  ; stop SD clock

        ret


; MMC initalization
.mmc:
        ;определяем и настраиваем карту и контроллер
        ;cmd1
        ;TODO: НАЙТИ АЛГОРИТМ ИНИЦИАЛИЗАЦИИ MMC КАРТ!!!
        ;call    add_card_disk
        mov     [esi + SDHCI_CONTROLLER.type_card], 4
        and     dword[eax + SDHC_CTRL1], not 0x0100  ; stop power
        and     dword[eax + SDHC_CTRL2], not 0x04  ; stop SD clock

        DEBUGF  1,'SDHCI: Card not init\n'
        ret
.err:
        and     dword[eax + SDHC_CTRL1], not 0x0100  ; stop power
        and     dword[eax + SDHC_CTRL2], not 0x04  ; stop SD clock
        DEBUGF  1,'SDHCI: ERROR INIT CARD\n'
        ret
endp

proc thread_card_detect
        ;get event with data
        sub      esp, 6*4  ; 6*Dword
        mov      edi, esp
        invoke  GetEvent
        mov     edi, esp
        ;DEBUGF  1,'SDHCI: Get event code=%x [edi + 4]=%x, [edi + 8]=%x\n', [edi], [edi + 4], [edi + 8]
        mov     eax, dword[edi + 4] ; reg map
        mov     esi, dword[edi + 8] ;controller struct

        call    card_init
        ; destryct thread
        mov     eax, -1
        int     0x40
endp


proc card_destruct
        DEBUGF  1,'SDHCI: Card removed\n'
        ; удаляем диск из списка дисков если это диск
        test    ebx, 110b
        jz      .no_memory_card

        call    del_card_disk
.no_memory_card:
        ;TODO: очищаем все регистры связанные с этим слотом

        ;stop power and clock gen
        and     dword[eax + SDHC_CTRL1], not 0x0100  ; stop power
        and     dword[eax + SDHC_CTRL2], not 0x04  ; stop SD clock
        ret
endp

; TODO: Доделать систему обработки сигналов ошибки и переработать работу
; с сигналами результата работы команд(сейчас это очень плохо сделано).
; добавить(уже там) 2 поля, для хранения данных об полученном прерывании.
; + статус работы с контроллером(для блокировок)
proc sdhc_irq
        pusha
        mov     esi, [esp + 4 + 32] ;stdcall
        mov     eax,[esi + SDHCI_CONTROLLER.base_reg_map]
        ;DEBUGF  1,"SDHCI: INTRPT: %x \n", [eax + SLOT_INTRPT]
        DEBUGF  1,"SLOT_INT_STATUS: %x \n",[eax + SDHC_INT_STATUS]
        cmp    dword[eax + SDHC_INT_STATUS], 0
        jz      .fail

        mov     ecx, [eax + SDHC_INT_STATUS]
        mov     dword[esi + SDHCI_CONTROLLER.int_status], ecx
        mov     [eax + SDHC_INT_STATUS], ecx ; гасим прерывания

        test    dword[esi + SDHCI_CONTROLLER.int_status], INT_STATUS.CARD_INS
        jz      .no_card_inserted

        ; create thread for init card
        push     esi
        push     eax
        mov     ebx, 1
        mov     ecx, thread_card_detect
        mov     edx, 0 ; stack - for kernel mode kernel alloc 8Kb RAM
        invoke  CreateThread
        DEBUGF  1,"SDHCI: create thread tid=%x \n", eax
        test    eax, eax
        pop     ebx
        pop     ecx
        jz      .no_card_inserted
        ; send event for thread
        mov     [.event_struct + 4], ebx ; reg map
        mov     [.event_struct + 8], ecx ; sdhci_controller struct
        mov     esi, .event_struct
        ;DEBUGF  1,"SDHCI: send event tid=%x code[1]=%x code[2]=%x \n", eax, [.event_struct + 4], [.event_struct + 8]
        push    ecx
        push    ebx
        invoke  SendEvent
        ;DEBUGF  1,"SDHCI: Evend sended, eax=%x uid=%x \n", eax, ebx
        pop     eax
        pop     esi

.no_card_inserted:
        test    dword[esi + SDHCI_CONTROLLER.int_status], INT_STATUS.CARD_REM
        jz      .exit

        call    card_destruct
.exit:
        popa
        xor     eax, eax
        ret
.fail:
        popa
        xor     eax, eax
        inc     eax
        ret
.event_struct: ; 6*dword
        dd     0xff0000ff
        rd     5
endp

; get voltage mask for ACMD41 and CMD5
; IN: ebx - base data for OCR  esi,eax -standart fo this driver
; OUT: ebx - OCR
;      ZF - error mask(ebx[23:0]=0)
proc    get_ocr_mask
        or      ebx, [esi + SDHCI_CONTROLLER.card_reg_ocr] ; set mask sd card
        cmp     byte[eax + 0x29], 1011b ;1.8
        jnz     @f
        and     ebx, (1 shl 30) + 0x80 ; see OCR reg
@@:
        cmp     byte[eax + 0x29], 1101b ;3.0
        jnz     @f
        and     ebx, (1 shl 30) + (1 shl 17) ; see OCR reg
@@:
        cmp     byte[eax + 0x29], 1111b ;1.8
        jnz     @f
        and     ebx, (1 shl 30) + (1 shl 20) ; see OCR reg
@@:
        test    ebx, 0xffffff
        ret
endp

proc  TEST_SDMA_R
        or      dword[eax + SDHC_INT_MASK], 0xFFFFFFFF
        or      dword[eax + SDHC_SOG_MASK], 0xFFFFFFFF
        and     dword[eax + SDHC_CTRL1], not 11000b ; set SDMA mode
        mov     byte[eax + 0x2E], 1110b ; set max
        mov     ebp, eax
        invoke  KernelAlloc, 4096
        push    eax
        invoke  GetPhysAddr ; arg = eax
        xchg    eax, ebp
        mov     dword[eax], ebp;phys addr
        mov     dword[eax + 4], SD_BLOCK_SIZE
        ;(block_count shl) 16  + (sdma_buffer_boundary shl 12) + block_size
        mov     dword[eax + 8], 0 ; arg - num sector
        mov     dword[eax + 0xC], (((17 shl 8) + DATA_PRSNT + RESP_TYPE.R1 ) shl 16) + 010001b
@@:
        cmp     dword[esi + SDHCI_CONTROLLER.int_status], 0
        hlt
        jz      @b
        ;DEBUGF  1,"SDHCI: resp1=%x resp2=%x \n", [eax + SDHC_RESP1_0], [eax + SDHC_RESP3_2]
.wait_int:
        mov     dword[esi + SDHCI_CONTROLLER.int_status], 0
        hlt
        cmp     dword[esi + SDHCI_CONTROLLER.int_status], 0
        jz      .wait_int
        ;DEBUGF  1,"SDHCI: resp1=%x resp2=%x \n", [eax + SDHC_RESP1_0], [eax + SDHC_RESP3_2]
        pop     ebp
        test    dword[eax + SDHC_RESP1_0], 0x8000
        jnz     @f
        push    eax
        mov     dword[.ptr], ebp
        mov     ebx, .file_struct
        invoke  FS_Service
        pop     eax
@@:
        ret
.file_struct:
        dd 2
        dd 0
        dd 0
        dd 512
.ptr:   dd 0
        db '/tmp0/1/dump_first_sector',0

endp

;   Заметка к SDMA: Прерывание DMA возникает только при пересечении границы блока данных
; у меня это граница в 4кб
proc  TEST_SDMA_R_MUL
        or      dword[eax + SDHC_INT_MASK], 0xFFFFFFFF
        or      dword[eax + SDHC_SOG_MASK], 0xFFFFFFFF
        and     dword[eax + SDHC_CTRL1], not 11000b ; set SDMA mode
        mov     byte[eax + 0x2E], 1110b ; set max
        mov     ebp, eax
        invoke  KernelAlloc, 4096*0x800;128;4096*512
        push    eax
        push    eax
        invoke  GetPhysAddr ; arg = eax
        xchg    eax, ebp
        mov     dword[eax], ebp;phys addr
        mov     dword[eax + 4], ((8*0x800) shl 16) +  SD_BLOCK_SIZE
        ;(block_count shl) 16  + (sdma_buffer_boundary shl 12) + block_size
        mov     dword[eax + 8], 0;0x2000 ; arg - num sector
        mov     dword[eax + 0xC], (((18 shl 8) + DATA_PRSNT + RESP_TYPE.R1 ) shl 16) + CMD_TYPE.Multiple + 10101b
@@:
        cmp     dword[esi + SDHCI_CONTROLLER.int_status], 0
        hlt
        jz      @b
        ;DEBUGF  1,"SDHCI: resp1=%x resp2=%x \n", [eax + SDHC_RESP1_0], [eax + SDHC_RESP3_2]
.wait_int:
        mov     dword[esi + SDHCI_CONTROLLER.int_status], 0
        hlt
        cmp     dword[esi + SDHCI_CONTROLLER.int_status], 0
        jz      .wait_int
        test    dword[esi + SDHCI_CONTROLLER.int_status], 10b
        jnz     @f
        test    dword[esi + SDHCI_CONTROLLER.int_status], 1000b
        jz      @f

        xchg    eax, ebp
        mov     eax, dword[esp]
        add     eax, 4096
        mov     dword[esp], eax
        invoke  GetPhysAddr
        xchg    eax, ebp
        mov     dword[eax], ebp;phys addr

        jmp     .wait_int

        ;DEBUGF  1,"SDHCI: resp1=%x resp2=%x \n", [eax + SDHC_RESP1_0], [eax + SDHC_RESP3_2]
@@:
        pop     ebp
        pop     ebp
        test    dword[eax + SDHC_RESP1_0], 0x8000
        jnz     @f
        push    eax
        mov     dword[.ptr], ebp
        mov     ebx, .file_struct
        invoke  FS_Service
        pop     eax
@@:
        ret
.file_struct:
        dd 2
        dd 0
        dd 0
        dd 4096*0x800;128
.ptr:   dd 0
        db '/tmp0/1/dump_first_sector_mul',0

endp


; This function for working drivers and programs worked
; with SDIO interface.
proc service_proc stdcall, ioctl:dword
        ; 0 - get version
        ; 1 - get card count
        ; 2 - get card (hand + info(CID, CSD, RCA, OCR))
        ; 3 - set card width bus
        ; 4 - set card clock
        ; 5 - set card irq hand (for SDIO)
        ; 6 - look access card
        ; 7 - unlook access card
        ; 8 - call card func (for SDIO)
        ; 9 - capturing control controller
        ret
endp

drv_name:       db 'SDHCI',0

align 4
data fixups
end data

include_debug_strings
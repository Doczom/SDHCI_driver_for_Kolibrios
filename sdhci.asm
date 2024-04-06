;;      Copyright (C) 2022-2024, Mikhail Frolov aka Doczom
;; SD host controller driver.
;;
;;                 !!!!WARNING!!!!
;;  Драйвер работает только по спецификации 2.0 и тестируется только на
;; контроллере данной версии. Для контроллеров более новой версии драйвер
;; будет работать как с контроллером по спецификации версии 2.0. Функции
;; контроллера из за этого могут ограничены.

;; TODO list:
;; - fix output error read/write sectors
;; - add switch in High speed
;; - add API for SDIO
;;   - EXPORT cmd52    ?
;;   - EXPORT cmd53    ?
;;   - EXPORT and creat sdio_atached_irq
;;   - EXPORT function for set card and host param
;;   - EXPORT function for add listen on detect insert sdio card
;;           (как в юсб подсистеме)
;;   -
;; - add exit in erase exec function (jnz .err)
;; - add API for usermode programm
;; - add ADMA2
;; - add SDUC support

format PE native 0.05
entry START
use32

        DEBUG                   = 1
        __DEBUG__               = 1
        __DEBUG_LEVEL__         = 1  ; 1 = verbose, 2 = errors only


        DRIVER_VERSION          = 1  ;debug

; base SD registers
SDHC_SYS_ADDR   = 0x00
SDHX_BLK_CS     = 0x04

SDHC_CMD_ARG    = 0x08
SDHC_CMD_TRN    = 0x0c

;0x10-0x1f - Response
SDHC_RESP1_0    = 0x10
SDHC_RESP3_2    = 0x14
SDHC_RESP5_4    = 0x18
SDHC_RESP7_6    = 0x1C

SDHC_BUFFER     = 0x20

SDHC_PRSNT_STATE   = 0x24  ;word (12-15 , 26 Rsvd)
PRSNT_STATE:
  .CMD_INHIB_CMD   = 0x01 ; for test [eax + SDHC_PRSNT_STATE], SDHC_PRSNT_STATE.CMD_INHIB_CMD
  .CMD_INHIB_DAT   = 0x02
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

SDHC_CTRL2        = 0x2C
  clock_control   = 0x2c ;word
  timeout_control = 0x2e ;byte (using 0-3 bits)
  software_reset  = 0x2f ;byte (using 0-2 bits)
    .software_reset_for_all       = 0x01  ;1-reset 0-work
    .saftware_reset_for_cmd_line  = 0x02  ;1-reset 0-work
    .software_reset_for_dat_line  = 0x04  ;1-reset 0-work

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
    ; Если появилось прерывания подключения или отключения карты, нужно проверить это через регистр 0x24
    ;для отключения генерации прерываний записать в нужный бит единицу(через or например).
    .CARD_INS       = 0x40
    .CARD_REM       = 0x80
    .SDIO           = 0x0100
    .INT_A          = 0x0200 ; in 2 version spec not used
    .INT_B          = 0x0400 ; in 2 version spec not used
    .INT_C          = 0x0800 ; in 2 version spec not used
    ;.re_tuning_event = 0x1000
    ;.FX_event        = 0x2000
    ; 14 bit reserved
    .ERROR          = 0x8000   ; in all version specifications
    ; error interrupt
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
    .ADMA_ERR       = 0x0200 ; added in 2 version spec
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
    TO_CLK_UNIT     = (1 shl 7)
    MMC8_SUPPORT    = (1 shl 18)
    ADMA2_SUPPORT   = (1 shl 19)
    ADMA_SUPPORT    = (1 shl 20)
    HISPEED_SUPPORT = (1 shl 21)
    DMA_SUPPORT     = (1 shl 22)
    SUS_RES_SUPPORT = (1 shl 23)
    SUPPORT_3_3V    = (1 shl 24)
    SUPPORT_3_0V    = (1 shl 25)
    SUPPORT_1_8V    = (1 shl 26)
SDHC_CURR_CAPABILITY = 0x48 ; qword (using 0-23 32-39)

SDHC_FORCE_EVT  = 0x50
  force_event_register = 0x50 ;word (using 0-7 bits)
  force_event_register_for_interrupt_status = 0x52 ; word

SDHC_ADMA_ERR   = 0x54 ; byte (using 0-2 bits)
SDHC_ADMA_SAD   = 0x58

SDHC_VER_SLOT   = 0xfc ; block data
 SLOT_INTRPT    = 0xfc ;Slot interrupt status register 1 byte; 0xfd - reserved
 SPEC_VERSION   = 0xfe ; in map register controller(15-8 - vendor version; 7-0 - spec version)
 VENDOR_VERSION = 0xff

; PCI reg
PCI_CLASS_SDHCI = 0x0805 ;basic_class=0x08 sub_class=05
PCI_BAR0        = 0x10
PCI_BAR1        = 0x14
PCI_BAR2        = 0x18
PCI_BAR3        = 0x1C
PCI_BAR4        = 0x20
PCI_BAR5        = 0x14
PCI_IRQ_LINE    = 0x3C

PCI_slot_information = 0x40 ;0-2 first BAR 4-6 - number of Slots(counter BAR)
PCI_SDHCI_NO_DMA     = 0
PCI_SDHCI_DMA        = 1
PCI_SDHCI_VEND_IF    = 2


section '.flat' code readable writable executable

include 'drivers/proc32.inc'
include 'drivers/struct.inc'
include 'drivers/macros.inc'
include 'drivers/peimport.inc'
include 'drivers/fdo.inc'


include 'sdhc_cmd.inc'
include 'sdhc_disk.inc'
include 'sdhci_adma.inc'
include 'sdio.inc'
; structures
struct  RW_FUNC
        singe_read      rd 1
        multiple_read   rd 1
        singe_write     rd 1
        multiple_write  rd 1
ends

struct  SDHCI_DEVICE
        next            rd 1
        prev            rd 1
        dev             rd 1   ;
        bus             rd 1   ;
        state           rd 1   ;  bit flags
        irq_line        rd 1 ; rb
        dma_support     rd 1 ; rb
        slot_0          rd 1   ; ptr SDHCI_SLOT
        slot_1          rd 1
        slot_2          rd 1
        slot_3          rd 1
        slot_4          rd 1
        slot_5          rd 1
ends

struct  SDHCI_SLOT
        base_reg_map    rd 1 ;pointer to registers controller
        ;base_sdhc_reg   rd 1 ; offset for BAR
        ;count_bar_reg   rd 1 ; count BAR for this register
        state           rd 1   ;  bit flags
        ver_spec        rb 1 ; using 0 - 4  bits
        dma_support     rb 1 ; 0 - no DMA, 1 - yes DMA  2 - Vendor unique SD hoet controller

        ;irq_line        rd 1
        Capabilities    rd 2 ; qword - save Capabilities
        max_slot_amper  rd 2

        divider400KHz   rd 1 ; for SDCLK frequency Select
        divider25MHz    rd 1
        divider50MHz    rd 1

        type_card       rd 1 ; 0 - no card 1 - SD 2 - SDIO 4 - MMC(eMMC) 5+ - other
        ;dma_mode        rd 1 ; 0-sdma 1-adma1 2-adma2-32 3-adma2-64

        ; card data
        card_reg_ocr    rd 1 ; 32 bit
        SDIO_reg_ocr    rd 1 ; 32 bit
        card_reg_cid    rd 4 ; 128 bit 120 bit
        card_reg_csd    rd 4 ; 128 bit
        card_reg_rca    rw 1 ; rw 1   ; 16 bit
        card_reg_dsr    rw 1 ; rw 1 ;16 bit (optional) ; not using!!!
        card_reg_scr    rd 2 ; 64 bits
        card_reg_ssr    rd 16 ; 512bit

        pwd_leb         rb 1
        pwd             rb 512
        sector_count    rq 1  ; count rw sectors on SD\SDIO\MMC card
        disk_hand       rd 1  ; DISK*
        disk_name       rd 4  ; 16 byte for save path disk, example, 'sdhci0001',0
        memory_rw       RW_FUNC

        ; for working SDIO card
        sdio_service    rd 1 ; ptr to SDIO_SERVICE
        sdio_pdata      rd 1 ; DWORD for SDIO functions
        ;program_id      rd 1 ; tid thread for working with no memory cards

        ; to execute the command
        virt_addr_buff  rd 1 ; addr buffer for data
        int_status      rd 1 ; copy SDHC_INT_STATUS
                        rd 4 ; reserved
        status_control  rd 1 ; flags status controller(0x01 - get irq AND int_status good)
                             ; status for write\read  disk, global flags

ends

count_controller:       dd 0
list_controllers:
.next:       dd list_controllers ; pointer to first item list
.prev:       dd list_controllers ; pointer to last item list

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

        cmp     word[eax + PCIDEV.class + 1], PCI_CLASS_SDHCI
        jnz     .next_dev

        pusha
        call    sdhci_init
        popa
        jmp     .next_dev
.end_find:
        pop     eax
        xor     eax, eax
        cmp     eax, [count_controller]
        jz      .not_found

        DEBUGF  1,"SDHCI: Found %d controllers\n", [count_controller]
        invoke  RegService, drv_name, service_proc
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

        DEBUGF  1, "SDHCI: Stop working driver\n"
        xor     eax, eax
        pop     ebp edi esi ebx
        ret
endp

; args: eax - ptr PCIDEV
; no return
; NO SAVE REGISTERS
proc sdhci_init
        mov     esi, eax
        ; alloc memory for structure SDHCI_DEVICE
        invoke  KernelAlloc, sizeof.SDHCI_DEVICE
        test    eax, eax
        jz      .err_mem

        movzx   edx, [esi + PCIDEV.devfn]
        mov     [eax + SDHCI_DEVICE.dev], edx
        movzx   edx, [esi + PCIDEV.bus]
        mov     [eax + SDHCI_DEVICE.bus], edx
        mov     esi, eax ;save ptr SDHCI_DEVICE
        ; clear SDHCI_DEVICE.slotX items
        xor     edx, edx
        mov     ecx, 5 + 1
@@:
        mov     [eax + SDHCI_DEVICE.slot_0 + ecx*4 - 4], edx
        loop    @b

        ; add list
        ; TODO: add and use macro list_add_tail
        mov     edx, [list_controllers.prev]
        mov     [list_controllers.prev], esi
        mov     [eax + SDHCI_DEVICE.next], list_controllers
        mov     [eax + SDHCI_DEVICE.prev], edx
        mov     [edx], eax

        inc     dword[count_controller]

        ; Set Master and Memory bits, dunkaist
        pusha
        invoke  PciRead32, [esi + SDHCI_DEVICE.bus], [esi + SDHCI_DEVICE.dev], dword 4
        test    eax, 0x4 ; Test Master bit
        jnz     @f
        or      eax, 0x4 ; Set Master bit
        movi    ebx, 0x6
        and     ebx, eax
        cmp     ebx, 0x6 ; Test Master and Memory bits
        jz      @f
        or      eax, 0x6 ; Set Master and Memory bits
        invoke  PciWrite32, [esi + SDHCI_DEVICE.bus], [esi + SDHCI_DEVICE.dev], dword 4, eax
        ;invoke  PciRead32, [esi + SDHCI_DEVICE.bus], [esi + SDHCI_DEVICE.dev], dword 4
@@:
        popa
        ;  get DMA support in pci reg
        invoke  PciRead8, [esi + SDHCI_DEVICE.bus], [esi + SDHCI_DEVICE.dev], dword 9
        mov     byte[esi + SDHCI_DEVICE.dma_support], al
        cmp     al, PCI_SDHCI_VEND_IF
        ja      .err_interface

        ;create name for controller (/sdhciXXX0)
        sub     esp, 4*4 ; for name

        mov     dword[esp], 'sdhc'
        mov     dword[esp + 4], 'i000'  ; controller number
        mov     dword[esp + 8], '0'     ; slot number
        mov     eax, dword[count_controller]
        mov     ecx, 3
        mov     edi, 10 ; for div instruction
@@:
        xor     edx, edx
        div     edi
        add     byte[esp + 4 + ecx], dl
        dec     ecx
        test    eax, eax
        jnz     @b


        ;get count slot

        invoke  PciRead8, [esi + SDHCI_DEVICE.bus], dword[esi + SDHCI_DEVICE.dev], PCI_slot_information
        movzx   edx, al
        and     edx, 111b
        shr     eax, 4
        and     eax, 111b
        mov     ecx, edx
        add     ecx, eax
        cmp     ecx, 5
        ja      .err_count_slots
        push    edx ; save first BAR  ;save offset base register sdhc
        push    eax ;save count    ;save count working basical addres register

        DEBUGF  1,"SDHCI: base BAR: %x count BAR: %x\n", eax, edx

        xor     ecx, ecx
.add_new_slot:
        push    ecx
        ;  get BAR addr to slots(all slots)
        add     ecx, [esp + 4 + 4]
        add     ecx, PCI_BAR0
        invoke  PciRead32, dword [esi + SDHCI_DEVICE.bus], dword [esi + SDHCI_DEVICE.dev], ecx
        and     al, not 0Fh   ; not 0xff
        ;  check BAR
        test     eax, eax
        jz       .no_mmio

        ;  mapped mmio space
        invoke  MapIoMem, eax, 0x100, PG_SW+PG_NOCACHE  ;
        test    eax, eax
        jz      .no_mmio

        DEBUGF  1,"SDHCI: base address = %x \n", eax
        push    eax
        ;  alloc memory for structure SDHCI_SLOT
        invoke  KernelAlloc, sizeof.SDHCI_SLOT
        test    eax, eax
        pop     ecx   ; ecx - reg map
        jz      .not_memory
        mov     [eax + SDHCI_SLOT.base_reg_map], ecx
        mov     edx, [esp]
        mov     [esi + SDHCI_DEVICE.slot_0 + edx*4], eax

        ;  create name for slot (/sdhci000X)
        mov     edx, [esp + 4 + 4*2]
        mov     [eax + SDHCI_SLOT.disk_name], edx
        mov     edx, [esp + 4 + 4*2 + 4]
        mov     [eax + SDHCI_SLOT.disk_name + 4], edx
        mov     edx, [esp + 4 + 4*2 + 8]
        mov     [eax + SDHCI_SLOT.disk_name + 8], edx
        mov     edx, [esp + 4 + 4*2 + 12]
        mov     [eax + SDHCI_SLOT.disk_name + 12], edx
        mov     edx, [esp]
        add     byte[eax + SDHCI_SLOT.disk_name + 8], dl ; set slot in name

        ;  copy dma_support in SDHCI_SLOT

        mov     edx, [esi + SDHCI_DEVICE.dma_support]
        mov     [esi + SDHCI_SLOT.dma_support], dl

        ;  ALL RESET slots(all slots)
        mov     edx, [eax + SDHCI_SLOT.base_reg_map]
        inc     byte[edx + software_reset]
@@:
        test    byte[edx + software_reset], 0xFF
        jnz     @b
        DEBUGF  1,"SDHCI: slot resetting \n"

        pop     ecx
        inc     ecx
        cmp     ecx, dword[esp]
        ja      .end_reset
.not_memory: ; TODO не тут, это должно полностью прекращать работу драйвера
.no_mmio:
        pop     ecx
        mov     [esi + SDHCI_DEVICE.slot_0 + ecx*4], 0
        inc     ecx
        cmp     ecx, dword[esp]
        jbe     .add_new_slot

.end_reset:
        ;Attach IRQ
        invoke  PciRead8, dword [esi + SDHCI_DEVICE.bus], dword [esi + SDHCI_DEVICE.dev], PCI_IRQ_LINE ;al=irq
        movzx   eax, al
        mov     [esi + SDHCI_DEVICE.irq_line], eax ;save irq line
        invoke  AttachIntHandler, eax, sdhc_irq, esi ;esi = pointre to controller struct

        xor     ecx, ecx
.loop:
        DEBUGF  1,"SDHCI: ecx=%x slotX=%x\n", ecx, [esi + SDHCI_DEVICE.slot_0 + ecx*4]
        cmp     dword[esi + SDHCI_DEVICE.slot_0 + ecx*4], 0
        jz      .skip_slot
        pusha
        mov     esi, [esi + SDHCI_DEVICE.slot_0 + ecx*4]
        mov     eax, [esi + SDHCI_SLOT.base_reg_map]
        ; call sdhci_slot_init
        call    sdhci_slot_init
        test    eax, eax
        jz      @f
        ; IF NOT sdhci_slot_init() THEN free memory for SDHCI_SLOT
        ;     TODO: free mapio and free slotX in SDHCI_DEVICE
@@:     ;DEBUGF  1,"SDHCI_SLOT_INIT: error code =%d \n", eax
        popa
.skip_slot:
        inc     ecx
        cmp     ecx, [esp]
        jbe     .loop

        add     esp, 4*4 + 4*2
        ret

.err_first_bar:
.err_count_slots:
        add     esp, 4*4
.err_interface:
.err_mem:
        ret
endp

;init controller, set base value, add interrupt function, set stucture for controller
; in: esi - ptr to SDHCI_SLOT
;     eax - ptr base reg map
; out: eax - error code 0 - good; other - init error code
proc sdhci_slot_init
        mov     [esi + SDHCI_SLOT.type_card], 0
        ; save registers Capabiliti and  Max Current Capabilities
        mov     ebx, [eax + SDHC_CAPABILITY]
        mov     [esi + SDHCI_SLOT.Capabilities], ebx
        mov     ebx, [eax + SDHC_CAPABILITY + 4]
        mov     [esi + SDHCI_SLOT.Capabilities + 4], ebx
        DEBUGF  1,"SDHCI:Capabilities %x %x\n",[esi + SDHCI_SLOT.Capabilities + 4],[esi + SDHCI_SLOT.Capabilities]

        mov     ebx, [eax + SDHC_CURR_CAPABILITY]
        mov     [esi + SDHCI_SLOT.max_slot_amper], ebx
        mov     ebx, [eax + SDHC_CURR_CAPABILITY + 4]
        mov     [esi + SDHCI_SLOT.max_slot_amper + 4], ebx
        DEBUGF  1,"SDHCI:Amper capabilities %x %x\n",[esi + SDHCI_SLOT.max_slot_amper + 4],[esi + SDHCI_SLOT.max_slot_amper]

        ; get the values of frequency dividers
        push    eax
        mov     eax, [esi + SDHCI_SLOT.Capabilities]
        shr     eax, 8
        and     eax, 11111111b  ; 1111 1111
        mov     ebx, 25
        xor     edx, edx
        div     ebx ; 25 Mhz
        bsr     ecx, eax
        xor     edx, edx
        bsf     edx, eax
        cmp     ecx, edx
        jnz     @f
        dec     ecx
@@:
        xor     edi, edi
        bts     edi, ecx
        mov     dword[esi + SDHCI_SLOT.divider25MHz], edi
        DEBUGF  1,'25MHz : %u\n', edi
        shr     edi, 1   ; +- десять
        mov     dword[esi + SDHCI_SLOT.divider50MHz], edi
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
        mov     dword[esi + SDHCI_SLOT.divider400KHz], edi
        DEBUGF  1,'400KHz : %u\n', edi

        pop     eax
        ; Set values in Host Control Register

        ;Set values in host control 2
        ;set 0x2e

        ; set Wekeup_control
        or      byte[eax + Wekeup_control], 111b

        ; set interrupt mask for detect insert/remove crad,
        ; using CMD and DAT command, but not using card interrupt
        mov     eax, [esi + SDHCI_SLOT.base_reg_map]
        or      dword[eax + SDHC_INT_MASK], INT_STATUS.ALL_ERROR \
                                          + INT_STATUS.CARD_INS \
                                          + INT_STATUS.CARD_REM \
                                          + INT_STATUS.CMD_DONE \
                                          + INT_STATUS.DAT_DONE \
                                          + INT_STATUS.DMA_EVT  \
                                          + INT_STATUS.BUF_WR_RDY \
                                          + INT_STATUS.BUF_RD_RDY

        or      dword[eax + SDHC_SOG_MASK], INT_STATUS.ALL_ERROR \
                                          + INT_STATUS.CARD_INS \
                                          + INT_STATUS.CARD_REM \
                                          + INT_STATUS.CMD_DONE \
                                          + INT_STATUS.DAT_DONE \
                                          + INT_STATUS.DMA_EVT  \
                                          + INT_STATUS.BUF_WR_RDY \
                                          + INT_STATUS.BUF_RD_RDY
        DEBUGF  1,'SDHCI: Enable insert and remove interrupt\n'

        ; detected card in slot
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
        and     dword[eax + SDHC_CTRL2], 0xffff0000 ; clear and stop clock
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
        and     dword[esi + SDHCI_SLOT.card_reg_rca], 0
        and     dword[esi + SDHCI_SLOT.disk_hand], 0
        and     dword[esi + SDHCI_SLOT.sdio_service], 0
        ; Включить питание (3.3В - не всегда) максимально возможное для хоста
        ; дай бог чтоб не сгорело ничего
        mov     ebx, [esi + SDHCI_SLOT.Capabilities]
        shr     ebx, 24
        and     ebx, 111b ;26bit - 1.8  25bit - 3.0  24bit - 3.3
        bsf     ecx, ebx  ;ecx= 0 for 3.3, 1 for 3.0 , 2 for 1.8
        jz      .err
        mov     edx, 111b
        sub     edx, ecx  ; see format data this register in specs
        shl     edx, 1
        or      edx, 0x01   ; for start power card
        shl     edx, 8 ; offset 0x29
        or      dword[eax + SDHC_CTRL1], edx
        DEBUGF  1,'SDHCI: SDHC_CTRL1= %x \n',[eax + SDHC_CTRL1]
        DEBUGF  1,'SDHCI: Питание включено, дай бог чтоб ничего не сгорело \n'

        ; running clock gen on 400kHz
        mov     ebx, [esi + SDHCI_SLOT.divider400KHz]
        call    set_SD_clock
        ; clear SDHC_CTRL1
        and     dword[eax + SDHC_CTRL1], 11000b + 0x0f00 ;оставляем только dma режим и power control
        and     dword[eax + SDHC_CTRL1], not 10b

        ;; !!! Begin process init card !!!

        GO_IDLE_SATTE

        call    SEND_IF_COUND
        ;DEBUGF  1,"SDHCI: CMD5 - check SDIO\n"
        xor     ebx, ebx ; arg cmd, zero to get voltage mask and to check SDIO functions
        call    IO_SEND_OP_COND; 0 - test voltage mask to check SDIO interface, ZF=1-sdio
        jz      .sdio

        mov     [esi + SDHCI_SLOT.card_reg_ocr], 0 ;OCR_REG.CCS
.set_acmd41:
        ; TODO: Add timeout on 10 ms, see code embox
        call    get_ocr_mask
        ; first call retuning OCR, other call set voltage
        call    SD_SEND_OP_COND
        jnz     .mmc
        test    dword[eax + SDHC_RESP1_0], OCR_REG.Busy
        jz      .set_acmd41

        ALL_SEND_CID

        call    SEND_RCA

        call    SEND_CSD

        call    SELECT_CARD

        ; set block length for SDSC
        test    [esi + SDHCI_SLOT.card_reg_ocr], OCR_REG.CCS
        jnz     @f
        mov     ebx, SD_BLOCK_SIZE
        call    SET_BLOCKLEN
@@:
        ; get size device
        test    dword[esi + SDHCI_SLOT.card_reg_ocr], OCR_REG.CO2T
        jz      @f

        call    GET_SDUC_SIZE
        jmp     .end_get_size
@@:
        test    dword[esi + SDHCI_SLOT.card_reg_ocr], OCR_REG.CCS
        jz      @f

        call    GET_SDHC_SIZE
        jmp     .end_get_size
@@:
        call    GET_SDSC_SIZE

.end_get_size:
        DEBUGF  1,"SDHCI: Sectors card = %d:%d\n",[esi + SDHCI_SLOT.sector_count + 4],\
                                                  [esi + SDHCI_SLOT.sector_count]

        ; set timeout reg
        mov     byte[eax + 0x2E], 1110b ; set max

        ; get SCR register
        ; Примечание: регистр передаётся и записывается с конца побайтно
        ; то есть 63-56, 55-48. и тд
        call    SEND_SCR
        jnz     .err

        ; check supported 4-bit mode
        test    word[esi + SDHCI_SLOT.card_reg_scr], 0x500
        jz      .no_4bit_mode
        ; acmd6. set 4bit mode
        mov     ebx, 10b ;4bit mode
        call    SET_BUS_WIDTH
        jnz     .err
        ; set flag in register controller
        or      dword[eax + SDHC_CTRL1], 10b
        DEBUGF  1,'SDHCI: set 4bit mode\n'
; TODO: check this code
        mov     ecx, 0xffff
@@:
        dec     ecx
        jnz     @b
; end
.no_4bit_mode:

        ; frequency increase up to 25 MHz
        mov     ebx, [esi + SDHCI_SLOT.divider25MHz]
        call    set_SD_clock

        ; switch in high speed
        ; check support high speed in host
        test    [esi + SDHCI_SLOT.Capabilities], HISPEED_SUPPORT
        jz      .no_high_speed
        ; check SD_SPEC in SCR register.
        ; if spec >= 1.10 then high speed supported
        test     byte[esi + SDHCI_SLOT.card_reg_scr], 11b
        jz      .no_high_speed

        ; cmd6
        invoke  KernelAlloc, 512/8
        test    eax, eax
        jz      .err
        ;call    SWITCH_FUNC
        jnz     .no_high_speed

        ; set flag in register controller
        or      dword[eax + SDHC_CTRL1], 100b

        ;   set new clock
        mov     ebx, [esi + SDHCI_SLOT.divider50MHz]
        call    set_SD_clock
.no_high_speed:

        push    esi
        add     dword[esp], SDHCI_SLOT.disk_name
        call    add_card_disk

        mov     [esi + SDHCI_SLOT.type_card], 1
        DEBUGF  1,'SDHCI: Card init - Memory card\n'
        ret

.sdio:
        ; SDIO initialization (cmd5)set voltage window
        call    get_ocr_mask
        call    IO_SEND_OP_COND
        jnz     .err
        test    dword[eax + SDHC_RESP1_0], OCR_REG.Busy
        jz      .sdio
        mov     ecx, [esi + SDHCI_SLOT.card_reg_ocr]
        mov     [esi + SDHCI_SLOT.SDIO_reg_ocr], ecx

        mov     [esi + SDHCI_SLOT.type_card], 2 ; sdio card
        ; check MP flag
        test    [esi + SDHCI_SLOT.SDIO_reg_ocr], OCR_REG.MP
        jz      .no_combo_card
        ;  acmd41 for combo card
        ;  cmd2
        ALL_SEND_CID
        mov     [esi + SDHCI_SLOT.type_card], 3 ; combo card
.no_combo_card:

        call    SEND_RCA

        call    SELECT_CARD
        ; get CCCR data (SD, SDIO, CCCR version)
        ;  set 4bit mode
        ;  set hidn speed
        ;  set power mode
        ; get CIS for CCCR
        ; get FBR and CIS for this FBR

        ; find SDIO service
        and     [esi + SDHCI_SLOT.sdio_service], 0
        and     [esi + SDHCI_SLOT.sdio_pdata], 0
        mov     ecx, [sdio_drv_list]
.sdio_find_new:
        cmp     ecx, sdio_drv_list
        jz      .sdio_end_find

        mov     edx, [ecx + SDIO_SERVICE.sdio_func]
        push    ecx
        push    esi
        call    dword[edx + SDIO_SERVICE_FUNC.check_fbr]
        pop     ecx
        test    eax, eax
        jz      .sdio_find_new
        mov     [esi + SDHCI_SLOT.sdio_service], ecx
        mov     [esi + SDHCI_SLOT.sdio_pdata], eax
        mov     eax, [esi + SDHCI_SLOT.base_reg_map]
        DEBUGF  1,'SDHCI: Card init - SDIO card\n'
        ret
.sdio_end_find:
        mov     eax, [esi + SDHCI_SLOT.base_reg_map]
        DEBUGF  1,'SDHCI: SDIO card not supported. Power and clock stoped\n'
        and     dword[eax + SDHC_CTRL1], not 0x0100  ; stop power
        and     dword[eax + SDHC_CTRL2], not 0x04  ; stop SD clock
        ret


; MMC initalization
; see https://github.com/Stichting-MINIX-Research-Foundation/minix/blob/master/minix/drivers/storage/mmc/emmc.c
.mmc:
        GO_IDLE_SATTE
        ; cmd1
        ; goto cmd1
        ; cmd 2
        ; cmd 3
        ; cmd 9
        ; cmd 7
        ; cmd 8 !!! SEND_EXT_CSD
        ; cmd 6 <- set hign speed
        ; Wait for the (optional) busy signal.
        ; /* CMD13. Check the result of the SWITCH operation. */
        ; ...
        ; cmd16 <- set block length 512 byte
        ;TODO: НАЙТИ АЛГОРИТМ ИНИЦИАЛИЗАЦИИ MMC КАРТ!!!
        ;stdcall add_card_disk
        mov     [esi + SDHCI_SLOT.type_card], 4
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

; Creat new kernel thread for execute function
;IN: eax - bar
;    esi - ptr SDHCI_SLOT
;    ecx - ptr to called function
;OUT: -
proc call_func_thread

        sub     esp, 5*4 ;data for event struct
        push    0xff0000ff
        mov     [esp + 4], eax  ; reg map
        mov     [esp + 8], esi  ; sdhci_controller struct
        mov     [esp + 12], ecx ; addr function

        pusha
        mov     ebx, 1
        mov     ecx, .new_thread
        xor     edx, edx ; stack - for kernel mode kernel alloc 8Kb RAM

        invoke  CreateThread
        test    eax, eax
        jz      .exit

        ; send event for thread
        lea     esi, [esp + (8*4)] ; esi = ptr to struct event
        invoke  SendEvent
.exit:
        popa
        add     esp, 6*4
        ret
.new_thread:
        ;get event with data
        sub      esp, 6*4  ; 6*Dword
        mov      edi, esp
        invoke  GetEvent
        mov     edi, esp
        ;DEBUGF  1,'SDHCI: Get event code=%x [edi + 4]=%x, [edi + 8]=%x\n',\
        ;                                    [edi], [edi + 4], [edi + 8]
        mov     eax, dword[edi + 4] ; reg map
        mov     esi, dword[edi + 8] ;controller struct

        call   dword[edi + 12]
        ; destryct thread
        mov     eax, -1
        int     0x40
endp


proc card_destruct
        DEBUGF  1,'SDHCI: Card removed\n'

        cmp     dword[esi + SDHCI_SLOT.disk_hand], 0
        jz      .no_memory_card

        invoke  DiskDel, [esi + SDHCI_SLOT.disk_hand]
        mov     eax, [esi + SDHCI_SLOT.base_reg_map]
.no_memory_card:
        cmp     dword[esi + SDHCI_SLOT.sdio_service], 0
        jz      .no_sdio

        push    eax
        push    [esi + SDHCI_SLOT.sdio_pdata]
        mov     ecx, [esi + SDHCI_SLOT.sdio_service]
        mov     ecx, [ecx + SDIO_SERVICE.sdio_func]
        call    dword[ecx + SDIO_SERVICE_FUNC.close_card]
        pop     eax

        and     dword[esi + SDHCI_SLOT.sdio_service], 0
.no_sdio:
        ;TODO: очищаем все регистры связанные с этим слотом
        mov     [esi + SDHCI_SLOT.disk_hand], 0
        mov     [esi + SDHCI_SLOT.type_card], 0
        ;stop power and clock gen
        and     dword[eax + SDHC_CTRL1], not 0x0100  ; stop power
        and     dword[eax + SDHC_CTRL2], not 0x04  ; stop SD clock
        ret
endp

; TODO: Доделать систему обработки сигналов ошибки и переработать работу
; с сигналами результата работы команд(сейчас это очень плохо сделано).
; + статус работы с контроллером(для блокировок)
proc sdhc_irq c pdata:dword
        pusha
        mov     eax, [pdata]
        xor     edx, edx
@@:
        cmp     [eax + SDHCI_DEVICE.slot_0 + edx*4], 0
        jnz     .found
        inc     edx
        cmp     edx, 5
        ja      .fail
        jmp     @b

.found:
        mov     ecx, [eax + SDHCI_DEVICE.slot_0 + edx*4]
        mov     ecx, [ecx + SDHCI_SLOT.base_reg_map]  ; get base addr slot0
        mov     cx, word[ecx + SLOT_INTRPT]
        and     cx, 111b ;clear
        bsf     dx, cx
        jz      .fail
        movzx   edx, dx
        mov     esi, [eax + SDHCI_DEVICE.slot_0 + edx*4]
        test    esi, esi
        jz      .fail
        mov     eax, [esi + SDHCI_SLOT.base_reg_map]
        ;DEBUGF  1,"SDHCI: INTRPT: %x \n", [eax + SLOT_INTRPT]
        ;DEBUGF  1,"SLOT_INT_STATUS: %x \n",[eax + SDHC_INT_STATUS]
        cmp    dword[eax + SDHC_INT_STATUS], 0
        jz      .fail

        ; send request on interrupt for stop generated irq signal
        mov     ecx, [eax + SDHC_INT_STATUS]
        mov     dword[esi + SDHCI_SLOT.int_status], ecx
        mov     [eax + SDHC_INT_STATUS], ecx

        test    dword[esi + SDHCI_SLOT.int_status], INT_STATUS.CARD_INS
        jz      .no_card_inserted

        mov      ecx, card_init
        call     call_func_thread

.no_card_inserted:
        test    dword[esi + SDHCI_SLOT.int_status], INT_STATUS.CARD_REM
        jz      @f;.exit

        mov      ecx, card_destruct
        call     call_func_thread

@@:
        ; check INT_STATUS.Error + check command or transfer complate
        test    dword[esi + SDHCI_SLOT.int_status], INT_STATUS.ERROR\
                                                  + INT_STATUS.DAT_DONE\
                                                  + INT_STATUS.CMD_DONE
        jnz     .sdio_int
        ; check dma
        test    dword[esi + SDHCI_SLOT.int_status], INT_STATUS.DMA_EVT
        jz      .exit
        ; dma int - set new phys addr
        mov     dword[esi + SDHCI_SLOT.int_status], 0
        and     dword[esi + SDHCI_SLOT.virt_addr_buff], -4096
        add     dword[esi + SDHCI_SLOT.virt_addr_buff], 4096
        mov     ecx, dword[esi + SDHCI_SLOT.virt_addr_buff]
        xchg    eax, ecx
        invoke  GetPhysAddr
        xchg    eax, ecx
        mov     dword[eax + SDHC_SYS_ADDR], ecx
        jmp     .exit

.sdio_int:
        test    dword[esi + SDHCI_SLOT.int_status], INT_STATUS.SDIO
        jz      .exit

        cmp     dword[esi + SDHCI_SLOT.sdio_service], 0
        jz      .exit

        push    eax

        push    [eax + SDHCI_SLOT.sdio_pdata]
        mov     ecx, [eax + SDHCI_SLOT.sdio_service]
        mov     ecx, [ecx + SDIO_SERVICE.sdio_func]
        call    dword[ecx + SDIO_SERVICE_FUNC.int_handler]

        pop     eax
.exit:
        popa
        xor     eax, eax
        ret
.fail:
        popa
        xor     eax, eax
        inc     eax
        ret
endp

; get voltage mask for ACMD41 and CMD5
; IN: esi,eax -standart fo this driver
; OUT: ebx - OCR
;      ZF - error mask(ebx[23:0]=0)
proc    get_ocr_mask
        ; set mask sd card
        or      dword[esi + SDHCI_SLOT.card_reg_ocr], OCR_REG.CCS + OCR_REG.CO2T
        mov     ebx, dword[esi + SDHCI_SLOT.card_reg_ocr]
        cmp     byte[eax + 0x29], 1011b ;1.8
        jnz     @f
        and     ebx, OCR_REG.CCS + OCR_REG.CO2T + 0x80 ; see OCR reg
@@:
        cmp     byte[eax + 0x29], 1101b ;3.0
        jnz     @f
        and     ebx, OCR_REG.CCS + OCR_REG.CO2T + (1 shl 17) ; see OCR reg
@@:
        cmp     byte[eax + 0x29], 1111b ;1.8
        jnz     @f
        and     ebx, OCR_REG.CCS + OCR_REG.CO2T + (1 shl 20) ; see OCR reg
@@:
        test    ebx, 0xffffff
        ret
endp

; This function for working drivers and programs worked
; with SDIO interface.
proc service_proc stdcall, ioctl:dword
        pusha
        mov     eax, [ioctl]
        mov     ecx, [eax + IOCTL.io_code]
        cmp     ecx, .table_size
        jae     .err_exit

        jmp     dword[.table + ecx*4]
.table:
        dd      .get_version
        dd      .get_device
        dd      .get_slot
        dd      .get_sdio_export_func
.table_size = ($ - .table)/4

; Get version driver
;     IN:  IOCTL.out_size = 4,
;          IOCTL.io_code = 0
;     OUT: [IOCTL.output] = DRIVER VERSION
.get_version:
        cmp     dword[eax + IOCTL.out_size], 4
        jnz     .err_exit

        mov     ecx, [eax + IOCTL.output]
        mov     dword[ecx], DRIVER_VERSION
        jmp     .exit

; Get SDHCI_DEVICE struct
;     IN: IOCTL.out_size = sizeof.SDHCI_DEVICE,
;         [IOCTL.input] = handle or ZERO for get root handle
;     OUT: [IOCTL.output] = struct SDHCI_DEVICE or
;                           handle root list
.get_device:
        cmp     dword[eax + IOCTL.inp_size], 4
        jnz     .err_exit

        mov     ecx, [eax + IOCTL.input]
        mov     ecx, [ecx]

        mov     edi, [eax + IOCTL.output]

        test    ecx, ecx
        jz      .get_device.root

        mov     esi, ecx  ;save handle struct

        cmp     ecx, list_controllers
        jz      @f

        cmp     dword[eax + IOCTL.out_size], sizeof.SDHCI_DEVICE
        jb     .err_exit

        mov     ecx, sizeof.SDHCI_DEVICE
        rep movsb

        jmp     .exit
  @@:
        cmp     dword[eax + IOCTL.out_size], 8 ; for 2 ptr on root list
        jb      .err_exit

        movsd
        movsd
        jmp     .exit

  .get_device.root:
        cmp     dword[eax + IOCTL.out_size], 4 ; for handle on root list
        jb      .err_exit

        mov     dword[edi], list_controllers
        jmp     .exit

; Get SDHCI_SLOT struct
;     IN: IOCTL.out_size = sizeof.SDHCI_SLOT,
;         [IOCTL.input] = handle
;     OUT: [IOCTL.output] = struct SDHCI_SLOT
.get_slot:
        cmp     dword[eax + IOCTL.inp_size], 4
        jnz     .err_exit

        mov     esi, [eax + IOCTL.input]
        mov     esi, [esi]

        mov     edi, [eax + IOCTL.output]

        cmp     dword[eax + IOCTL.out_size], sizeof.SDHCI_SLOT
        jnz     .err_exit

        mov     ecx, sizeof.SDHCI_SLOT
        rep movsb

        jmp     .exit

; 3 - get_sdio_export_func
;     IN: IOCTL.out_size = 4
;     OUT: [IOCTL.output] = prt to table export SDIO function this driver.
.get_sdio_export_func:
        cmp     dword[eax + IOCTL.out_size], 4
        jnz     .err_exit

        mov     ecx, [eax + IOCTL.output]
        mov     dword[ecx], export_sdio_api

.exit:
        popa
        xor     eax, eax
        ret
.err_exit:
        popa
        mov     eax, 1
        ret
endp

drv_name:       db 'SDHCI',0

align 4
data fixups
end data

include_debug_strings
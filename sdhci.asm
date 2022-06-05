;;      Copyright (C) 2022, Michail Frolov(aka Doczom)
;; SD host controller driver.
;;
;;                 !!!!��������!!!!
;;  ������� �������� ������ �� ������������ 2.0 � ����������� ������ ��
;; ����������� ������ ������. ��� ������������ ����� ����� ������ �������
;; ����� �������� ��� � ������������ �� ������������ ������ 2.0. �������
;; ����������� �� �� ����� ����� ����������.

format PE native
entry START
use32
;;;                            ;;;
;                                ;
;  Driver for SD host controller ;
;                                ;
;;;                            ;;;
; ��� ������� ��� ������ � ������� �� sd ������ � �������� ��� ��� ����-��
; ��� ������������� ������� ������� ���������� ��������� ��� ���������
; ��������� ��� ���������� ����������, ��������� �������� ������������� ����� ���
; ����������� ��� ���������� �����
        DEBUG                   = 1
        __DEBUG__               = 1
        __DEBUG_LEVEL__         = 1             ; 1 = verbose, 2 = errors only


        API_VERSION             = 0  ;debug

        STRIDE                  = 4      ;size of row in devices table

        SRV_GETVERSION          = 0
; base SD registers
;0x00-0x0f - SD Command Generation
; ���� ������ ����������� ������ 3 ��� host_version_4_enable=0, �� ��� ����� SDMA
;���� ������� �������� ����� ��������� ������ ��� �������� SDMA � 32������ ������ ����������.
;����� ���� ���������� ������������� �������� SDMA, ���� ������� ������ ��������� �� �����
;��������� ����������� ������� ������.
;������ � ����� �������� �������� ������ � ��� ������, ���� ���������� �� �����������(�.�. �����
;��������� ����������).������ ����� �������� �� ����� SDMA �������� ����� ������������ �������.
;������� ����� ������ ���������������� ���� ������� ����� �������� SDMA ��������.
;����� ���������  SDMA ��������� ��������� ����� ��������� ����������� ������� ����� ���� ������
;�� ����� ��������.
;
;���� ���������� ���������� ���������� DMA, ����� ��������� ������� ����� ��� ���������� �����
;��������. ������� ����� ������������� ��������� ��������� ����� ��������� ������� ������ � ����
;�������.����� ������������ ����� ������� ���� ����� ��������(03h), ���� ���������� �������������
;�������� SDMA.
;
;ADMA �� ���������� ���� �������
; ���� ������ ������ � host_version_4_enable=1 �� ��� 32bit block count(����� �������� �������� �
;������� 1.15) � ������ 4.0 ������������ ������ ��� �������� ������ ��� auto CMD23, ���� ���������
;��������� CMD23 ��� ���������� auto CMD23. ���� ���������� ����� ��������� �������� ����� ��������
;��� ������ �������� � ��� ���������� ���� �������� ������ ������������.������ � ����� �������� �����
;������������ ������ ����� ���������� �� �����������. ��� ������ ��� ���������� ����������
;����� ������� ������������ ��������
;=====
; ��� � ������� �������� ����� ��������: ����� �� ������� ��� ������ �� ����� ���-�� ����
; ��� ������ ������������� ������� ����� ������ ��������� sdma
SDHC_SYS_ADDR   = 0x00 ;32bit block Count(SDMA System Address)
;� ���� �������� ���������� 3 ��������.
;0-11 Transfer Block Size
; ���� ������� ���������� ������ ����� �������� ������ ��� CMD17, CMD18, CMD24, CMD25, CMD35.
; ����� ������ �������� �� 1 �� 2048 ����. �� �������� � �� ������ �� ����� ����������
; In case of memory? it shall be set up to 512 bytes( Reffer to Implementation Note in Section 1.7.2)
;12-14 SDMA Buffer Boundary
; ������ ���������� ���� ���������� ������ ��� SDMA ������.(4�� 8 �� 16 �� � ��. �� 512�)
; ����� ���������� ����� �� ����� ���������� ���� ������, ���������� ���������� DMA interrupt
; ���� ����������� ������� Transfer Complete interrupt �� DMA interrupt �� ���������
; ADMA �� ���������� ���� �������
; ��� �������� ������ �������������� ���� � �������� capabilities register
;  SDMA support = 1 � ���� � �������� Transfer Mode register   DMA Enable = 1
;16-31 16 bit block count Register
;   ������ ���� ����������� 4.10 ��������� ���������� ������ �� 32���(�� ������ 1.15)
;  ����� ���� 16 ���� 32 ������� �������� �������� ������ ������������ ��������� �������:
;   ���� Host version 4 enable = 0 ��� ���� ��� �������� 0�06 ������������ ��������� ��������
;  �� ���������� ������� 0�06
;   ����   Host version 4 enable = 1 � ������� 0x06 ���������� � ����, �� �������� 32������ �������
; ������������� 16/32 ������� �������� �������� ������ ��������, ���� Block Count Enable � ��������
; Trancfer Mode ���������� � 1, � ��� ��������� ������ ��� �������� ���������� ������.
; ������� ������ ���������� � ���� ������� �������� �� 1 �� ������������� ���������� ������.
; ���������� ��������� ��� �������� ����� ������ �������� ������ � ���������������, ����� ����������
; ��������� ����. ��������� �������� � ������������ � ����, ��� ����� �� ����������.
;  ������ � �������� �������� ������ ����� ��� ����������. ���� ��� ���� ������ ��������� � ������
; ���������� �������� ��������.
SDHX_BLK_CS     = 0x04
  Block_size_register = 0x04 ;word
  _16bit_block_count_register = 0x06 ;word
; �������� SD �������, ��������� � ����������� ����������� ������
SDHC_CMD_ARG    = 0x08 ; dword
  ARGUMENT0     = 0x08 ; word
  ARGUMENT1     = 0x0A ; word
; Transfer Mode Register
;   ���� ������� ������������ ��� �������� �������� �������� ������.������� ������ ���������� ���� �������
; ����� ����������� ������� � ��������� ������(������� Data Pressent Select � Command ��������), ��� �����
; ����������� Resume �������. ������� ������ ��������� ���� ������� ����� �������� ������ ��������������
; (� ���������� ���������� ������� ������������) � ������������ ��� ����� ����������� ������� ��������������
; ����� �������� ������ ������, ���������� ������ ����������� ������ �� ������ ��� ����� �������� �� �����
; ���������� ������.������ � ���� ������� ������ �������������� ����� Command Inhibit (DAT) ����� 1.
;            0 - DMA Enable
;                  ���� ��� ������������ ���������������� DMA ��� ������� � ������� 1.4 .DMA ����� ����
;                �������� ������ � ��� ������, ���� ��� �������������� � �������� ������������.
;                ���� �� ������� ������ DMA ����� ���� ������ � ������� DMA Select � Host Control ��������.
;                ���� DMA �� �������������� ���� ��� ������ ������ ���� ��������� � 0. ���� ���� ���
;                ���������� � 1, �� �������� DMA ������ ���������� ����� ������� ����� ���������� �
;                ������� ���� Command ��������(0x0f).
;            1 - Block Counter Enable
;                  ���� ��� ������������ ��� ��������� �������� �������� ������, ������� ����� ��������
;                ������ ��� �������� ���������� �����. ����� ���� ��� ������ 0, ������� �������� ������
;                �����������, ��� ������� ��� ���������� ����������� ��������(�� ������� 2-8)
;                  ���� �������� ������ ADMA2 ���������� ����� 65535 ������, ���� ��� ������ ����
;                  ���������� � 0. � ���� ������ ����� �������� ������ ������������ �������� ������������.
;            2 - Auto CMD12 Enable
;                  ��� ������������ �������� ������ ��������� ��������� ���������� ����� CMD12
;                ��� ��������� ����� ���� ���������� ��� ���������� ��� ������� ��� ���������� ����������
;                ������� ����� �� ������ ������������� ���� ���, ���� ������� �� ������� cmd12 ���
;                ��������� �������� ������.
;            4 - Data Transfer Direction Select
;                  ���� ��� ���������� ���������� �������� ������ �� DAT �����. 1-�������� ������ � �����
;                � ���� ����������, 0 ��� ���� ��������� �������.(1-������, 0-������)
;            5 - Multi/ Single Block Select
;                  ���� ��� ��������������� ��� ������ ������ ������������ �������� � ��������������
;                DAT �����.��� ����� ������ ������ ���� ��� ������ ���� ���������� � 0. ���� ���� ���
;                ���������� � 0 ��� ������������� ������������� Block Count �������.
SDHC_CMD_TRN    = 0x0c
  transfer_mode_register = 0x0c ;word (using 0-5 bits)
  ; ���� ������� ����� ���������� ������ ����� ���� ��� ��������� Command Inhibit(DAT) � (CMD),
  ;������ � ������� ���� ����� �������� �������� ��������� �������. ������� ���� ���������������
  ;�� ������ ����� ��������, ��������� ���������� �� �������� ������, ����� ����������� Command Inhibit
  ;(CMD)
  ;          0-1 - Response Type Select
  ;                   00 - No Response
  ;                   01 - Response Length 136
  ;                   10 - Response Length 48
  ;                   11 - Response Length 48 check Busy after response
  ;          3 - Command CRC Check Enable
  ;          4 - Command index Check Enable
  ;          5 - Data Present Select
  ;          6-7 - Command Type
  ;          8-13 - Command index
  command_register = 0x0e ;word  (using 0-13)

;0x10-0x1f - Response
SDHC_RESP1_0    = 0x10
SDHC_RESP3_2    = 0x14
SDHC_RESP5_4    = 0x18
SDHC_RESP7_6    = 0x1C

;0x20-0x23 - Buffer Data Port  ��� � ������� ��� ��������� �� �����
; ������ � ������ ����������� ����� �������� ����� 32bit Data Port �������(��� ������ 1.7)
SDHC_BUFFER     = 0x20

;0x24-0x2f - Host Control 1 and Others
  ; Present Satte Register (offset 0x24)
  ;  ������� ����� �������� ��������� ����������� ����� ���� 32 ������ �������.
  ; 0 - Command inhibit (CMD)
  ; 1 - Command inhibit (DAT)
  ; 2 - DAT Line Active
  ; 3-7 - Resevred
  ; 8 - Write Transfer Active
  ; 9 - Read Transfer Active
  ;      ���� ������ ������������ ��� �� DMA ������ ����������.
  ; 10 - Buffer Write Enable
  ;      ���� ������ ������������ ��� �� DMA ������ ����������.
  ; 11 - Buffer Read Enable
  ; 12-15 - Reserved
  ;      ���� ��� ���������� ��������� ����� ��� ��� � ����. � ���������� �������� ���������� �������
  ;    ���������� Card Inesrtion � Card Removed. ����� ����� �� ������ ������ �� ���.
  ; 16 - Card Inserted
  ; 17 - Card State Stable
  ; 18 - Card Detect Pin Level
  ;      ���� ��� ���������� ��� SDWP#. ������������� ������ �� ������ �������������� ��� ���� ������
  ;    � ��������������� ����.
  ; 19 - Write Protect Switch Pin Level (1 - Write enable SDWP#=1, 0 - Write protected SDWP#=0)
  ;
  ; 20-23 - DAT[0:3] Line Signal Level
  ;      ���� ������ ������������ ��� �������� ������ CMD ����� ��� �������������� ����� ������ � �������.
  ; 24 - CMD Line Signal Level
  ; 25-31 - Reserved
SDHC_PRSNT_STATE = 0x24  ;word (12-15 , 26 Rsvd)
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
  ; Host control Register (offset 0x28)
  ; 0 - LED Control  (0 - LED off; 1 - LED on)
  ;       ���� ��� ������������ ��� �������������� ������������� � ��� ����� �� �� �������� ����� ��
  ;     ����� ������� � SD �����. ���� �� ���������� �������� ��������� ������ SD, ���� ��� ����� ����
  ;     ���������� �� ����� ���� ���� ����������. ��� ������������� ������� ��������� ��� ������
  ;     ����������.
  ; 1 - Data Transfer Width (0 - 1 bit mode; 1 - 4 bit mode)
  ;       ���� ��� �������� ������ ������ ���� �����������. ������� ������ ��������� ��� ��� ����� ��
  ;     �������������� ������ ������ SD �����.
  ; 2 - High Speed Enable ( 0 - Normal Speed mode; 1 - High Speed mode)
  ;       ��� �������������� ���. ����� ���������� ��������� ������� Capabilities.
  ;     ���� ���� ��� ����� 0 - ������� �� 25 ���, ���� 1 - �� 50 ���.
  ; 3-4 - DMA Select
  ;       ����� ������ �� �������������� ������� DMA. ����� ���� ��������� ������� Capabilities.
  ;     ������������� ���������� DMA ������������ DMA Enable � �������� Transfer Mode.
  ;         00 - SDMA
  ;         01 - Reserved
  ;         10 - 32-bit Address ADMA2
  ;         11 - 64-bit Address ADMA2
  ; 6 - Card Detect Test Level (1 - Card Inserted; 0 - Not Card)
  ;       ���� ��� ������� ����� Card Detect Signal Selection ����� 1 � �� ��������� ���������
  ;     ����� ��� ���.
  ; 7 - Card Detect Signal Selection  (0 - SDCD# (for normal use); 1 - The Card Detect Test Level (for test purpose))
  ;       ���� ��� �������� �������� ����������� ����.
  ;     �������� �� ��� �������� � ������������(����� ���������� � ������).
SDHC_CTRL1      = 0x28
  ; Power Control Regstre (offset 29h)
  ; 0   -  SD Bus Power for VDD1
  ;           ���� ���� ���������� �������� No Card ���������, �� ���� ���� ���� ��������
  ; 1-3 -  SD Bus Voltage Select for VDD1
  ;          ���� ��� ����� ���� ���������� ���� � �������� capabilities  �������� 1.8V VDD2 Support
  ;        ���������� � 1.
  ;           101 - 1.8V
  ;           110 - 3.0V
  ;           111 - 3.3V
  Power_control = 0x29  ; byte (using 0-3 bits)
  ;
  block_gap_control = 0x2a ;byte (using 0-3 bits)
;   ������� ������ ������������ ������� �� SD ���� ������������ SD Bus Power � Power Control, when wake
; up event via Card Interrupt is desired.
;   ��� ��� ������� �, � ������ ������������ ��� ����� ��� ���� ����� ������ ���������� �����/���� �����.
; � FN_WUS � �������� CIS ���������� ��� 00 ���� ������� ��������.
;       00 - Wakeup Event Enable On Card Intwrrupt.
;       01 - Wakeup Event Enable On SD Card Insertion
;       02 - Wakeup Event Enable On SD Card Removal
  Wekeup_control = 0x2b  ;byte (using 0-2 bits)

; 0x2c - SDHC_CTRL2
; ��� ������������� ���������� ��������� ���� SDCLK/RCLK Frequency Select � ������������ � ���������
; Capabilities. ���� ������� ��������� SDCLK � SD Mode � RCLK � UHS-II Mode.
;       0      - Internal Clock Enable
;              ���� ��� ��������������� � ���� ����� ������� �� ���������� ���������� ��� ����������
;            ������� ���������� �����������.���������� ��������� � ����� ������� ������������,
;            ������������� ���������� ����(internal clock), �������� �������� � �� ������� � �� ������.
;            ���� �������� ����������, ����� ��� ���������� � 1, ����� �������� ������� ���������������
;            ���������� ������������� ��� Internal Clock Stable � ��������� 1. ���� ��� �� ������ ��
;            ����������� ����(�� ��� �� �����).
;       1      - Internal Clock Stable
;              ������� � ������ 4.0 ������� ��������� ���� ������ ������, ����� ��������� ����������
;            �����(�� ����) � ����� ��������� PLL Enable.(Refer to Figure 3-3)
;              1) Internal Clock Stable(����� PLL Enable = 0 ��� ���� �� ��������������)
;                  ���������� ������������� ���� ������� � 1, ����� ������� ��������������� (�� ����)
;                (Doczom: ��� �� �� ���������, � ��� ����� ���� ��������� ���� �� �������� ��� ������)
;              2) PLL Clock Stable (PLL Enable = 1)
;                  ���������� �������������� PLL Enable, ������������� ��� �������� � 0, ��� ���������
;                PLL Enable � 0 �� 1 � ������������� 1, ����� PLL ������������(PLL ���������� ����������
;                ���� � �������� ��������� �����, ������� ���������� � Internal Clock Enable). �����
;                ����, ��� ���� ��� ���������� � 1, ������� ����� ������ SD clock Enable.
;       2      - SD Clcok Enable
;                  ���� ���������� ������ ���������� SDCLK ��� ������ ����� ���� � 0. ����� ������� SDCLK
;                ����� ���� ������ ����� ���� ��� ����� 0. ����� ���� ���������� ������ ������������
;                �� �� ������� �� ��� ���, ���� SDCLK �� ����� ����������(��������� ��� SDCLK=0). ����
;                Card insert � �������� Present State ������, ���� ��� ������ ���� ������.

;;       3      - PLL Enable
;;                  ���� ������� �������� � ������ 4.10 �����������, ������������� PLL. ��� ���������
;;                ���������������� clock ��������� � 2 �����: a)������������ ������� �������� ���������
;;                PLL � Internal Clock Enable � b) ������������ PLL � PLL Enable.
;;                ���������� ����� ��������� ����������� �������� � ������� SD Clock Enable.
;;
;;       4      - Reaerved

;       8 - 15 - SDCLK/RCLK Frequency Select
;              ���� ������� ������������ ��� ������ ������� SDCLK ����.����������� ����� ����
; ������� �� ������ �����������
;       1) 8 ������ ����������� ������
;            ���� ����� �������������� � ������ 1 � 2. ������� �� ��������������� ��������, �
;          �������� �������� ��� Base Clock Frequency For SD Clock � �������� Capabilities
;                   0x08 - base clock / 256
;                   0x40 - base clock / 128
;                   0x20 - base clock / 64
;                   0x10 - base clock / 32
;                   0x08 - base clock / 16
;                   0x04 - base clock / 8
;                   0x02 - base clock / 4
;                   0x01 - base clock / 2
;                   0x00 - base clock (10MHz-63MHz)
;            ��� �������� ������� ������������ ����� ������� ���, �������� ������������ �����������
;          ������ ������������ ������� SD Clock = 25 MHz � ���������� �������� � 50 MHz, ��� �������
;          �������� � ������� �� ������ ��������� ���� �����. ������ ���� �������� ��������� � ������
;          ������ ��� ������ �������� base Clock  = 33MHz � ������� ������� ����� 25MHz, �� ��������
;          �������� �������� 0x01 = 16,5MHz, ��������� ������� ��� ������. ���������� ��� �������
;          ������� 400KHz �������� �������� ������ � 0x40 ����������� �������� ��������� 258kHz.
;       2) 10 ������ ����������� ������
;            ���� ���������� ������ 3.0 ��� ����� �����, �������� ������ ����������� �� 10 ���
;          � �������� ��������
;                   0x3ff -  1/2046 base clock
;                     n   -  1/2n base clock
;                   0x002 -  1/4 base clock
;                   0x001 -  1/2 base clock
;                   0x000 -  Base Clock (10MHz - 155MHz)
;       3) ��������������� ����������� ������
;            ���������� ������ 3.0 � ���� ���� Clock Multiplier � �������� Capabilities �� �������
;          � ���-��. ��������� ��������� ����-������� ����� ����� �������� ������� ��� �������������
;          ������������ ��������� ���� ������, ��������� � ���� ����, ��������� ���������������
;          ��������� ��������� ������� �� ����������� ���������� � ������� �� ����������. �������
;          ���� ����� ������������ � ��������� Preset Value.
;          ��������� ����������� ������������� ��������� ���������, � ���������� ����-������
;          ��������������� �������� � �������� Preset Value.
;                   0x3FF - Base clock * M/1024
;                    N-1  - base clock * M/N
;                   0x002 - base clock * M/3
;                   0x001 - base clock * M/2
;                   0x000 - base clock * M
;            ��� ���� ������� �� �������������� �������� � Preset Value Enable � ��������
;          Host control 2. ���� Preset Value Enable = 0, �� ���� ������� ������������� �������,
;          ���� = 1 , �� ��� �������� ������������� ��������������� ������������� � ����� ��
;          Preset value ���������.
SDHC_CTRL2      = 0x2C
  clock_control = 0x2c ;word
;��� ������������� �����������, ������� ������ ���������� ��� �������� �������� �������� capabilities
;
  timeout_control = 0x2e ;byte (using 0-3 bits)

; ������� ��������� ��� ��������� ����� ����� ��������
;��� ������������� ���������� ������ ������� ����� ��� ���� ���� ����� ����(������ ����� ����)
; 0x02 - software reset ��� DAT ����� (������ SD Mode)
;    ���������:
;      Buffer Data Port register
;         ����� ��������� � ����������������
;      Present State register
;         Buffer Read Enable
;         Buffer Write Enable
;         Read Transfer Active
;         Write Transfer Active
;         DAT Line Active
;         Command Lnhibit(DAT)
;      Block Gap Control register
;         Continue Request
;         Stop At Block Gap Request
;      Normal Interrupt Status register
;         Buffer Read Ready
;         Buffer Write Ready
;         DMA interrupt
;         Block Gap Event
;         Transfer Complete
; 0x01 - software reset for CMD �����
; ��� ������ 4.10 ������������ ��� ������������� ��������� ������� UHS-II
; ���� ����� ��������� ������ �� ����� ������ ������(������� ��������� ������ ������ �
; Command Inhibit(CMD) control) � �� ������ �� ����� �������� ������.
; ���������� ����� ���������� �������� ������, ���� ���� ���� ����� ����������� �� �����
; ��������� ������ ������ ����������.
;    ���������:
;      Present State register
;         Command Inhibit (cmd)
;`     Normal Interrupt Status register
;         Command Complete
;      Error Interrupt Status (from Version 4.10)
;         Response error statuses related to Command Inhibit (CMD)
; 0x00 - software reset for All
; ���� ����� ������ �� ���� ����������� �� ����������� ����� ����������� �����.
; ���� ��������� � �����: ROC RW RW1C RWAC ��������� � 0
; �� ����� ������������� ������� ������ ������� ���� ����� (���������� ������� capabilities �������)
;��������� ���������� ����� ������ ����� �� �������� �� capabilities register.
;���� ���� ��� ���������� � 1,������� ������� ������� ������ � ������ �������������� SD-�����
  software_reset = 0x2f ;byte (using 0-2 bits)
    .software_reset_for_all             = 0x01  ;1-reset 0-work
    .saftware_reset_for_cmd_line        = 0x02  ;1-reset 0-work
    .software_reset_for_dat_line        = 0x04  ;1-reset 0-work

;0x30-0x3d - Interrupt Controls
; � ������������ �� 3.0 ���� ������ 0-8 ����, ��� 15 ���� �� ���� �������
SDHC_INT_STATUS = 0x30
  normal_int_status = 0x30 ; word
    .command_complete                   = 0x01
    .transfer_complete                  = 0x02
    .block_gap_event                    = 0x04
    .dma_interrupt                      = 0x08
    .buffer_write_ready                 = 0x10
    .buffer_read_ready                  = 0x20
    ; ���� ��������� ���������� ������� ��� ������������ �����, ����� ��������� ��� ����� ������� 0x24 .
    ;��� ���������� ��������� ���������� �������� � ������ ��� �������(����� or ��������).
    .card_insertion                     = 0x40
    .card_removal                       = 0x80
    .card_interrupt                     = 0x0100
    .INT_A                              = 0x0200
    .INT_B                              = 0x0400
    .INT_C                              = 0x0800
    .re_tuning_event                    = 0x1000
    .FX_event                           = 0x2000
    ; 14 bit reserved
    .error_interrupt                    = 0x8000   ;���� �� ���� ������� �����
  error_int_status = 0x32 ;word
    .command_timeout_error              = 0x01   ; 1=time out 0=no_error  (SD mode only)
    .command_crc_error                  = 0x02   ; 1=crc error generation 0=no error (sd mode only)
    .command_end_bit_error              = 0x04   ; 1=end_bit_error_generation 0=no error (sd mode only)
    .command_index_error                = 0x08   ; 1=error 0=no error (SD mode only)
    .data_timeout_error                 = 0x10   ; 1=time out 0= no error (sd mode only)
    .data_crc_error                     = 0x20   ; 1=error 0=no error (sd mode only)
    .data_end_bit_error                 = 0x40   ; 1=error 0=no error (sd mode only)
    .current_limit_error                = 0x80   ; 1=Power_fail 0=no_error
    .auto_cmd_error                     = 0x0100 ; 1=error 0=no error (sd mode only)
    .adma_error                         = 0x0200 ; 1=error 0=no error     ; ���������� �� 2 ������ �����
    .tuning_error                       = 0x0400 ; 1=error 0=no error (UHS-I only)
    .response_error                     = 0x0800 ; 1=error 0=no error (SD mode only)
    .vendor_specific_error_status       = 0xf000 ; 1=error 0=no error
SDHC_INT_MASK   = 0x34
  normal_int_status_enable = 0x34 ;word
    .command_complete_status_enable      = 0x01   ; 1=enabled 0=masked
    .transfer_complete_status_enable     = 0x02   ; 1=enabled 0=masked
    .block_gap_event_status_enable       = 0x04   ; 1=enabled 0=masked
    .dma_interrupt_status_enable         = 0x08   ; 1=enabled 0=masked
    .buffer_write_readly_status_enable   = 0x10   ; 1=enabled 0=masked
    .buffer_read_readly_status_enable    = 0x20   ; 1=enabled 0=masked
    .card_insertion_status_enable        = 0x40   ; 1=enabled 0=masked
    .card_removal_status_enable          = 0x80   ; 1=enabled 0=masked
    .card_interrupt_status_enable        = 0x0100 ; 1=enabled 0=masked
    .INT_A_status_enable                 = 0x0200 ; 1=enabled 0=masked (embedded)
    .INT_B_status_enable                 = 0x0400 ; 1=enabled 0=masked (embedded)
    .INT_C_status_enable                 = 0x0800 ; 1=enabled 0=masked (embedded)
    .Re_tuning_event_status_enable       = 0x1000 ; 1=enabled 0=masked (UHS-I only)
    .FX_event_status_enable              = 0x2000 ; 1=enabled 0=masked
    ;reserved 14 bit
    .Fixed_to_0                          = 0x8000   ;���� �� ���� ������� �����
  error_int_status = 0x36
    .command_timeout_error_status_enable = 0x01   ; 1=enabled 0=masked (SD mode only)
    .command_crc_error_status_enable     = 0x02   ; 1=enabled 0=masked (SD mode only)
    .command_end_bit_error_status_enable = 0x04   ; 1=enabled 0=masked (SD mode only)
    .command_index_error_status_enable   = 0x08   ; 1=enabled 0=masked (SD mode only)
    .data_timeout_error_status_enable    = 0x10   ; 1=enabled 0=masked (SD mode only)
    .data_crc_error_status_enable        = 0x20   ; 1=enabled 0=masked (SD mode only)
    .data_end_bit_error_enable           = 0x40   ; 1=enabled 0=masked (SD mode only)
    .current_limit_error_status_enable   = 0x80   ; 1=enabled 0=masked
    .auto_cmd_error_status_enable        = 0x0100 ; 1=enabled 0=masked (SD mode only)
    .adma_error_status_enable            = 0x0200 ; 1=enabled 0=masked
    .tuning_error_status_enable          = 0x0400 ; 1=enabled 0=masked (UHS-I only)
    .response_error_status_enable        = 0x0800 ; 1=enabled 0=masked (SD mode only)
    .vendor_specific_error_status_enable = 0xf000 ; 1=enabled 0=masked (�� ������������!!!)
SDHC_SOG_MASK   = 0x38
  normal_int_signal_enable = 0x38
    .command_complete_signal_enable      = 0x01   ; 1=enabled 0=masked
    .transfer_complete_signal_enable     = 0x02   ; 1=enabled 0=masked
    .block_gap_event_signal_enable       = 0x04   ; 1=enabled 0=masked
    .dma_interrupt_signal_enable         = 0x08   ; 1=enabled 0=masked
    .buffer_write_ready_signal_enable    = 0x10   ; 1=enabled 0=masked
    .buffer_read_ready_signal_enable     = 0x20   ; 1=enabled 0=masked
    .card_insertion_signal_enable        = 0x40   ; 1=enabled 0=masked
    .card_removal_signal_enable          = 0x80   ; 1=enabled 0=masked
    .card_interrupt_signal_enable        = 0x0100 ; 1=enabled 0=masked
    .INT_A_Signal_enable                 = 0x0200 ; 1=enabled 0=masked (embedded)
    .INT_B_Signal_enable                 = 0x0400 ; 1=enabled 0=masked (embedded)
    .INT_C_Signal_enable                 = 0x0800 ; 1=enabled 0=masked (embedded)
    .Re_tunning_event_signal_enable      = 0x1000 ; 1=enabled 0=masked (UHS_I only)
    .FX_event_signal_enable              = 0x2000 ; 1=enabled 0=masked
    ;reserved 14 bit
    .Fixed_to_0                          = 0x8000 ; The Host Driver shall control
    ; error interrupts using the Error Interrupt Signal Enable register.
  error_int_signal_enable = 0x3a
    .command_timeout_error_signal_enable = 0x01   ; 1=enabled 0=masked (SD mode only)
    .command_crc_error_signal_enable     = 0x02   ; 1=enabled 0=masked (sd mode only)
    .command_end_bit_error_signal_enable = 0x04   ; 1=enabled 0=masked (sd mode only)
    .command_index_error_signal_enable   = 0x08   ; 1=enabled 0=masked (sd mode only)
    .data_timeout_error_signal_enable    = 0x10   ; 1=enabled 0=masked (sd mode only)
    .data_crc_error_signal_enable        = 0x20   ; 1=enabled 0=masked (sd mode only)
    .data_end_bit_sagnal_enable          = 0x40   ; 1=enabled 0=masked (sd mode only)
    .current_limit_error_signal_enable   = 0x80   ; 1=enabled 0=masked
    .auto_cmd_error_signal_enable        = 0x0100 ; 1=enabled 0=masked (sd mode only)
    .adma_error_signal_enable            = 0x0200 ; 1=enabled 0=masked
    .tuning_error_signal_enable          = 0x0400 ; 1=enabled 0=masked (UHS-I only)
    .response_error_signal_enable        = 0x0800 ; 1=enabled 0=masked (sd mode only)
    .vendor_specific_error_signal_enable = 0xf000 ; 1=enabled 0=masked (�� ������������!!!)
SDHC_ACMD12_ERR = 0x3C
  Auto_cmd_error_status = 0x3C ;word(using 0-7 bits)
    .auto_cmd12_not_excuted  = 0x01 ; check 0 bit - 1=not_executed 0=executed
    .auto_cmd_timeout_error  = 0x02 ; check 1 bit   1=time out 0=no_error
    .auto_cmd_crc_error      = 0x04 ; check 2 bit   1=crc error generation 0=no_error
    .auto_cmd_end_bit_error  = 0x08 ; check 3 bit   1=end_bit_error_generated  0=no_error
    .auto_cmd_index_error    = 0x10 ; check 4 bit   1=error 0=no_error
    .auto_cmd_response_error = 0x20 ; check 5 bit   1=error 0=no_error
    ; 6 bit is reserved
    .command_not_issued_by_auto_cmd12_error = 0x80 ; check 7 bit   1=Not_issued 0=no_error

;0x3e-0x3f - Host Control 2 ;spec version 3
SDHC_HOST_CONTROL_2_REG = 0x3e   ; word

;0x40-0x4f - Capabilities
;���� ������� ������������� �������� ����, ����������� ��� ���������� ������� �����������.
; �������� ����� ������� ������. ��� ������ ������ ����� ������ ������������ ��������� �
;�����������  �������� �������������
SDHC_CAPABILITY = 0x40    ;qword

;���� ������� ��������� �� ������������ ������� ����������� ��� ������� ���� ����������,
;���� ���������� ������������ ��� ����������(������� 0x40). ���� ���������� �������
;��� �������� ������ �������, �� ���� ������� ������ ���� ��������� � ����.
;    0 - 7 - 3.3V VDD1
;    8 - 15 - 3.0V VDD1
;    16 - 23 - 1.8V VDD1
;    24 - 31 - reserved
;    32 - 39 - 1.8V VDD2
;    40 - 63 - resevred
; ������ ������� �������� ��� � ����� 4��
;    0 - ��������� ���������� ������ ��������
;    1 - 4 ��
;    2 - 8 ��
;    3 - 12 ��
;    ...
;    255 - 1020 ��
; ������� ����������� ��������������� SDXC ����� ������ ��������� ���� ������� ��� ������������
;�������� XPC � ��������� ACMD41. ���� ���������� ����� ��������� ���� ������ 150 �� �� XPC = 1,
;����� XPC = 0. ��������� � XPC � ����� ����������� ������ 3.0x.
SDHC_CURR_CAPABILITY = 0x48    ; qword (using 0-23 32-39)

;0x50-0x53 - Force Event ; spec version 2
SDHC_FORCE_EVT  = 0x50
  force_event_register = 0x50 ;word (using 0-7 bits)
  force_event_register_for_interrupt_status = 0x52 ; word

;0x54-0x5f - ADMA2       ; spec version 2
SDHC_ADMA_ERR   = 0x54
  ADMA_error_status = 0x54 ; byte (using 0-2 bits)

SDHC_ADMA_SAD   = 0x58
  ADMA_system_addres_register = 0x58 ;qword

;0x60-0x6f - Preset Value ;spec version 3

;0x70-0x77 - ADMA3 ;spec version 4

;0x80-0xD7 - UNS-II

;0xe0-0xef - Pointers

;0xf0-0xff  - common area
SDHC_VER_SLOT   = 0xfc ; block data
 SLOT_INTRPT     = 0xfc ;Slot interapt status register 1 byte; 0xfd - reserved
 ;��� � �����, ��� ���������� ���� ������� ����������, ��� ��������� ����������
 ; ����� ���� 8 ������, ������� �� ������� ������������� 1 ���
 SPEC_VERSION = 0xfe ; in map register controller(15-8 - vendor version; 7-0 - spec version)
 VENDOR_VERSION = 0xff

; PCI reg
pci_class_sdhc  = 0x0805  ;basic_class=0x08 sub_class=05
PCI_BAR0        = 0x10
PCI_BAR1        = 0x14
PCI_BAR2        = 0x18
PCI_BAR3        = 0x1C
PCI_BAR4        = 0x20
PCI_BAR5        = 0x14
PCI_IRQ_LINE    = 0x3C

PCI_slot_information = 0x40    ;0-2 first BAR 4-6 - number of Slots(counter BAR?)
; code
section '.flat' code readable writable executable

include 'drivers/proc32.inc'
include 'drivers/struct.inc'
include 'drivers/macros.inc'
include 'drivers/peimport.inc'
include 'drivers/fdo.inc'

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

        card_reg_ocr    rd 1 ; 32 bit
        card_reg_cid    rd 4 ; 128 bit
        card_reg_csd    rd 4 ; 128 bit (������� ����� ���� 2 ������)
        card_reg_rca    rd 1 ; rw 1   ; 16 bit
        card_reg_dsr    rd 1 ; rw 1 ;16 bit (optional)
        card_reg_scr    rd 2 ; 64 bits
        card_reg_ssr    rd 16 ; 512bit

        program_id      rd 1 ; tid thread for working with no memory cards

        flag_command_copmlate rd 1 ; flag interrapt command complate 00 - interrapt is geting
        flag_transfer_copmlate rd 1 ; flag interrapt transfer complate 00 -interrapt is geting


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

tmp_void:       dd 0

proc START c, state:dword, cmdline:dword
        cmp   [state],1
        jne   .stop_drv

        ;detect controller
        DEBUGF  1,"SDHCI: Loading driver\n"
        invoke  GetPCIList
        mov     [tmp_void], eax
        push    eax
.next_dev:
        pop     eax
        mov     eax, [eax+PCIDEV.fd]
        cmp     eax, [tmp_void]
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
        invoke  RegService, drv_name, service_proc
        ret
.not_found:
        DEBUGF  1,"SDHCI: Contriller not found\n"
        mov     eax, 0
        ret
.stop_drv:
        ; deattach  irq
        ; stop power devise
        ; free struct
           ; free reg_map
           ; free memory for DMA


        DEBUGF  1,"SDHCI: Stop working driver\n"
        mov     eax, 0
        ret

        ;DEBUGF   1,"Controller found: class:=%x bus:=%x devfn:=%x \n",[eax + PCIDEV.class],[bus],[dev]

        ;set offset SDMA System address
        ;mov     al, byte[ver_spec]
        ;and     al, 111b
        ;mov     ebx, [base_reg_map]    ; set ebx=SDHC_SYS_ADRR +[base_sdhc_reg]
        ;cmp     al, 0x02 ; ver 3.0 - adding register host control 2
        ;jbe     @f ;
        ;test    word[ebx + SDHC_HOST_CONTROL_2_REG], 0xC ; check 12 bit this register
        ;jz      @f;
        ;add     ebx, SDHC_ADMA_SAD
;@@:
        ;mov     [SDMA_sys_addr],ebx
        ;DEBUGF  1,"set SDMA_sys_addr : %x \n",[SDMA_sys_addr]


        ;reset controller


        ; TODO: working with registers controller
        ; set function for working in DMA and no DMA mode
        ; SDMA - �������� DMA ��� ����� �����������. �� ���� ������� SDMA
        ; ����� ���� ��������� ���� ���������� SD command.
        ; Support of SDMA can be checked by the SDMA Support in the Capabilities register.
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

        ; ��������� ������� Capabiliti � max Current Capabilities
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

        ; �������� DMA ����� : 0 - no dma   1 - sdma  2 - adma1   3 - adma2-32bit   4 - adma2-64bit(�� �����, ��� ��� �� 32 ����)
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
        ;and     ecx, not 0x111 ;�� ����� ��� ��� shl ecx,3 � ��� ������� ��� ���� � ����
        or      dword[eax + SDHC_CTRL1], ecx
        ; ���� 0x28 ���������� � ��������� ��������

        ; ���������� �������� ������
        push    eax
        mov     eax, [esi + SDHCI_CONTROLLER.Capabilities]
        shr     eax, 8
        and     eax, 11111111b  ; 1111 1111
        mov     ebx, 25
        xor     edx, edx
        div     ebx ; 25 ���
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
        shr     edi, 1   ; +- ������
        mov     dword[esi + SDHCI_CONTROLLER.divider50MHz], edi
        DEBUGF  1,'50MHz : %u\n', edi
        imul    eax, 63  ; ��������

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
        ; ��������� ����� ���������� TODO: ����������, � ������������ � ������� DMA
        ;mov     eax, [esi + SDHCI_CONTROLLER.base_reg_map]
        or      dword[eax + SDHC_INT_MASK], 0x40 or 0x80
        or      word[eax + SDHC_SOG_MASK], 0x40 or 0x80
        DEBUGF  1,'SDHCI: Set maximum int mask and mask signal\n'
        ; ���������� �������� � Host Control Register
        ; �� ���� ����� ��������� ���������

        ;��������� ������� 0�0-0�4f
        ;���������� �������� � host control 2
        ;set 0x2e

        ;test
        mov     dword[eax + SDHC_INT_STATUS], 0x00

        ; set Wekeup_control
        or      byte[Wekeup_control], 111b
        ; save and attach IRQ
        invoke  PciRead8, dword [esi + SDHCI_CONTROLLER.bus], dword [esi + SDHCI_CONTROLLER.dev], PCI_IRQ_LINE ;al=irq
        ;DEBUGF  1,'Attaching to IRQ %x\n',al
        movzx   eax, al

        ;attach interrupt
        mov     [esi + SDHCI_CONTROLLER.irq_line], eax ;save irq line
        invoke  AttachIntHandler, eax, sdhc_irq, esi ;esi = pointre to controller

        ; �������� �����
        mov     eax, [esi + SDHCI_CONTROLLER.base_reg_map]
        test    dword[eax + SDHC_PRSNT_STATE], 0x10000 ; check 16 bit in SDHC_PRSNT_STATE.CARD_INS
        jz      @f
        call    card_detect ; eax - REGISTER MAP esi - SDHCI_CONTROLLER
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
        and     dword[eax + SDHC_CTRL2], 0xffff004f ; clear
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
; out: ebx  = type card 0 - unknow card 1 - sdio 2 - sd card(ver1 ver2 ver2-hsp ), 4 - spi(MMC, eMMC)
proc card_init
        DEBUGF  1,'SDHCI: Card init\n'
        ; �������� ��������� ������ ����������� � ��������� ������� �������� ���������
        ; ��������� �� 400 ���
        mov     ebx, [esi + SDHCI_CONTROLLER.divider400KHz]
        call    set_SD_clock
        ; ������� SDHC_CTRL1
        and     dword[eax + SDHC_CTRL2], 11000b

@@:
        jmp     @b
        ; �������� ������� (3.3� - �� ������) ����������� ��������� ��� �����
        ; ��� ��� ���� �� ������� ������
        mov     ebx, [esi + SDHCI_CONTROLLER.Capabilities]
        shr     ebx, 24
        and     ebx, 111b ;26bit - 1.8  25bit - 3.0  24bit - 3.3
        bsf     ecx, ebx
        mov     edx, 111b
        sub     edx, ecx
        shr     edx, 1
        or      edx, 0x01   ; ��� ��������� �����������
        or      dword[eax + SDHC_CTRL1], edx
        DEBUGF  1,'SDHCI: ������� ��������, ��� ��� ���� ������ �� ������� \n'
        ; cmd0 - reset card

        ;�������� ����� ������(sd bus, spi) - �� ��� �� �����

        ; cmd8 - �������� ����������   ������� �� ������ ������������

        ; cmd5 voltage window = 0 - check sdio
        ; if SDIO initialization (cmd5)set voltage window

        ; acmd41 voltage window = 0

        ;if card supported 2 spec,  acmd41 + set hsp=1

        ; cmd55  acmd41 - �� �����

        ; for no sdio card  : cmd2 - get_CID
        ; for all init card : cmd3 - get RCA
        ret
.spi:
        ;���������� � ����������� ����� � ����������
        ret
endp

proc thread_card_detect
        ;get data on stack

        ;call   card_detect
        call    card_detect
        ; destryct thread

endp

proc card_detect
        DEBUGF  1,'SDHCI: Card inserted\n'
        call    card_init
        mov     [esi + SDHCI_CONTROLLER.type_card], ebx
        test    ebx, ebx
        jz      .unknowe
        dec     ebx
        jz      .SDIO
        ; ���� ��� ����� ������(SD memory, eMMC, SPI), �� ��������� ����, else set flag SDIO device
        ; ��������� ��� ��������� � ��������� ��������
.memory_card:
        call    add_card_disk
        DEBUGF  1,'SDHCI: Card init - Memory card\n'
        ret
.SDIO:
        ;mov     [esi + SDHCI_CONTROLLER.type_card], 1 ; sdio card
        DEBUGF  1,'SDHCI: Card init - SDIO card\n'
        ret
.unknowe:
        DEBUGF  1,'SDHCI: Card not init\n'
        ret
endp

proc card_destryct
        DEBUGF  1,'SDHCI: Card removed\n'
        ; ������� ���� �� ������ ������ ���� ��� ����
        test    ebx, 110b
        jz      .no_memory_card

        call    del_card_disk
.no_memory_card:
        ;������� ��� �������� ��������� � ���� ������

        ret
endp

proc sdhc_irq
        mov     esi, [esp + 4] ;stdcall
        DEBUGF  1,"SDHCI: get_irq \n"
        mov     eax,[esi + SDHCI_CONTROLLER.base_reg_map]
        DEBUGF  1,"SLOT_INTRPT: %x \n", [eax + SLOT_INTRPT]
        DEBUGF  1,"SLOT_INT_STATUS: %x \n",[eax + SDHC_INT_STATUS]
        ;DEBUGF  1,"SLOT_SOG_MASK: %x \n",[eax + SDHC_SOG_MASK]
        test    dword[eax + SDHC_INT_STATUS], 0x40
        jz      .no_card_inserted

        or      dword[eax + SDHC_INT_STATUS], 0x40
        pusha
        mov     ebx, 1
        mov     ecx, card_detect
        mov     edx, 0 ; stack - for kernel mode kernel alloc 8Kb RAM
        invoke  CreateThread
        popa
        call    card_detect
.no_card_inserted:
        test    dword[eax + SDHC_INT_STATUS], 0x80
        jz      .no_card_removed

        or      dword[eax + SDHC_INT_STATUS], 0x80
        call    card_destryct
.no_card_removed:
        test    dword[eax + SDHC_INT_STATUS], 0x01 ; check zero bit -  Command Complete
        jz      .no_command_complate

        or      dword[eax + SDHC_INT_STATUS], 0x01
        DEBUGF  1,"Get command complete, CLR flag stop running \n"
        and     [esi + SDHCI_CONTROLLER.flag_command_copmlate], 0x00
.no_command_complate:
        test    dword[eax + SDHC_INT_STATUS], 0x02
        jz      .no_transfer_commplate

        or      dword[eax + SDHC_INT_STATUS], 0x02
        DEBUGF  1,"Get transfer complete, CLR flag stop running \n"
        and     [esi + SDHCI_CONTROLLER.flag_transfer_copmlate], 0x00
.no_transfer_commplate:

        test    dword[eax + SDHC_INT_STATUS], 0x8000 ; 15 bit
        jnz      .get_error

        ret
.get_error:
        DEBUGF  1,"SDHCI: get error irq,  \n"

        ret
endp

proc add_card_disk

        ret
endp
proc del_card_disk

        ret
endp



; This function for working drivers and programs worked
; with SDIO interface.
proc service_proc stdcall, ioctl:dword

        ret
endp

drv_name:       db 'SDHCI',0

sdcard_disk_name:       db 'sdcard00',0

;base_reg_map:   dd 0;pointer on base registers comntroller

;SDMA_sys_addr: dq 0;  [base_sdhc_reg]+offset(0x00 or 0x58-0x5f) 32 or 64 bit
;pt_call_command: dd 0; noDMA or DMA function

align 4
data fixups
end data

include_debug_strings
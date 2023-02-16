;;      Copyright (C) 2022, Michail Frolov(aka Doczom)
;; SDHC ADMA function


; for ADMA2
; edi = virtual addr, edx = block count
; block size = 512
; OUT: edi = phys addr table
proc    create_adma2_table

        ret
endp

proc    destruct_adma2_table

        ret
endp

; for ADMA1
proc    create_adma1_table

        ret
endp

proc    destruct_adma1_table

        ret
endp

; for SDMA mode and for creating ADMA tables
; ecx = line address
; edx = length
; OUT: ecx = virtual addr on table phys addrs on blocks in 512 byte

; WARNING!!! buffer align 9
; 4096 = 0..4 sectors + 1022*4 sectors + 0..4 sectors
;proc    create_mem_table
;
;        ret
;endp

;proc    destruct_mem_table
;
;        ret
;endp

; SDMA
;  send command
;  wait command_complate
;@@:
;  wait DMA int or Transfer compalte
;  if Transfer complate goto .end
;  set new addr  ; передача продолжается при замене этого адреса
;  goto @f
;.end:

; ADMA
; creat descrption table
; send command
; wait command_complate
; wait transfer complate or ADMA_Error
; destruct description table

; no DMA
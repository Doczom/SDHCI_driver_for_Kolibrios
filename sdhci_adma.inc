;;      Copyright (C) 2022-2024, Mikhail Frolov aka Doczom
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
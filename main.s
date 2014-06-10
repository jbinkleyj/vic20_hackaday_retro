; VIC-20 Hack-a-Day Retro Project
; (C) 2014 by Jody Bruchon

!to "main.o",plain
!sl "symbols.txt"

*=$1000
PKTBUF=$1812	; 1518 bytes for ethernet packet

!src "via_spi.s"
!src "enc28j60.s"

main
	jsr spi_init
	jsr e28_init

; Init routines/tables will go here so they can be discarded
; if running somewhere that memory is super tight.
!src "via_spi_init.s"
!src "enc28j60_init.s"

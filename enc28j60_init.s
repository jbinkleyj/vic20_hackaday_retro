; Initialize the chip
e28_init
	; assume the ENC28J60 is the only SPI device
	lda #$ff	; Invalid bank forces initial bank setting
	sta E28_BANK
	; Initialize a bunch of device control registers
	; In the future this may work better if the data was simply
	; copied to the stack in one shot so the data could be pulled
	; directly off the stack.
	ldy #$00
-	lda e28_init_regs_byte,y
	tax
	iny
	lda e28_init_regs_byte,y
	iny
	pha
	tya
	pha	; prepare for device write
	ldy #E28_WCR
	jsr e28_write
	pla
	tay
	pla
	cpy #(e28_init_regs_end - e28_init_regs_byte)
	bne -
	rts

e28_init_regs_byte
!08 E28_ECON1, %00010100	; Enable checksums and packet reception
!08 E28_ERXSTL, <E28_RXBUF_START
!08 E28_ERXSTH, >E28_RXBUF_START
!08 E28_ERXNDL, <E28_RXBUF_END
!08 E28_ERXNDH, >E28_RXBUF_END
!08 E28_ERXRDPTL, <E28_RXBUF_START
!08 E28_ERXRDPTH, >E28_RXBUF_START
!08 E28_ERXFCON, %11100000	; Enable CRC and MAC address checks
!08 E28_MACON1, %00001101	; Enable MAC w/full duplex
!08 E28_MACON3, %11110011	; Enable padding, CRCs, frame error checks
!08 E28_MACON4, %01000000	; 802.3 compliance mode
!08 E28_MAMXFLL, <1518		; Maximum Ethernet frame size
!08 E28_MAMXFLH, >1518
!08 E28_MABBIPG, $15		; Inter-packet gap (802.3 compliance)
!08 E28_MAIPGL, $12
;!08 E28_AIPGH, $0c		; Only used for half-duplex
!08 E28_MAADR1,$c0		; MAC address
!08 E28_MAADR2,$de
!08 E28_MAADR3,$c0
!08 E28_MAADR4,$ff
!08 E28_MAADR5,$ee
!08 E28_MAADR6,$ee
e28_init_regs_end

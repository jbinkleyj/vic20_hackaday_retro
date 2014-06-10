; SD/MMC card SPI initialization routine
; Not used for non-SD/MMC devices

; This was part of Andre Fachat's SPI code. It was moved here
; because it is not used by the VIC-20 Hackaday Project, but
; it could be very useful to someone else.

; Visit http://www.6502.org/users/andre/csa/spi/ for more info.

; send a $ff byte and keeping the data line high
; which is needed for an MMC card to switch to SPI mode
sdmmc_sendresetbytes
	; invert data so first bit is already high
	inc SPI_VIA+VIA_DRA
	ldx #10
--	lda #$00
	sta SPI_VIA+VIA_SR
	; wait to finish
	lda #%00000100
-	bit SPI_VIA+VIA_IFR
	beq -
	; clear int
	sta SPI_VIA+VIA_IFR
	; next resetbyte
	dex
	bne --
	; reset inverter
	dec SPI_VIA+VIA_DRA
	rts


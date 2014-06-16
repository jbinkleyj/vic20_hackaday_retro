; SPI mode 0 interface driver
;
; Use shift register of 6522 VIA 
;
; Low-level driver code and SPI hardware interface taken from
; Andre Fachat's excellent website:
; http://www.6502.org/users/andre/csa/spi/

!src "via_regs.s"

via_spi_code_start

; --- 6522 VIA addresses for SPI interface ---
; Base address of VIA with SPI interface attached
SPI_VIA=$9110

; SPI control flags for output on SPI control port
; VIC-20 cannot use bit 0 optimization for SPI_INVDAT
SPI_SEL=        %00010000
SPI_INVCLK=     %00001000
SPI_INVDAT=     %00000100
SPI_INVDAT_MASK=%11111011

; --- End VIA SPI addresses ---


; Low level SPI routines
;
; These routines use the VIA shift register to shift out the data, and a 
; hardware shift register connected to port B to read the data shifted in.
;
; note that the pure VIA shift register works as SPI mode 3, which is not
; understood by many MMC/SD Cards. 
;
; By using INVCLK the SPI clock signal can be inverted (set CPOL=0).
; To achieve CPHA=0, the first (MSB) bit must be sent out manually 
; by XORing the current shift register output appropriately, which is
; done via INVDAT.
;
; The code waits for the shift register to finish. You could do that with
; NOPs as well for example, as a byte only takes 16 cycles. 
; However, then you can't test it with lower clocks easily.
;
; If you define INVERT_ON_BIT0:
; code assumes the SPI_INVDAT on bit 0 of the port A - so it can be
; modified quickly by INC and DEC


; deselect the connected SPI device
spi_deselect
	pha
	lda SPI_VIA+VIA_DRA
	ora #SPI_SEL
	sta SPI_VIA+VIA_DRA
	jsr spi_r
	pla
	rts

; select the connected SPI device
spi_select
	pha
	lda SPI_VIA+VIA_DRA	
	and #255-SPI_SEL
	sta SPI_VIA+VIA_DRA
	pla
	rts

; send and read a byte
spi_r
	lda #$ff
; send a byte only (could be optimized, 
; but not when you have to wait to end the data inverter) 
spi_w
	; mode 0
	; make sure last bit is 0, shifting bit 7 into carry
	asl
	bcs spi_w_invert
	; last bit was 0, nothing to do but send the byte
	sta SPI_VIA+VIA_SR
	lda #%00000100		; wait to finish
-	bit SPI_VIA+VIA_IFR
	beq -
	bne ++

!ifdef INVERT_ON_BIT0 {
	; invert the current bit (which is last bit from prev. 
	; data byte, which we set to zero)
spi_w_invert
	inc SPI_VIA+VIA_DRA
	eor #$fe		; compensate for the inversion
	sta SPI_VIA+VIA_SR	; send out the data
	lda #%00000100		; wait to finish
-	bit SPI_VIA+VIA_IFR
	beq -
	dec SPI_VIA+VIA_DRA	; reset inverter
} else {
	; compensate for the inversion
spi_w_invert
	eor #$fe
	pha
	; invert the current bit (which is last bit from prev. 
	; data byte, which we set to zero)
	lda SPI_VIA+VIA_DRA
	ora SPI_INVDAT
	sta SPI_VIA+VIA_DRA
	pla
	sta SPI_VIA+VIA_SR	; send out the data
	lda #%00000100		; wait to finish
-	bit SPI_VIA+VIA_IFR
	beq -
	lda SPI_VIA+VIA_DRA	; reset inverter
	and SPI_INVDAT_MASK
	sta SPI_VIA+VIA_DRA
}
++	sta SPI_VIA+VIA_IFR	; clear int
	lda SPI_VIA+VIA_DRB	; do read from ext. shift reg
	rts

via_spi_code_end

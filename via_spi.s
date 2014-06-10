; SPI mode 0 interface driver
;
; Use shift register of 6522 VIA 
;
; Low-level driver code and SPI hardware interface taken from
; Andre Fachat's excellent website:
; http://www.6502.org/users/andre/csa/spi/

!src "via_regs.s"

; --- 6522 VIA addresses for SPI interface ---
; Base address of VIA with SPI interface attached
SPI_VIA=$9110

; SPI control flags for output on SPI control port
; WARNING: SPI code requires SPI_INVDAT on bit 0 of the port!
SPI_SEL=4
SPI_INVCLK=2
SPI_INVDAT=1

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
; note code assumes the SPI_INVDAT on bit 0 of the port A - so it can be
; modified quickly by INC and DEC
;
; The code waits for the shift register to finish. You could do that with
; NOPs as well for example, as a byte only takes 16 cycles. 
; However, then you can't test it with lower clocks easily.


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
	bcs +
	; last bit was 0, nothing to do but send the byte
	sta SPI_VIA+VIA_SR
	; wait to finish
	lda #%00000100
-	bit SPI_VIA+VIA_IFR
	beq -
	bne ++
	
+	; invert the current bit (which is last bit from prev. 
	; data byte, which we set to zero)
	inc SPI_VIA+VIA_DRA
	; compensate for the inversion
	eor #$fe
	; send out the data
	sta SPI_VIA+VIA_SR
	; wait to finish
	lda #%00000100
-	bit SPI_VIA+VIA_IFR
	beq -
	; reset inverter
	dec SPI_VIA+VIA_DRA
++	; clear int
	sta SPI_VIA+VIA_IFR
	; read read data
	lda SPI_VIA+VIA_DRB	; load from external shift reg
	rts


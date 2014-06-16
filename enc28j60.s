; ENC28J60 SPI Ethernet adapter driver
; Low-level device code for direct communication

!src "enc28j60_regs.s"

enc28j60_code_start

E28_BANK=$02	; Current bank
E28_TEMP=$03	; Work area
E28_MEML=$04	; Pointer for memory copy calls
E28_MEMH=$05
E28_SIZH=$06	; 16-bit MEM(L/H) size
E28_SIZL=$07

; --- Low-level device access ---

; Set the control register bank before read/write
e28_cr_setbank
	cmp #$1b	; $1b-$1f never need a CR bank switch
	bmi +
	cmp #$20
	bmi e28_cr_nobank2
+	pha		; Save A register
	and #$c0	; get bank for control register
	cmp E28_BANK	; check against current CR bank
	beq e28_cr_nobank1
	txa
	pha
	tya
	pha
	sta E28_BANK
	ldx #$03	; Zero out bank before setting bits
	lda #E28_ECON1
	ldy #E28_BFC
	jsr e28_write_bypass
	lda E28_BANK	; Restore desired CR bank
	clc		; Move bank bits into position
	rol
	rol
	rol
	beq +	; Skip unnecessary write if bank is 0
	tax
	lda #E28_ECON1	; Actually set the desired bank
	ldy #E28_BFS
	jsr e28_write_bypass
+	pla
	tay
	pla
	tax
e28_cr_nobank1
	pla
e28_cr_nobank2
	rts

; Read control register A into X
e28_rcr
	jsr spi_select
	and #10		; Set command
	ora #E28_RCR
	jsr spi_w
	jsr spi_r
	jmp spi_deselect

; WCR, BFS, BFC instructions
; Perform control register write or bit field operation
; Writes value or sets/clears flags in X to register in A
; Load command prefix with zeroed argument into Y
e28_write
	jsr e28_cr_setbank
e28_write_bypass
	; setbank enters here to avoid calling itself
	jsr spi_select
	and #10		; Set command
	sty E28_TEMP
	ora #E28_TEMP
e28_write_finish
	jsr spi_w
	txa
	jsr spi_w
	jmp spi_deselect

; Soft reset the ethernet controller
e28_src
	jsr spi_select
	lda #E28_SRC
	jmp spi_w


; --- High-level device access ---

; Set up read pointer on device to values in MEM(L/H)
e28_set_readptr
	ldy #E28_WCR
	ldx E28_ERDPTL
	lda E28_MEML
	jsr e28_write
	ldx E28_ERDPTH
	lda E28_MEMH
	jmp e28_write

; Set up write pointer on device to values in MEM(L/H)
e28_set_writeptr
	ldy #E28_WCR
	ldx E28_EWRPTL
	lda E28_MEML
	jsr e28_write
	ldx E28_EWRPTH
	lda E28_MEMH
	jmp e28_write

; Read E28_SIZ(L/H) bytes from device buffer at previously set ERDPT
e28_read_buffer
	jsr spi_select
	lda #E28_RBM
	jsr spi_w
	ldx E28_SIZL
-	jsr spi_r
	sta (E28_MEML),y
	iny
	dex
	bne -
	lda E28_SIZH	; Handle 16-bit size
	beq +
	inc E28_MEMH
	ldy #$00
	ldx #$ff
	bne -		; Retrieve another page
+	jmp spi_deselect

; Write E28_SIZ(L/H) bytes from device buffer at previously set EWRPT
e28_write_buffer
	jsr spi_select
	lda #E28_WBM
	jsr spi_w
	ldx E28_SIZL
-	lda (E28_MEML),y
	jsr spi_w
	iny
	dex
	bne -
	lda E28_SIZH	; Handle 16-bit size
	beq +
	inc E28_MEMH
	ldy #$00
	ldx #$ff
	bne -		; Retrieve another page
+	jmp spi_deselect

enc28j60_code_end

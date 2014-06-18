; ENC28J60 SPI Ethernet adapter driver
; Low-level device code for direct communication

!src "enc28j60_regs.s"

enc28j60_code_start

E28_PPCB=%00000000	; Per-packet control byte

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
	jsr e28_cr_setbank
e28_rcr_bypass
	jsr spi_select
	and #$1f		; RCR = 000aaaaa
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
	; Universal regs (present in all banks) can enter here
	jsr spi_select
	and #$1f		; Set command
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


; --- Mid-level device access ---

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
	ldx #$ff
	ldy #$00
	beq -		; Retrieve another page
+	jmp spi_deselect

; Write E28_SIZ(L/H) bytes to device buffer at previously set EWRPT
e28_write_buffer
	jsr spi_select
	lda #E28_WBM
	jsr spi_w
	ldx E28_SIZL
	ldy #$00
-	lda (E28_MEML),y
	jsr spi_w
	iny
	dex
	bne -
	lda E28_SIZH	; Handle 16-bit size
	beq +
	inc E28_MEMH
	ldx #$ff
	ldy #$00
	beq -		; Retrieve another page
+	jmp spi_deselect

; Enable checksums and packet reception
e28_enable_recv
	ldy #E28_BFS
	ldx #%00010100
	lda #E28_ECON1
	jmp e28_write

; Disable checksums/reception
e28_disable_recv
	ldy #E28_BFC
	ldx #%00010100
	lda #E28_ECON1
	jmp e28_write

; --- High-level device access (send/recv packet) ---

; Checksumming and sending packets to the network card are
; combined operations to enable offloading the checksum work.
; This driver links the TCP/IP to the Ethernet driver and
; pushes checksum calculation work to the ENC28J60 chip.

; To send data:
; 1. Build the complete packet in memory
; 2. Fill a CKSUM# area with the start/end of the part to
;    sum over and the offset to place the checksum at.
;    If offset is 0, that checksum slot will be ignored.
; 3. If TCP is used, the pseudo-header must be removed.
;    Set PSEUDOHEADER to $01 if TCP is used.
; 4. Set X/Y to low/high byte of 16-bit packet size
; 5. Call send_packet

send_packet
	lda #<E28_TXBUF_START	; Send packet data to ENC28J60
	sta E28_MEML
	lda #>E28_TXBUF_START
	sta E28_MEMH
	jsr e28_set_writeptr
	stx E28_SIZL		; Store packet size
	sty E28_SIZH
	lda #$00		; Zero the send override byte
	sta PKTBUF0
	lda #<PKTBUF0		; Point to start of packet buffer for TX
	sta E28_MEML
	lda #>PKTBUF0
	sta E28_MEMH
	jsr e28_write_buffer	; Send packet to ENC28J60 memory

send_packet_cksum_offload
	; Checksum offload handling code
	ldx #CKSUM1_START
-	lda $03,x		; Read checksum offset
	bne +			; Only process this sum if nonzero
send_packet_skip_cksum
	inx			; Skip this checksum slot
	inx
	inx
	inx
	bne -			; Process another slot if X didn't wrap
	jmp send_packet_no_cksums
+	lda $00,x		; Get start of range
	stx E28_TEMP
	clc
	adc #<E28_TXBUF_START	; Add adapter's low byte too
	tax
	ldy #E28_WCR
	lda #E28_EDMASTL
	jsr e28_write
	ldx #>E28_TXBUF_START	; Offload high byte is constant
	lda #E28_EDMASTH
	jsr e28_write
	ldx E28_TEMP
	lda $01,x		; Same process for end of range
	clc
	adc #<E28_TXBUF_START
	tax
	ldy #E28_WCR
	lda #E28_EDMANDL
	jsr e28_write
	ldx E28_TEMP
	lda $02,x
	clc
	adc #>E28_TXBUF_START
	tax
	lda #E28_EDMANDH
	jsr e28_write
	ldy #E28_BFS		; Prepare to do the checksum
	ldx #%00110000		; Set ECON1.DMAST and ECON1.CSUMEN
-	lda #E28_ECON1
	jsr e28_rcr_bypass	; Spin on ECON1 until DMAST is 0
	txa
	and #%00100000
	bne -
	; Load checksum from controller and push to packet
	lda #E28_EDMACSL
	jsr e28_rcr
	stx CKSUM1_ENDL
	lda #E28_EDMACSH
	jsr e28_rcr
	stx CKSUM1_ENDH
send_packet_push_cksum
	lda #<E28_TXBUF_START
	ldx E28_TEMP
	clc
	adc $03,x		; Apply offset
	sta E28_MEML
	lda #>E28_TXBUF_START
	sta E28_MEMH
	jsr e28_set_writeptr
	jsr spi_select		; Inline the write code
	lda #E28_WBM
	jsr spi_w
	lda CKSUM1_ENDL
	jsr spi_w
	lda CKSUM1_ENDH
	jsr spi_w
	jsr spi_deselect
	; Keep summing until all sums are exhausted
	jmp send_packet_skip_cksum
send_packet_no_cksums
	lda #<E28_TXBUF_START	; Set TX end pointer
	clc
	adc E28_SIZL
	bcc +
	inc E28_SIZH
+	tax
	ldy #E28_WCR
	lda #E28_ETXNDL
	jsr e28_write
	lda #>E28_TXBUF_START
	clc
	adc E28_SIZH
	tax
	lda #E28_ETXNDH
	jsr e28_write
	ldy #E28_BFS
	ldx #%00001000		; ECON1.TXRTS
	lda #E28_ECON1
	jmp e28_write_bypass	; Tell ENC28J60 to send packet

; Attempt to receive a packet if possible
; Returns clear carry if no packet available, otherwise sets carry
recv_packet
	lda #E28_EPKTCNT
	jsr e28_rcr
	cpx #$00		; EPKTCNT=0 means no packets
	bne +
	clc
	rts
+	

enc28j60_code_end

; init the SPI code
spi_init
	; deselect any device and invert the clock (mode 0)
	lda SPI_VIA+VIA_PORTA
	ora #SPI_SEL+SPI_INVCLK
	and #255-SPI_INVDAT
	sta SPI_VIA+VIA_PORTA

	lda SPI_VIA+VIA_DDRA	; set port A to output
	ora #SPI_SEL+SPI_INVDAT+SPI_INVCLK
	sta SPI_VIA+VIA_DDRA
	lda #$00		; set port B to input
	sta SPI_VIA+VIA_DDRB

	lda #%00000100		; disable shift register interrupts
	sta SPI_VIA+VIA_IER

	; set up shift register mode to output
	; under phi2 control, which makes bits go out on half phi2.
	lda SPI_VIA+VIA_ACR
	and #%11111011
	ora #%00011000
	sta SPI_VIA+VIA_ACR	

	; write first (dummy) byte, to make sure the last bit is low
	lda #$0
	sta SPI_VIA+VIA_SR
	rts


; init the SPI code
spi_init
	; deselect any device,
	; do invert the clock (mode 0)
	lda SPI_VIA+VIA_PORTA
	ora #SPI_SEL+SPI_INVCLK
	and #255-SPI_INVDAT
	sta SPI_VIA+VIA_PORTA

	; set port A to output
	lda SPI_VIA+VIA_DDRA
	ora #SPI_SEL+SPI_INVDAT+SPI_INVCLK
	sta SPI_VIA+VIA_DDRA
	; set port B to input
	lda #$00
	sta SPI_VIA+VIA_DDRB

	; disable shift register interrupts
	lda #%00000100
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


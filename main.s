; VIC-20 Hack-a-Day Retro Project
; (C) 2014 by Jody Bruchon

!to "main.o",cbm
!sl "symbols.txt"

; VIC-20 contiguous memory limits
START_RAM0=$1000
END_RAM0=$1dff

*=START_RAM0+1
PKTBUF=END_RAM0-1518+1	; 1518 bytes for ethernet packet


; VIC-20 extra free memory blocks
; When things get tight, these could become very useful.
START_RAM1=820		; $C7 (199) bytes
END_RAM1=1023
START_RAM2=512		; $59 (89) bytes
END_RAM2=600
START_ZP0=251		; Free zero page space (5 bytes)
END_ZP0=255
START_ZP1=115		; More ZP (29 bytes)
END_ZP1=143


; BASIC stub for startup
!16 basic_stub_end	; BASIC link to next line
!16 2014		; Line number
!08 $9e			; SYS command
!tx "4109"		; Starting location
!08 0,0,0		; Terminate BASIC program
basic_stub_end

main
	jsr spi_init
	jsr e28_init

!src "via_spi.s"
!src "enc28j60.s"
!src "pagecopy.s"

; Init code will be discarded, but main program code must not overflow
; or nothing will work. Throw a serious error if the code is too big.
end_of_program_code
!if end_of_program_code > PKTBUF {
	!serious "Program code too large. Optimize harder, grasshopper."
}

; Code to be relocated elsewhere
reloc1_start
; Currently not used
reloc1_end

init_code_start
; Init routines/tables will go here so they can be discarded
; if running somewhere that memory is super tight.
!src "via_spi_init.s"
!src "enc28j60_init.s"
init_code_end

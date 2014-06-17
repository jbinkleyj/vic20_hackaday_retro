; VIC-20 Hack-a-Day Retro Project
; (C) 2014 by Jody Bruchon

!to "main.o",cbm
!sl "symbols.txt"

; VIC-20 contiguous memory limits
START_RAM0=$1000
END_RAM0=$1dff

*=START_RAM0+1
PKTBUF0=END_RAM0-1514	; 1514 bytes for ethernet packet
PKTBUF=PKTBUF0+1	; plus prefixed send override byte

; Packet structure for PKTBUF
; ----------------
; PKTBUF0	Send override byte for the ENC28J60 hardware
; $00-$05	Destination Ethernet address
; $06-$0b	Source Ethernet address
; $0c-$0d	Type/Length of Ethernet packet
; --- Start of IPv4 header ---
; $0e		IP version + header length in DWORDs
; $0f		DSCP/ECN bit fields
; $10-$11	IP packet size (header + data)
; $13-$14	Identification for fragmentation
; $15-$16	Flags and fragment offset
; $17		Time to live
; $18		Protocol number
; $19-$1a	IP header checksum
; --- TCP pseudo-header overlaps here ---
; $1b-$1e	Source IP address
; $1f-$22	Destination IP address
; --- TCP pseudo-header ---
; The pseudo-header is overwritten after checksum computation.
; The DMA controller in the ENC28J60 is used to move the TCP
; header and data down once the checksums are finished.
; Pseudo-header starts at $1b but TCP packet data is shifted
; down to $23 to wipe out the pseudo-header.
; $23		Zero
; $24		Protocol (always 6)
; $25-$26	TCP length (header + data)
; --- Actual TCP header ---
; $27-$28	Source port
; $29-$2a	Destination port
; $2b-$2e	Sequence number
; $2f-$32	Acknowledgement number
; $33		Data offset + reserved
; $34		Flags
; $35		Window
; $36-$37	Checksum
; $38-$39	Urgent pointer
; $3a		Start of data
; ... variable length ...

; VIC-20 extra free memory blocks
; When things get tight, these could become very useful.
START_RAM1=820		; $C7 (199) bytes
END_RAM1=1023
START_RAM2=512		; $59 (89) bytes
END_RAM2=600
ZP0=115			; ZP (29 bytes)
END_ZP0=143

start_of_program_code
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
program_code_size=end_of_program_code - start_of_program_code
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

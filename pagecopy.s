; Copy up to one memory page to another location
; Assumes the two memory blocks do not overlap and copies from
; end to start (if dest < src then overlap is okay)
; WARNING: this code is to be modified by the calling code!

; How to use:
; Store source address in pagecopy_src+1
; Store destination in pagecopy_dest+1
; load X with number of bytes to copy
; call this routine
pagecopy
pagecopy_src
	lda $0000,x
pagecopy_dest
	sta $0000,x
	dex
	bne pagecopy_src
	rts

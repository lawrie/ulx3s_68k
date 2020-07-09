	ORG	$0000

	DC.L	$20000		; Set stack to top of RAM
	DC.L    start		; Set PC to start

start:
	MOVE.L	#$10000,A0	; VRAM address
	MOVE.W  #$3FFF,D0	; Full screen in words
loop:
	MOVE.W  #$6431, (A0)	; Write to VRAM
	ADDQ.L	#2, A0		; Increment VRAM pointer
	DBRA    D0, loop	; Loop until done
	STOP    #$2700




	ORG	$0000

	DC.L	$20000	; Set stack to top of RAM
	DC.L    start	; Set PC to start

start:
	LEA	$10000,A0
	MOVE.W  #$6431, (A0)
	STOP    #$2700




ACIAC    EQU $600001
ACIAD    EQU ACIAC+2

RDRF    EQU 0
TDRE    EQU 1

CR      EQU 13
LF      EQU 10
	ORG	$0000

	DC.L	$20000		; Set stack to top of RAM
	DC.L    START		; Set PC to start

START	BSR.S	INIT_ACIA
	MOVE.L	#$FFFF,D1
	DBRA	D1,$

LOOP	
	LEA.L	HELLO.L,A0
	BSR.S	OUTL
	MOVE.L	#$FFFF,D1
	DBRA	D1,$
	BRA.S	LOOP

STOP	STOP    #$2700

HELLO   DC.B    "Hello World!",CR,LF,0,0

OUTL    MOVE.B  (A0)+,D0
	BEQ.S   OUTL1
	BSR.S	OUTC
	BRA.S	OUTL
OUTL1	RTS

OUTC	BSR.S	COUT
	MOVE.W	#2000,D1
	DBRA D1,$
	RTS

INIT_ACIA  MOVE.B #3,ACIAC.L   ; RESET ACIA
           MOVE.W #10000,D0
           DBRA  D0,$
           MOVE.B #$15,ACIAC.L   ; rts enabled 9600 8ne
           RTS

COUT      BTST.B #TDRE,ACIAC.L
          BEQ.S  COUT
          MOVE.B D0,ACIAD.L
          RTS


CINS      BTST.B #RDRF,ACIAC.L
          BEQ.S  CINS
          MOVE.B ACIAD.L,D0
          RTS


CIN      BTST.B #RDRF,ACIAC.L
         BEQ.S  CIN
         MOVE.B ACIAD.L,D0
         BSR COUT
         RTS


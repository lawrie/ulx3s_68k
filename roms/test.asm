KEYROW1 EQU $600017

	ORG	$0000

	DC.L	$20000		; Set stack to top of RAM
	DC.L    START		; Set PC to start

START
; Clear the screen
	LEA	$10000,A0	; VRAM address of top half
	MOVE.W  #$1FFF,D0	; Clear too half of  screen to cyan
CLEAR	MOVE.W  #$5555, (A0)+	; Write to VRAM
        DBRA    D0, CLEAR	; Loop until done
        LEA     $14000,A0       ; VRAM address of bottonm half
	MOVE.W  #$1FFF,D0	; Clear bottom half of screen to yellow
CLEAR1	MOVE.W  #$6666, (A0)+	; Write to VRAM
        DBRA    D0, CLEAR1	; Loop until done
; Draw sprites
	MOVE.W	#123, D3	; Draw it 124 times
DRAW
	LEA	$13800,A0	; 16 pixels above bottom half
        MOVE.B  KEYROW1.L,D4    ; Get Keyrow 1
        BTST.L  #2,D4
	BEQ.S	NOJMP
	SUBA.L	#2048,A0
NOJMP	
	MOVE.W	#123,D4		; Get positive index 
	SUB.W	D3,D4		
	ADDA.W	D4,A0		; Add it to screen address
	MOVE.L	A0,-(SP)	; Save address
	LEA	BACK,A1		; Read existing screen contents
	BSR	READVRAM
	MOVE.L	(SP),A0		; Restore screen address
	LEA	SPRITE1,A1	; Get address of sprite
	BSR.S	SPRITE		; Draw the sprite
	MOVE.W	#$FFFF,D2	; Delay
	DBRA	D2,$		
	MOVE.L	(SP)+,A0	; Restore screen address
	LEA	BACK,A1		; Restore background
	BSR	SPRITE16
	DBRA	D3,DRAW		; Continue to next position
	MOVE.W	#123, D3	; Draw it 124 times
DRAWBACK
	LEA	$1387C,A0	; 16 pixels above bottom half
        MOVE.B  KEYROW1.L,D4    ; Get Keyrow 1
        BTST.L  #2,D4
	BEQ.S	NOJMP1
	SUBA.L	#2048,A0
NOJMP1
	MOVE.W	#123,D4		; Get positive index 
	SUB.W	D3,D4		
	SUB.W	D4,A0		; Subtract it from screen address
	MOVE.L	A0,-(SP)	; Save address
	LEA	BACK,A1		; Read existing screen contents
	BSR	READVRAM
	MOVE.L	(SP),A0		; Restore screen address
	LEA	SPRITE1,A1	; Get address of sprite
	BSR.S	SPRFLIP		; Draw the sprite
	MOVE.W	#$FFFF,D2	; Delay
	DBRA	D2,$		
	MOVE.L	(SP)+,A0	; Restore screen address
	LEA	BACK,A1		; Restore background
	BSR.S	SPRITE16
	DBRA	D3,DRAWBACK	; Continue to next position
	LEA	$13800,A0
	LEA	SPRITE1,A1
	BSR.S	SPRITE
STOP
	STOP    #$2700

; A0 = screen address, A1 = sprite
; 8x8 sprite expanded to 8x16 on screen
; Byte-aligned only
SPRITE
	MOVE.W	#7,D0		; 8 rows in a sprite
LINE	MOVE.W	#3,D1		; 4 bytes, 8 pixels on a row
PIXEL2	MOVE.B	(A1)+,(A0)+     ; Write 2 pixels to screen
	DBRA	D1,PIXEL2       ; Loop until 8 pixels written
	SUBQ.L	#4, A1		; Go back to start of sprite row
	ADDA.L	#124,A0		; Move to next screen row
        MOVE.W	#3,D1		; Write second copy of row
PIX2A   MOVE.B  (A1)+,(A0)+	; For 8x16 sprite
	DBRA	D1,PIX2A
	ADDA.L	#124,A0		; Move to next line
	DBRA	D0,LINE
	RTS

; A0 = screen address, A1 = sprite
; 8x8 sprite expanded to 8x16 on screen
; Byte-aligned only
SPRFLIP
	MOVE.W	#7,D0		; 8 rows in a sprite
LINEF	MOVE.W	#3,D1		; 4 bytes, 8 pixels on a row
	ADDA.L	#4,A0
PIXELF	MOVE.B	(A1)+,D4	; Write 2 pixels to screen
	ROL.B	#4,D4
	MOVE.B	D4,-(A0)
	DBRA	D1,PIXELF	; Loop until 8 pixels written
	SUBQ.L	#4, A1		; Go back to start of sprite row
	ADDA.L	#132,A0		; Move to next screen row
        MOVE.W	#3,D1		; Write second copy of row
PIXFA   MOVE.B  (A1)+,D4	; For 8x16 sprite
	ROL.B	#4,D4
	MOVE.B	D4,-(A0)
	DBRA	D1,PIXFA
	ADDA.L	#128,A0		; Move to next line
	DBRA	D0,LINEF
	RTS

; A0 = screen address, A1 = sprite
; 8x16 sprite 
; Byte-aligned only
SPRITE16
	MOVE.W	#15,D0		; 16 rows in a sprite
LINE16	MOVE.W	#3,D1		; 4 bytes, 8 pixels on a row
PIX16	MOVE.B	(A1)+,(A0)+     ; Write 2 pixels to screen
	DBRA	D1,PIX16	; Loop until 8 pixels written
	ADDA.L	#124,A0		; Move to next line
	DBRA	D0,LINE16
	RTS

; Read screen data for sprite
; A0 = screen address, A1 = storage area
READVRAM
	MOVE.W	#7,D0		; 8 rows in a sprite
RLINE	MOVE.W	#3,D1		; 4 bytes, 8-pixels on a row
RPIXEL2	MOVE.B	(A0)+,(A1)+     ; Read 2 pixels from screen
	DBRA	D1,RPIXEL2	; Loop until 8-pixels read
	ADDA.L	#124,A0		; Move to next screen row
        MOVE.W	#3,D1		; Read second copy of row
RPIX2A	MOVE.B  (A0)+,(A1)+	; For 8x16 sprite
	DBRA	D1,RPIX2A
	ADDA.L	#124,A0		; Move to next line
	DBRA	D0,RLINE
	RTS

SPRITE1	
	DC.B	$50,$22,$22,$55
	DC.B	$52,$22,$77,$22
	DC.B	$00,$06,$06,$05
	DC.B	$00,$06,$06,$05
	DC.B	$06,$00,$66,$65
	DC.B	$21,$12,$20,$06
	DC.B	$61,$11,$15,$55
	DC.B	$00,$55,$00,$55

BLANK
	DC.B	$55,$55,$55,$55
	DC.B	$55,$55,$55,$55
	DC.B	$55,$55,$55,$55
	DC.B	$55,$55,$55,$55
	DC.B	$55,$55,$55,$55
	DC.B	$55,$55,$55,$55
	DC.B	$55,$55,$55,$55
	DC.B	$55,$55,$55,$55

	ORG	$18000		; RAM

BACK	DS.L	64


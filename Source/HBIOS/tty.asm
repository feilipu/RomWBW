;
;==================================================================================================
;   TTY EMULATION MODULE
;==================================================================================================
;
; TODO:
;   - SOME FUNCTIONS ARE NOT IMPLEMENTED!!!
;
; INITIALIZATION OF EMULATION MODULE CALLED BY PARENT VDA DRIVER
; ON ENTRY:
;   C: CIO UNIT NUMBER OF CALLING VDA DRIVER
;   DE: DISPATCH ADDRESS OF CALLING VDA DRIVER
; RETURNS:
;   DE: OUR CIO DISPATCH ADDRESS
;
TTY_INIT:
	; PREVENT ATTEMPTS TO INIT MULTIPLE INSTANCES FOR NOW
	LD	A,(TTY_VDAUNIT)		; LOAD CURRENT VDA UNIT VALUE
	INC	A			; SHOULD BE $FF, INC TO $00
	RET	NZ			; IF NOT 0, PREVIOUSLY ATTACHED, RETURN W/ NZ
;
	; SAVE INCOMING DATA
	LD	A,B			; TERMINAL DEVICE NUM PASSED IN B
	LD	(TTY_DEVNUM),A		; SAVE IT
	LD	A,C			; VDA UNIT NUMBER PASSED IN C
	LD	(TTY_VDAUNIT),A		; SAVE IT
	LD	(TTY_VDADISPADR),DE	; RECORD VDA DISPATCH ADDRESS
;
	; INIT/RESET OUR INTERNAL STATE
	CALL	TTY_RESET		; FULL RESET OF EMULATOR INTERNAL STATE
	RET	NZ			; BAIL OUT ON ERROR
;
	LD	DE,TTY_DISPATCH		; RETURN OUR DISPATCH ADDRESS
	XOR	A			; SIGNAL SUCCESS
	RET				; RETURN
;
TTY_RESET:
	; QUERY THE VIDEO DRIVER FOR SCREEN DIMENSIONS
	LD	B,BF_VDAQRY	; FUNCTION IS QUERY
	LD	HL,0		; WE DO NOT WANT A COPY OF THE CHARACTER BITMAP DATA
	CALL	TTY_VDADISP	; PERFORM THE QUERY FUNCTION
	LD	(TTY_DIM),DE	; SAVE THE SCREEN DIMENSIONS RETURNED
;
	LD	DE,0		; DE := 0, CURSOR TO HOME POSITION 0,0
	LD	(TTY_POS),DE	; SAVE CURSOR POSITION
;
	XOR	A		; SIGNAL SUCCESS
	RET			; DONE
;
;
;
TTY_VDADISP:
	JP	PANIC
TTY_VDADISPADR	.EQU	$ - 2
;
;
;
TTY_DISPATCH:
	LD	A,B		; GET REQUESTED FUNCTION
	AND	$0F		; ISOLATE SUB-FUNCTION
	JR	Z,TTY_CIOIN	; $30
	DEC	A
	JR	Z,TTY_CIOOUT	; $31
	DEC	A
	JR	Z,TTY_CIOIST	; $32
	DEC	A
	JR	Z,TTY_CIOOST	; $33
	DEC	A
	JR	Z,TTY_CIOINIT	; $34
	DEC	A
	JR	Z,TTY_CIOQUERY	; $35
	DEC	A
	JR	Z,TTY_CIODEVICE	; $36
	CALL	PANIC
;
;
;
TTY_CIOIN:
	LD	B,BF_VDAKRD	; SET FUNCTION TO KEYBOARD READ
	JP	TTY_VDADISP	; CHAIN TO VDA DISPATCHER
;
;
;
TTY_CIOOUT:
	CALL	TTY_DOCHAR	; HANDLE THE CHARACTER (EMULATION ENGINE)
	XOR	A		; SIGNAL SUCCESS
	RET
;
;
;
TTY_CIOIST:
	LD	B,BF_VDAKST	; SET FUNCTION TO KEYBOARD STATUS
	JP	TTY_VDADISP	; CHAIN TO VDA DISPATCHER
;
;
;
TTY_CIOOST:
	XOR	A		; ZERO ACCUM
	INC	A		; A := $FF TO SIGNAL OUTPUT BUFFER READY
	RET
;
;
;
TTY_CIOINIT:
	; RESET THE ATTACHED VDA DEVICE
	LD	B,BF_VDAINI	; FUNC: INIT
	LD	E,-1		; DO NOT CHANGE VIDEO MODE
	LD	HL,0		; DO NOT LOAD A BITMAP
	CALL	ANSI_VDADISP	; CALL THE VDA DRIVER
	; RESET OUR INTERNAL STATE AND RETURN
	JP	TTY_RESET	; RESET OURSELVES AND RETURN
;
;
;
TTY_CIOQUERY:
	LD	DE,$FFFF
	LD	HL,$FFFF
	XOR	A
	RET
;
;
;
TTY_CIODEVICE:
	LD	D,CIODEV_TERM		; TYPE IS TERMINAL
	LD	A,(TTY_DEVNUM)		; GET DEVICE NUMBER
	LD	E,A			; PUT IT IN E
	LD	A,(TTY_VDAUNIT)		; GET VDA UNIT NUM
	SET	7,A			; SET BIT 7 TO INDICATE TERMINAL TYPE
	LD	C,A			; PUT IT IN C
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
TTY_DOCHAR:
	LD	A,E		; CHARACTER TO PROCESS
	CP	8		; BACKSPACE
	JR	Z,TTY_BS
	CP	12		; FORMFEED
	JR	Z,TTY_FF
	CP	13		; CARRIAGE RETURN
	JR	Z,TTY_CR
	CP	10		; LINEFEED
	JR	Z,TTY_LF
	CP	32		; COMPARE TO SPACE (FIRST PRINTABLE CHARACTER)
	RET	C		; SWALLOW OTHER CONTROL CHARACTERS
	LD	B,BF_VDAWRC
	CALL	TTY_VDADISP	; SPIT OUT THE RAW CHARACTER
	LD	A,(TTY_COL)	; GET CUR COL
	INC	A		; INCREMENT
	LD	(TTY_COL),A	; SAVE IT
	LD	DE,(TTY_DIM)	; GET SCREEN DIMENSIONS
	CP	E		; COMPARE TO COLS IN LINE
	RET	C		; NOT PAST END OF LINE, ALL DONE
	CALL	TTY_CR		; CARRIAGE RETURN
	JR	TTY_LF		; LINEFEED AND RETURN
;
TTY_FF:
	LD	DE,0		; PREPARE TO HOME CURSOR
	LD	(TTY_POS),DE	; SAVE NEW CURSOR POSITION
	CALL	TTY_XY		; EXECUTE
	LD	DE,(TTY_DIM)	; GET SCREEN DIMENSIONS
	LD	H,D		; SET UP TO MULTIPLY ROWS BY COLS
	CALL	MULT8		; HL := H * E TO GET TOTAL SCREEN POSITIONS
	LD	E,' '		; FILL SCREEN WITH BLANKS
	LD	B,BF_VDAFIL	; SET FUNCTION TO FILL
	CALL	TTY_VDADISP	; PERFORM FILL
	JR	TTY_XY		; HOME CURSOR AND RETURN
;
TTY_BS:
	LD	A,(TTY_COL)	; GET CURRENT COLUMN
	DEC	A		; BACK IT UP BY ONE
	RET	C		; IF CARRY, MARGIN EXCEEDED, ABORT
	LD	(TTY_COL),A	; SAVE NEW COLUMN
	JP	TTY_XY		; UDPATE CUSROR AND RETURN
;
TTY_CR:
	XOR	A		; ZERO ACCUM
	LD	(TTY_COL),A	; COL := 0
	JR	TTY_XY		; REPOSITION CURSOR AND RETURN
;
TTY_LF:	; LINEFEED (FORWARD INDEX)
	LD	A,(TTY_ROW)	; GET CURRENT ROW
	LD	DE,(TTY_DIM)	; GET SCREEN DIMENSIONS
	DEC	D		; D := MAX ROW NUM
	CP 	D		; >= LAST ROW?
	JR	NC,TTY_LF1	; IF SO, NEED TO SCROLL
	INC	A		; BUMP TO NEXT ROW
	LD	(TTY_ROW),A	; SAVE IT
	JP	TTY_XY		; UPDATE CURSOR AND RETURN
;
TTY_LF1:	; SCROLL
	LD	E,1		; SCROLL FORWARD 1 LINE
	LD	B,BF_VDASCR	; SET FUNCTION TO SCROLL
	JP	TTY_VDADISP	; DO THE SCROLLING AND RETURN
;
TTY_XY:
	LD	DE,(TTY_POS)	; GET THE DESIRED CURSOR POSITION
	LD	B,BF_VDASCP	; SET FUNCTIONT TO SET CURSOR POSITION
	JP	TTY_VDADISP	; REPOSITION CURSOR
;
;
;
TTY_POS:
TTY_COL		.DB	0	; CURRENT COLUMN - 0 BASED
TTY_ROW		.DB	0	; CURRENT ROW - 0 BASED
;
TTY_DIM:
TTY_COLS	.DB	80	; NUMBER OF COLUMNS ON SCREEN
TTY_ROWS	.DB	24	; NUMBER OF ROWS ON SCREEN
;
TTY_VDAUNIT	.DB	$FF	; VIDEO UNIT NUM OF ATTACHED VDA DEVICE
TTY_DEVNUM	.DB	$FF	; TERMINAL DEVICE NUMBER
; PIO driver sets up the parallel port as a subtype of Serial/Char device.
;
;
; HBIOS initializes driver by:
;
; 1) Calling Pre-initialization
;
;    This involves setting up all the data structures describing the devices.
;    If possible, do a hardware test to verify it is available for adding to available devices.
;
; 2) Calling device initialization.
;
;    Hardware initialization.
;    Configure to initial state or to a new state.
;
; Implementation limitations:
;
; The fully functionality of the Z80 PIO can only be realized by using Z80 interrupt mode 2.
; Registers cannot be interrogated for interrupts status and the originating interrupt
; device cannot be determine.
;
; Full implementation of IM2 functionality for an ECB-ZP and ECB-4P board would require the 
; allocation of an interrupt handler for each chip channel. Thus, 12 interrupt handlers
; would be required to support this configuration. As the HBIOS only has an allocation of
; 16, a full implmentation is impractical.
;
; The compromise solution is to allow 4 interrupts for the PIO driver. All remaining PIO's
; are limited to Bit mode or blind read and write to the input/output ports.
;
; Zilog PIO reset state:
;
;	Both port mask registers are reset to inhibit All port data bits.
;	Port data bus lines are set to a high-impedance state and the Ready "handshake"
;	Mode 1 (output) is automatically selected.
;	The vector address registers are not reset.
;	Both port interrupt enable flip-flops are reset.
;	Both port output registers are reset.
;
; Register addressing example for ECB-ZP and ECB-4P assuming base address 90h and 88h respectively.
;
; PIO ----ZP---- ----4P----
;  0  DATA 0 90h DATA 0 B8h
;  0  DATA 1 91h DATA 1 B9h
;  0  CMD  0 92h CMD  0 BAh
;  0  CMD  1 93h CMD  1 BBh
;  1  DATA 0 94h DATA 0 BCh
;  1  DATA 1 95h DATA 1 BDh
;  1  CMD  0 96h CMD  0 BEh
;  1  CMD  1 97h CMD  1 BFh
;  2             DATA 0 C0h
;  2             DATA 1 C1h
;  2             CMD  0 C2h
;  2             CMD  1 C3h
;  3             DATA 0 C4h
;  3             DATA 1 C5h
;  3             CMD  0 C6h
;  3             CMD  1 C7h
;
PIODEBUG	.EQU	1
;
M_Output	.EQU	$00 << 6
M_Input		.EQU	$01 << 6
M_Bidir		.EQU	$02 << 6
M_BitCtrl	.EQU	$03 << 6
M_BitAllIn	.EQU	$FF
M_BitAllOut	.EQU	$00
;
PIO_NONE	.EQU	0
PIO_ZPIO	.EQU	1
PIO_8255	.EQU	2
PIO_PORT	.EQU	3

; SET MAXIMUM NUMBER OF INTERRUPTS AVAILABLE FOR ALL
; ENSURE INTERRUPTS ARE NOT TURNED ON IF IM2 IS NOT SET.

INT_ALLOC	.DB	0
INT_N		.EQU	00000000B
#IF	(INTMODE == 2)
INT_Y		.EQU	00000100B
INT_ALLOW	.EQU	4
#ELSE
INT_Y		.EQU	INT_N
INT_ALLOW	.EQU	0
#ENDIF
;
INT0		.EQU	00000000B
INT1		.EQU	00000001B
INT2		.EQU	00000010B
INT3		.EQU	00000011B

;
; SETUP THE DISPATCH TABLE ENTRIES
;
; PIO_CNT HOLDS THE NUMBER OF DEVICED CALCULATED FROM THE NUMBER OF DEFPIO MACROS
; PIO_CNT SHOULD INCREASE BY 2 FOR EVERY PIO CHIP ADDED.
;
; PIO_PREINIT WILL READ THROUGH ALL PIOCFG TABLES AND CONFIGURE EACH TABLE.
; IT WITH THEN CALL PIO_INITUNIT TO INITIALIZE EACH DEVICE TO ITS DEFAULT STATE
; 
; EXPECTS NOTHING ON ENTRY
;
PIO_PREINIT:
	CALL	NEWLINE		;D
	LD	B,PIO_CNT		; LOOP CONTROL
	LD	C,0			; PHYSICAL UNIT INDEX
	XOR	A			; ZERO TO ACCUM
;	LD	(PIO_DEV),A		; CURRENT DEVICE NUMBER
	LD	(INT_ALLOC),A		; START WITH NO INTERRUPTS ALLOCATED
PIO_PREINIT0:	
	PUSH	BC			; SAVE LOOP CONTROL
;	LD	A,C			; INITIALIZE THE UNIT

;	PUSH	AF		;D
;	LD	A,'u'		;D
;	CALL	COUT		;D
;	POP	AF		;D
;	CALL	PRTHEXBYTE	;D	UNIT
;	CALL	PC_SPACE	;D

;	RLCA				; MULTIPLY BY CFG TABLE ENTRY SIZE (32 BYTES)
;	RLCA				; ...
;	RLCA				; ... TO GET OFFSET INTO CFG TABLE
;	RLCA
;;	RLCA
;	LD	HL,PIO_CFG		; POINT TO START OF CFG TABLE
;	PUSH	AF
;	CALL	ADDHLA			; HL := ENTRY ADDRESS
;	POP	AF
;	CALL	ADDHLA			; HL := ENTRY ADDRESS
;	PUSH	HL			; SAVE IT
;	POP	IY			; ... TO IY

	CALL	IDXCFG			

	LD	(HL),C

	PUSH	AF		;D
	LD	A,'c'		;D
	CALL	COUT		;D
	POP	AF		;D
	PUSH	BC		;D
	PUSH	HL		;D
	POP	BC		;D
	CALL	PRTHEXWORD	;D	CONFIG TABLE
	CALL	PC_SPACE	;D
	POP	BC		;D

	LD	A,(IY+1)		; GET THE PIO TYPE DETECTED
	CP	PIO_PORT		; SET FLAGS

	PUSH	AF		;D
	LD	A,'t'		;D
	CALL	COUT		;D
	POP	AF		;D
	CALL	PRTHEXBYTE	;D	TYPE
	CALL	PC_SPACE	;D

;	JR	Z,BADINIT

;	PUSH	BC			; SAVE LOOP CONTROL
;	LD	BC,PIO_FNTBL		; BC := FUNCTION TABLE ADDRESS	
;	DEC	A
;	JR	Z,TYPFND		; SKIP IT IF NOTHING FOUND
;	LD	BC,PPI_FNTBL		; BC := FUNCTION TABLE ADDRESS
;	DEC	A
;	JR	Z,TYPFND		; ADD ENTRY IF PIO FOUND, BC:DE
;	LD	BC,PRT_FNTBL
;	DEC	A
;	JR	Z,TYPFND
;	POP	BC
;	JR	BADINIT

	PUSH	HL
	LD	DE,-1			; INITIALIZE THIS DEVICE WITH
	CALL	PIO_INITDEV		; DEFAULT VALUES
	POP	HL

;	JR	NZ,SKPINIT

	; AT THIS POINT WE KNOW WE
	; HAVE A VALID DEVICE SO ADD IT
	
	LD	A,8			; CALCULATE THE FUNCTION TABLE 
	CALL	ADDHLA			; POSITION WHICH FOLLOWS THE
	PUSH	HL			; CONFIGURATION TABLE OF EACH
	POP	BC			; DEVICE

TYPFND:	PUSH	AF		;D
	LD	A,'f'		;D
	CALL	COUT		;D
	POP	AF		;D
	PUSH	BC		;D
	CALL	PRTHEXWORD	;D	FUNCTION TABLE
	POP	BC		;D
	CALL	NEWLINE		;D

	PUSH	IY			; ADD ENTRY IF PIO FOUND, BC:DE
	POP	DE			; BC: DRIVER FUNCTION TABLE
	CALL	CIO_ADDENT		; DE: ADDRESS OF UNIT INSTANCE DATA

BADINIT:POP	BC			; RESTORE LOOP CONTROL

	INC	C			; NEXT PHYSICAL UNIT
SKPINIT:DJNZ	PIO_PREINIT0		; LOOP UNTIL DONE

	PUSH	AF		;D
	PRTS("INTS=$")		;D
	LD	A,(INT_ALLOC)	;D
	CALL	PRTHEXBYTE	;D
	POP	AF		;D
	PUSH	DE		;D
	LD	DE,CIO_TBL-3	;D
	CALL	DUMP_BUFFER	;D
	POP	DE		;D
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
; INDEX INTO THE CONFIG TABLE
; ON ENTRY C = UNIT NUMBER
; ON EXIT IY = CONFIG DATA POINTER
; ON EXIT DE = CONFIG TABLE START
;
; EACH CONFIG TABLE IS 24 BYTES LONG
;
CFG_SIZ		.EQU	24
;
IDXCFG:	LD	A,C
	RLCA				; X 2
	RLCA				; X 4
	RLCA				; X 8
	LD	H,0
	LD	L,A			; HL = X 8
	PUSH	HL
	ADD	HL,HL			; HL = X 16
	POP	DE
	ADD	HL,DE			; HL = X 24
	LD	DE,PIO_CFG
	ADD	HL,DE
	PUSH	HL			; COPY CFG DATA PTR
	POP	IY			; ... TO IY
	RET
	
; PIO_INITDEV - INITIALIZE DEVICE
;
; IF DE = FFFF THEN THE SETUP PARAMETER WORD WILL BE READ FROM THE DEVICE CONFIGURATION  
; TABLE POINTED TO BY IY AND THE PIO PORT WILL BE PROGRAMMED BASED ON THAT CONFIGURATION. 
;
; OTHERWISE THE PIO PORT WILL BE PROGRAMMED BY THE SETUP PARAMETER WORD IN DE AND THIS 
; WILL BE SAVED IN THE DEVICE CONFIGURATION TABLE POINTED TO BY IY.
;
; ALL OTHER CONFIGURATION OF THE DEVICE CONFIGURATION TABLE IS DONE UPSTEAM BY PIO_PREINIT 

PIO_INITDEV:
	; TEST FOR -1 (FFFF) WHICH MEANS USE CURRENT CONFIG (JUST REINIT)
	LD	A,D			; TEST DE FOR
	AND	E			; ... VALUE OF -1
	INC	A			; ... SO Z SET IF -1
	JR	NZ,PIO_INITDEV1		; IF DE == -1, REINIT CURRENT CONFIG
PIO_INITDEV0:
	; LOAD EXISTING CONFIG (DCW) TO REINIT
	LD	E,(IY+4)		; LOW BYTE
	LD	D,(IY+5)		; HIGH BYTE	
;
PIO_INITDEV1:				; WHICH DEVICE TYPE?
	LD	A,(IY+1)
	CP	PIO_ZPIO		
	JR	Z,SETPIO0
	CP	PIO_8255
	JP	Z,SET_8255
	CP	PIO_PORT
	JP	Z,SET_PORT
BAD_SET:OR	$FF			; UNKNOWN DEVICE
	RET

SETPIO0:LD	A,E			; GET MODE 
	AND	11000000B		; BITS (B7B6)
	CP	10000000B		; IS IT BIDIR?
	JR	NZ,SETPIO1
	LD	A,(IY+2)		; GET CHANNEL
	OR	A
	JR	NZ,BAD_SET		; CAN'T DO ON CH1

	; VALIDATE INTERRUPT REQUEST
	; GRANT INTERRUPT IF THERE IS A FREE INTERRUPT
	; GRANT INTERRUPT IF AN INTERRUPT IS ALREADY ALLOCATED TO THIS UNIT

SETPIO1:PUSH	AF		;D
	LD	A,'['		;D
	CALL	COUT		;D
	LD	A,(IY)		;D
	CALL	PRTHEXBYTE	;D
	LD	A,']'		;D
	CALL	COUT		;D
	POP	AF		;D

	BIT	2,E			; SKIP IF WE ARE NOT REQUESTING 
	JP	Z,SETPIO2		; AN INTERRUPT

	PRTS("[INTREQ]$")	;D

;	LD	A,(IY+4)		; GET CURRENT INTERRUPT SETTING
;	BIT	2,A			; SKIP IF IT IS ALREADY
;	JP	NZ,SETPIO2		; ALLOCATED TO THIS UNIT

	LD	A,(INT_ALLOC)		; WE NEED TO ALLOCATE AN
	CP	INT_ALLOW		; INTERRUPT. DO WE HAVE 
	JR	NC,BAD_SET		; ONE FREE?

	PRTS("[ALLOCINT]$")	;D

	; WHICH INTERRUPT IS FREE ?
	; SCAN THROUGH THE CFG TABLES
	; AND FIND A FREE ONE

	PUSH	AF			; NESTED LOOP
	LD	DE,CFG_SIZ		; OUTSIDE LOOP IS INTERRUPT
	LD	B,INT_ALLOW		; INSIDE LOOP IS DEVICE
SETPIOP: LD	C,B 
	 DEC	C
	 PUSH	BC
	 LD	B,PIO_CNT
	 LD	HL,PIO_CFG+4
SETPIOX: LD	A,(HL)
	 BIT	2,A			; JUMP TO NEXT DEVICE
	 JR	Z,SETPIOY		; IF NO INTERRUPT ON 
	 AND	00000011B		; THIS DEVICE

	 CP	C			; IF WE MATCH AN INTERRUPT HERE THEN IT IS NOT FREE.
	 JR	NZ,SETPIOY		; SO EXIT INSIDE LOOP AND TRY NEXT INTERRUPT

	 XOR	A			; WE MATCH INT 0 - IF WE ARE CHECKING FOR IT THEN
	 OR	C			; WE REGARD IS AS FREE.
	 JR	NZ,SETPIOZ

SETPIOY: ADD	HL,DE			
	 DJNZ	SETPIOX

	 JR	SETPIOQ			; WE GET HERE IF THE CURRENT INTERRUPT
					; WAS NOT MATCHED SO IT IS FREE
SETPIOZ: POP	BC
	DJNZ	SETPIOP
	POP	AF

	PRTS("[NONEFREE]$")
	RET

SETPIOQ:PUSH	AF			; AVAILABLE INTERRUPT IS IN C
	PRTS("[FREE]=$")
	LD	A,C
	CALL	PRTHEXBYTE
	POP	AF

	POP	AF			
	POP	AF

SETPIOR:LD	HL,INT_ALLOC		; INCREASE THE COUNT
	INC	(HL)			; OF USED INTERRUPTS
	LD	A,(HL)

;	LD	A,(IY)			; IS THIS UNIT 
;	INC	A			; UNITIALIZED?
;	JR	Z,SETPIO6

	LD	A,(IY+4)		; IT IS UNITIALIZED SO
	OR	C			; SAVE THE ALLOCATES 
	LD	(IY+4),A		; INTERRUPT
;
; FOR THIS DEVICE AND INTERRUPT, UPDATE THE CONFIG TABLE FOR THIS DEVICE.
; PIO_IN, PIO_OUT, PIO_IST, PIO_OST ENTRIES NEED TO BE REDIRECTED.
; INTERRUPT VECTOR NEEDS TO BE UPDATED
;
	LD	A,(IY+0)
	LD	HL,0
	; SETUP PIO INTERRUPT VECTOR IN IVT
	LD	HL,HBX_IV09+1

;	CALL	SPK_BEEP
;
SETPIO6:RET	

	; EXIT WITH FREE INTERRUPT IN C

	LD	A,C
	LD	(INT_ALLOC),A

	LD	A,E
	AND	11000000B
	OR	00000100B
	OR	C
	LD	E,A
	LD	(IY+5),A
;
	; TODO: DEALLOCATE AN INTERRUPT
;
;	LD	A,(INT_ALLOC)
;	DEC	A
;	LD	(INT_ALLOC),A
;
SETPIO2:

;	DE CONTAINS THE MODE IF INTERRUPT ROUTINE SKIPPED

	PRTS("[NOINTREQ]$")	;D

;	LD	A,(IY+4)
	LD	A,E			; GET MODE AND CREATE COMMAND
	AND	11000000B		; $B0
	OR	00001111B		; $0F	

	LD	C,(IY+3)		; GET DATA PORT
	INC	C			; POINT TO CMD
	INC	C			; PORT	
	OUT	(C),A			; SET MODE
	CP	(M_BitCtrl | $0F)	; IF MODE 3
	JR	NZ,SETPIO3		
	LD	A,(IY+5)		; SET I/O DIRECTION
	OUT	(C),A			; FOR MODE 3

SETPIO3:; INTERUPT HANDLING

	JP	SETPIO4

	; SETUP THE INTERRUPT VECTOR

	LD	A,E
	AND	00000011B
;	DEC	A			; INDEX INTO THE
	ADD	A,A			; THE VECTOR TABLE
	ADD	A,A			; 
	LD	C,A
	LD	B,0
	LD	HL,HBX_IV09+1
	ADD	HL,BC			; GET THE ADDRESS OF
	PUSH	DE
	LD	D,(HL)			; THAT INTERRUPT
	INC	HL			; HANDLER
	LD	E,(HL)
	LD	HL,0	;HBX_IVT+IVT_PIO0	; POPULATE THE
	LD	A,L			; GET LOW BYTE OF IVT ADDRESS
	ADD	HL,BC			; INTERRUPT TABLE
	LD	(HL),D			; WITH THE INTERRUPT
	INC	HL			; HANDLER ADDRESS FOR
	LD	(HL),E			; THIS UNIT
	POP	DE
	LD	HL,INT_ALLOC
	LD	C,(HL)
	LD	B,0
	LD	HL,PRTTAB-1		; SAVE THE DATA	
	ADD	HL,BC			; PORT FOR EACH INTERRUPT
	LD	C,(IY+3)		
	LD	(HL),C

	INC	C			; POINT TO CMD PORT
	INC	C
	DI				; SET THE VECTOR ADDRESS
	OUT	(C),A

;	LD	A,10000011B		; ENABLE INTERRUPTS ON
	OUT	(C),A			; THIS UNIT
	EI	
;	JR	GUD_SET
;
SETPIO4:LD	A,00000111B		; $07 
	OUT	(C),A			; NO INTERRUPTS
;
;	SUCCESSFULL SO SAVE DEVICE CONFIGURATION WORD (DCW)
;
GUD_SET:LD	(IY+4),E		; LOW BYTE
	LD	(IY+5),D		; HIGH BYTE	
;
;	UPDATE THE DEVICE TABLE WITH THE ADDRESSES FOR THE CORRECT ROUTINE.
;
	LD	A,E
	AND	00000111B
	LD	HL,INTMATRIX		; POINT TO EITHER THE INTERRUPT
	JR	NZ, USEIM
	LD	HL,POLMATRIX		; MATRIX OR THE POLLED MATRIX
USEIM:	PUSH	HL	

	PUSH	IY			; CALCULATE THE DESTINATION
	POP	HL			; ADDRESS IN THE PIO_CFG TABLE
	LD	BC,8			; FOR THE FOUR ADDESSES TO BE 
	ADD	HL,BC			; COPIED TO 

;	LD	B,0			; 00000000 CALCULATE THE SOURCE ADDRESS
	LD	C,E			; XX?????? FROM THE MATRIX. EACH ENTRY 
	SRL	C			; 0XX????? IN THE MATRIX IS 8 BYTES SO
	SRL	C			; 00XX???? SOURCE = MATRIX BASE + (8 * MODE)
	SRL	C			; 000XX???
	POP	DE			; LOAD THE MATRIX BASE
;	LD	DE,POLMATRIX
	EX	DE,HL
	ADD	HL,BC			; HL = SOURCE

	LD	C,8			; COPY 8 BYTES
	LDIR

;	PUSH	IY
;	POP	DE
;	CALL	DUMP_BUFFER

	XOR	A
	RET

PRTTAB:	.DB	0
	.DB	0
	.DB	0
	.DB	0
;
;-----------------------------------------------------------------------------
;
; INPUT INTERRUPT VECTOR MACRO AND DEFINITION FOR FOUR PORTS
;
#DEFINE	PIOMIVT(PIOIN,PIOIST,PIOPRT) 		\
#DEFCONT ;\
#DEFCONT ;	RETURN WITH ERROR IF THERE IS	\
#DEFCONT ;	ALREADY	A CHARACTER IN BUFFER	\
#DEFCONT ;\
#DEFCONT ;	OTHERWISE CHANGE THE STATUS TO	\
#DEFCONT ;	SHOW THERE IS ONE CHARACTER IN	\
#DEFCONT ;	THE BUFFER AND READ IT IN AND	\
#DEFCONT ;	AND STORE IT.RETURN GOOD STATUS.\
#DEFCONT ;\
#DEFCONT \	LD	A,(_CIST)
#DEFCONT \	OR	A
#DEFCONT \	JR	NZ,_OVFL
#DEFCONT \	LD	A,(PIOPRT)
#DEFCONT \	LD	C,A
#DEFCONT \	LD	A,1
#DEFCONT \	LD	(_CIST),A
#DEFCONT \	IN	A,(C)
#DEFCONT \	LD	(_CICH),A
#DEFCONT \	OR	$FF
#DEFCONT \	RET
#DEFCONT \_OVFL:XOR	A
#DEFCONT \	RET
#DEFCONT ;\
#DEFCONT ;\
#DEFCONT ;\
#DEFCONT ;\
#DEFCONT ;\
#DEFCONT ;\
#DEFCONT \PIOIN:CALL	PIOIST
#DEFCONT \	JR	Z,PIOIN
#DEFCONT \	LD	A,(_CICH)
#DEFCONT \	LD	E,A
#DEFCONT \	XOR	A
#DEFCONT \	LD	(_CIST),A
#DEFCONT \	RET
#DEFCONT ;\
#DEFCONT ;	If THERE A CHARACTER		\
#DEFCONT ;	AVAILABLE? RETURN NUMBER	\
#DEFCONT ;	IN A - 0 OR 1			\
#DEFCONT ;\
#DEFCONT \PIOIST:LD	A,(_CIST)
#DEFCONT \	AND	00000001B
#DEFCONT \	RET
#DEFCONT ;\
#DEFCONT ;	CIST :	01 = CHARACTER READY ELSE NOT READY	\
#DEFCONT ;	CISH :	CHARACTER STORED BY INTERRUPT		\
#DEFCONT ;\
#DEFCONT \_CIST	.DB	00
#DEFCONT \_CICH	.DB	00
;
PIOIVT0:.MODULE	PIOIVT0
PIOMIVT(PIO0IN,PI0_IST,PRTTAB+0)
PIOIVT1:.MODULE PIOIVT1
PIOMIVT(PIO1IN,PI1_IST,PRTTAB+1)
PIOIVT2:.MODULE PIOIVT2
PIOMIVT(PIO2IN,PI2_IST,PRTTAB+2)
PIOIVT3:.MODULE PIOIVT3
PIOMIVT(PIO3IN,PI3_IST,PRTTAB+3)
;
;-----------------------------------------------------------------------------
;
; OUTPUT INTERRUPT VECTOR MACRO AND DEFINITION FOR FOUR PORTS
;
; AN INTERRUPT IS GENERATED WHEN THE RECEIVING DEVICE CAN ACCEPT A CHARACTER
;
#DEFINE	PIOMOVT(PIOOUT,PIOOST,PIOPRT) 		\
#DEFCONT ;\
#DEFCONT ;	RETURN IF WE ARE WAITING FOR A	\
#DEFCONT ;	CHARACTER (COST = 00)		\
#DEFCONT ;\
#DEFCONT ;	IF ZERO CHARACTERS READY 
#DEFCONT ;	(COST = 01) CHANGE STATUS TO	\
#DEFCONT ;	WAITING FOR CHARACTER (COST 00)	\
#DEFCONT ;\
#DEFCONT ;	IF A CHARACTER IS READY THEN	\
#DEFCONT ;	OUTPUT AND CHANGE STATUS TO	\
#DEFCONT ;	ZERO CHARACTERS READY		\
#DEFCONT ;\
#DEFCONT \	LD	A,(_COST)
#DEFCONT \ 	DEC	A
#DEFCONT \	RET	M
#DEFCONT \	JR	Z,_WFC
#DEFCONT \	LD	A,(_COCH)
#DEFCONT \	LD	E,A
#DEFCONT \_ONOW:LD	A,(PIOPRT)
#DEFCONT \	LD	C,A
#DEFCONT \	OUT	(C),E
#DEFCONT \ 	LD	A,1
#DEFCONT \_WFC:	LD	(_COST),A
#DEFCONT \	RET
#DEFCONT ;\
#DEFCONT ;	WAIT FOR SPACE FOR THE CHARACTER\
#DEFCONT ;	IF WE ARE WAITING FOR A		\
#DEFCONT ;	CHARACTRE THEN OUTPUT IT NOW	\
#DEFCONT ;	OTHERWISE STORE IT UNTIL THE	\
#DEFCONT ;	INTERRUPT CALLS FOR IT		\
#DEFCONT ;\
#DEFCONT \PIOOUT:LD	A,(_COST)
#DEFCONT \	CP	2
#DEFCONT \	JR	C,_ONOW
#DEFCONT \	LD	A,E
#DEFCONT \	LD	(_COCH),A
#DEFCONT \	LD	A,2
#DEFCONT \	LD	(_COST),A
#DEFCONT \	JR	PIOOUT
#DEFCONT ;\
#DEFCONT ;	RETURN WITH NUMBER OF		\
#DEFCONT ;	CHARACTERS AVAILABLE 0 or 1	\
#DEFCONT ;\
#DEFCONT \PIOOST:LD	A,(_COST)
#DEFCONT \	DEC	A
#DEFCONT \	DEC	A
#DEFCONT \	RET	Z
#DEFCONT \	LD	A,1
#DEFCONT \	RET
#DEFCONT ;\
#DEFCONT ;	COST :	00 WAITING FOR CHARACTER\
#DEFCONT ;		01 ZERO CHARACTERS READY\
#DEFCONT ;		02 ONE CHARACTER READY	\
#DEFCONT ;	COCH :	CHARACTER TO OUTPUT	\
#DEFCONT ;\
#DEFCONT \_COST	.DB	01
#DEFCONT \_COCH	.DB	00
;
PIOOVT0:.MODULE	PIOOVT0
PIOMOVT(PIO0OUT,PI0_OST,PRTTAB+0)
PIOOVT1:.MODULE PIOOVT1
PIOMOVT(PIO1OUT,PI1_OST,PRTTAB+1)
PIOOVT2:.MODULE PIOOVT2
PIOMOVT(PIO2OUT,PI2_OST,PRTTAB+2)
PIOOVT3:.MODULE PIOOVT3
PIOMOVT(PIO3OUT,PI3_OST,PRTTAB+3)
;
;-----------------------------------------------------------------------------
;
; NON INTERRUPT OUTPUT ROUTINE - SHARED
;
; INPUT WILL ALWAYS RETURN ERROR, CHARACTER RETURNED IS UNDEFINED.
; OUTPUT WILL ALWAYS RETURN SUCCESS
; INPUT-STATUS WILL ALWAYS RETURN 0 CHARACTERS IN BUFFER.
; OUTPUT-STATUS WILL ALWAYS RETURN 1 CHARACTER SPACE IN BUFFER.

PIOSHO_IN:
	LD	A,1
	RET
;
PIOSHO_OUT:	
	LD	C,(IY+3)
	OUT	(C),E
	XOR	A
	RET
;
PIOSHO_IST:	XOR	A
	RET
;
PIOSH_OST:	
	LD	A,1
	RET
;
;-----------------------------------------------------------------------------
;
; NON INTERRUPT INPUT ROUTINE - SHARED
;
; INPUT WILL ALWAYS A CHARACTER AND SUCCESS.
; OUTPUT WILL ALWAYS RETURN FAILURE
; INPUT STATUS WILL ALWAYS RETURN 1 CHARACTER IN BUFFER.
;OUTPUT-STATUS WILL ALWAYS RETURN 0 CHARACTER SPACE IN BUFFER.
;
PIOSHI_IN:
	LD	C,(IY+3)
	IN	A,(C)
	LD	E,A
	XOR	A
	RET
;
PIOSHI_OUT:
	LD	A,1
	RET
;
PIOSH_IST:
	LD	A,1
	RET
;
PIOSHI_OST:
	XOR	A
	RET
;
;-----------------------------------------------------------------------------
;
; ON ENTRY IY POINTS TO THE DEVICE RECORD. GET AND RETURN THE CONFIGURATION WORD IN DE
;
PIO_QUERY:
PPI_QUERY:
	LD	E,(IY+4)		; FIRST CONFIG BYTE TO E
	LD	D,(IY+5)		; SECOND CONFIG BYTE TO D
	XOR	A			; SIGNAL SUCCESS
	RET
;
;-----------------------------------------------------------------------------
;
; ON ENTRY IY POINTS TO THE DEVICE RECORD. FOR CHARACTER DEVICES BIT 6 OF ATTRIBUTE
; INDICATES PARALLEL PORT IF 1 SO WE SET IT. COMMON TO ALL PORTS
;
PIO_DEVICE:
PPI_DEVICE:
	LD	D,CIODEV_PIO		; D := DEVICE TYPE
	LD	E,(IY)			; E := PHYSICAL UNIT
	LD	C,$40			; C := ATTRIBUTE
	LD	H,0			; H := 0, DRIVER HAS NO MODES
	LD	L,(IY+3)		; L := BASE I/O ADDRESS
	XOR	A			; SIGNAL SUCCESS
	RET
;
INTMATRIX:
	.DW	PIO0IN,	PIO0OUT, PI0_IST, PI0_OST
	.DW	PIO1IN,	PIO1OUT, PI1_IST, PI1_OST
	.DW	PIO2IN,	PIO2OUT, PI2_IST, PI2_OST
	.DW	PIO3IN,	PIO3OUT, PI3_IST, PI3_OST
POLMATRIX:
	.DW	PIOSHO_IN, PIOSHO_OUT, PIOSHO_IST, PIOSH_OST	; OUTPUT
	.DW	PIOSHI_IN, PIOSHI_OUT, PIOSH_IST,  PIOSHI_OST	; INPUT
	.DW	0,0,0,0						; BIDIR	
	.DW	0,0,0,0						; BIT MODE

SET_8255:
	RET	
;
SET_BYE:
	XOR	A			; SIGNAL SUCCESS
	RET
;
; ------------------------------------
; i8255 FUNCTION TABLE ROUTINES
;-------------------------------------
	
PPI_IN:
	XOR	A			; SIGNAL SUCCESS
	RET	
;
PPI_OUT:
	XOR	A			; SIGNAL SUCCESS
	RET
;	
PPI_IST:
	RET	
;	
PPI_OST:
	RET
;
; PIO_INITDEV - Configure device.
; If DE = FFFF then extract the configuration information from the table of devices and program the device using those settings.
; Otherwise use the configuration information in DE to program those settings and save them in the device table

PPI_INITDEV:
	XOR	A			; SIGNAL SUCCESS
	RET	
PPI_INT:OR	$FF			; NZ SET TO INDICATE INT HANDLED
	RET
;	
PIO_PRTCFG:
	; ANNOUNCE PORT
	CALL	NEWLINE			; FORMATTING
	PRTS("PIO$")			; FORMATTING
	LD	A,(IY)			; DEVICE NUM
	CALL	PRTDECB			; PRINT DEVICE NUM
	PRTS(": IO=0x$")		; FORMATTING
	LD	A,(IY+3)		; GET BASE PORT
	CALL	PRTHEXBYTE		; PRINT BASE PORT
;
	; PRINT THE PIO TYPE
	CALL	PC_SPACE		; FORMATTING
	LD	A,(IY+1)		; GET PIO TYPE BYTE
	LD	DE,PIO_TYPE_STR		; POINT HL TO TYPE MAP TABLE
	CALL	PRTIDXDEA

	; ALL DONE IF NO PIO WAS DETECTED
	LD	A,(IY+1)		; GET PIO TYPE BYTE
	OR	A			; SET FLAGS
	RET	Z			; IF ZERO, NOT PRESENT
;
	PRTS(" MODE=$")			; FORMATTING
	LD	E,(IY+4)		; LOAD CONFIG
	LD	D,(IY+5)		; ... WORD TO DE
	CALL	PS_PRTPC0		; PRINT CONFIG
;
	LD	A,(IY+4)		; PRINT
	BIT	2,A			; ALLOCATED
	JR	Z,NOINT			; INTERRUPT
	PRTS("/i$")
	LD	A,(IY+4)
	AND	00000011B
	CALL	PRTDECB
NOINT:	XOR	A
	RET
;
; WORKING VARIABLES
;
PIO_DEV		.DB	0		; DEVICE NUM USED DURING INIT
;	
; DESCRIPTION OF DIFFERENT PORT TYPES
;
PIO_TYPE_STR:
		.TEXT	"<NOT PRESENT>$"	; IDX 0
		.TEXT	"Zilog PIO$"		; IDX 1
		.TEXT	"i8255 PPI$"		; IDX 2
		.TEXT	"IO Port$"		; IDX 3
;
; Z80 PIO PORT TABLE - EACH ENTRY IS FOR 1 CHIP I.E. TWO PORTS
;
;	32 BYTE DATA STRUCTURE FOR EACH PORT
;
;	.DB	0		; IY+0 CIO DEVICE NUMBER 			(SET DURING PRE-INIT, THEN FIXED)
;	.DB	0		; IY+1 PIO TYPE 				(SET AT ASSEMBLY, FIXED)
;	.DB	0		; IY+2 PIO CHANNEL				(SET AT ASSEMBLY, FIXED)
;	.DB	PIOBASE+2	; IY+3 BASE DATA PORT				(SET AT ASSEMBLY, FIXED)
;	.DB	0		; IY+4 SPW - MODE 3 I/O DIRECTION BYTE		(SET AT ASSEMBLE, SET WITH INIT)
;	.DB	0		; IY+5 SPW - MODE, INTERRUPT			(SET AT ASSEMBLY, SET WITH INIT)
;	.DW	0		; IY+6/7 FUNCTION TABLE				(SET AT ASSEMBLY, SET DURING PRE-INIT AND AT INIT)
;	.DW	PIO_IN		; IY+8  ADDR FOR DEVICE INPUT			(SET WITH INIT)
;	.DW	PIO_OUT		; IY+10 ADDR FOR DEVICE OUTPUT			(SET WITH INIT)
;	.DW	PIO_IST		; IY+12 ADDR FOR DEVICE INPUT STATUS		(SET WITH INIT)
;	.DW	PIO_OST		; IY+14 ADDR FOR DEVICE OUTPUT STATUS		(SET WITH INIT)
;	.DW	PIO_INITDEV	; IY+16 ADDR FOR INITIALIZE DEVICE ROUTINE	(SET AT ASSEMBLY, FIXED)
;	.DW	PIO_QUERY	; IY+18 ADDR FOR QUERY DEVICE RECORD ROUTINE	(SET AT ASSEMBLY, FIXED)
;	.DW	PIO_DEVICE	; IY+20 ADDR FOR DEVICE TYPE ROUTINE		(SET AT ASSEMBLY, FIXED)
;	.FILL	10
;
;	SETUP PARAMETER WORD:
;
;	+-------------------------------+ +-------+-----------+---+-------+
;	|         BIT CONTROL           | | MODE  |           | A |  INT  |
;	+-------------------------------+ --------------------+-----------+
;	 F   E   D   C   B   A   9   8     7   6   5   4   3   2   1   0
;	-- MSB (D REGISTER) --           -- LSB (E REGISTER) --
;
;
; 	MSB = BIT CONTROL MAP USE IN MODE 3 
;
; 	MODE B7 B6 =	00 Mode 0 Output
;			01 Mode 1 Input
;			10 Mode 2 Bidir
;			11 Mode 3 Bit Mode
;
;	INTERRUPT ALLOCATED B2	= 0 NOT ALLOCATED
;				= 1 IS ALLOCATED
;
;	WHICH IVT IS ALLOCATES B1 B0	00 IVT_PIO0
;					01 IVT_PIO1
;					10 IVT_PIO2
;					11 IVT_PIO3
;	
#DEFINE	DEFPIO(MPIOBASE,MPIOCH0,MPIOCH1,MPIOCH0X,MPIOCH1X,MPIOIN0,MPIOIN1) \
#DEFCONT \ .DB	0
#DEFCONT \ .DB	PIO_ZPIO
#DEFCONT \ .DB	0
#DEFCONT \ .DB	MPIOBASE
#DEFCONT \ .DB	(MPIOCH0|MPIOIN0)
#DEFCONT \ .DB	MPIOCH0X
#DEFCONT \ .DW	0
#DEFCONT \ .DW	0,0,0,0, PIO_INITDEV,PIO_QUERY,PIO_DEVICE
#DEFCONT \ .FILL 2	
#DEFCONT \ .DB	0
#DEFCONT \ .DB	PIO_ZPIO
#DEFCONT \ .DB	1
#DEFCONT \ .DB	MPIOBASE+1
#DEFCONT \ .DB	(MPIOCH1|MPIOIN1)
#DEFCONT \ .DB	MPIOCH1X
#DEFCONT \ .DW	0
#DEFCONT \ .DW	0,0,0,0, PIO_INITDEV,PIO_QUERY,PIO_DEVICE
#DEFCONT \ .FILL 2	
;
; i8255 PORT TABLE - EACH ENTRY IS FOR 1 CHIP I.E. THREE PORTS
;
#DEFINE	DEFPPI(MPPIBASE,MPPICH1,MPPICH2,MPPICH3,MPPICH1X,MPPICH2X,MPPICH3X) \
#DEFCONT \ .DB	0
#DEFCONT \ .DB	PIO_8255
#DEFCONT \ .DB	0
#DEFCONT \ .DB	MPPIBASE
#DEFCONT \ .DB	(MPPICH1|00001000B)
#DEFCONT \ .DB	MPPICH1X
#DEFCONT \ .DW	0
#DEFCONT \ .DW	PPI_IN,PPI_OUT,PPI_IST,PPI_OST,PPI_INITDEV,PPI_QUERY,PPI_DEVICE
#DEFCONT \ .FILL 2
#DEFCONT \ .DB	0
#DEFCONT \ .DB	PIO_8255
#DEFCONT \ .DB	1
#DEFCONT \ .DB	MPPIBASE+2
#DEFCONT \ .DB	(MPPICH2|00010000B)
#DEFCONT \ .DB	MPPICH2X
#DEFCONT \ .DW	0
#DEFCONT \ .DW	PPI_IN,PPI_OUT,PPI_IST,PPI_OST,PPI_INITDEV,PPI_QUERY,PPI_DEVICE
#DEFCONT \ .FILL 2
#DEFCONT \ .DB	0
#DEFCONT \ .DB	PIO_8255
#DEFCONT \ .DB	2
#DEFCONT \ .DB	MPPIBASE+4
#DEFCONT \ .DB	(MPPICH3|00100000B)
#DEFCONT \ .DB	MPPICH3X
#DEFCONT \ .DW	0
#DEFCONT \ .DW	PPI_IN,PPI_OUT,PPI_IST,PPI_OST,PPI_INITDEV,PPI_QUERY,PPI_DEVICE
#DEFCONT \ .FILL 2
;
; HERE WE ACTUALLY DEFINE THE HARDWARE THAT THE HBIOS CAN ACCESS
; THE INIT ROUTINES READ AND SET THE INITIAL MODES FROM THIS INFO
;
PIO_CFG:
;
#IF	PIO_4P
DEFPIO(PIO4BASE+0,M_Output,M_Input,M_BitAllOut,M_BitAllOut,INT_N,INT_N)
DEFPIO(PIO4BASE+4,M_Input,M_Input,M_BitAllOut,M_BitAllOut,INT_N,INT_N)
DEFPIO(PIO4BASE+8,M_Output,M_Output,M_BitAllOut,M_BitAllOut,INT_N,INT_N)
DEFPIO(PIO4BASE+12,M_Output,M_Output,M_BitAllOut,M_Output,INT_N,INT_N)
#ENDIF
#IF	PIO_ZP
DEFPIO(PIOZBASE+0,M_Input,M_Input,M_BitAllOut,M_BitAllOut,INT_N,INT_N)
DEFPIO(PIOZBASE+4,M_Output,M_Output,M_BitAllOut,M_BitAllOut,INT_N,INT_N)
#ENDIF
; PIO_SBC & (PLATFORM == PLT_SBC) & (PPIDEMODE != PPIDEMODE_SBC))

#IF 	PIO_SBC
DEFPPI(PIOSBASE,M_Output,M_Output,M_Output,M_BitAllOut,M_BitAllOut,M_BitAllOut)
#ENDIF
;
PIO_CNT	.EQU	($ - PIO_CFG) / CFG_SIZ 	
;
;-------------------------------------------------------------------
; WHEN WE GET HERE IY POINTS TO THE PIO_CFG TABLE WE ARE WORKING ON.
; C IS THE UNIT NUMBER
;-------------------------------------------------------------------
;
;PIO_INITUNIT:
;	LD	A,C			; SET THE UNIT NUMBER
;	LD	(IY),A	
;
;	LD	DE,-1			; LEAVE CONFIG ALONE
;	CALL	PIO_INITDEV		; IMPLEMENT IT AND RETURN
;	XOR	A			; SIGNAL SUCCESS
;	RET				; AND RETURN
;
PIO_INIT:
;	CALL	SPK_BEEP
	LD	B,PIO_CNT		; COUNT OF POSSIBLE PIO UNITS
	LD	C,0			; INDEX INTO PIO CONFIG TABLE
PIO_INIT1:
	PUSH	BC			; SAVE LOOP CONTROL
	
;	LD	A,C			; PHYSICAL UNIT TO A
;	RLCA				; MULTIPLY BY CFG TABLE ENTRY SIZE (32 BYTES)
;	RLCA				; ...
;	RLCA				; ... TO GET OFFSET INTO CFG TABLE
;	RLCA
;;	RLCA
;	LD	HL,PIO_CFG		; POINT TO START OF CFG TABLE
;	PUSH	AF
;	CALL	ADDHLA			; HL := ENTRY ADDRESS
;	POP	AF
;	CALL	ADDHLA			; HL := ENTRY ADDRESS
;	PUSH	HL			; COPY CFG DATA PTR
;	POP	IY			; ... TO IY
;	POP	IY			; ... TO IY

	CALL	IDXCFG

	LD	A,(IY+1)		; GET PIO TYPE
	OR	A			; SET FLAGS
	CALL	NZ,PIO_PRTCFG		; PRINT IF NOT ZERO
	
;	PUSH	DE	
;	LD	DE,$FFFF		; INITIALIZE DEVICE/CHANNEL
;	CALL	PIO_INITDEV		; BASED ON DPW
;	POP	DE

	POP	BC			; RESTORE LOOP CONTROL
	INC	C			; NEXT UNIT
	DJNZ	PIO_INIT1		; LOOP TILL DONE
;
	XOR	A			; SIGNAL SUCCESS
	RET				; DONE
;
SET_PORT:
	; DEVICE TYPE IS I/O PORT SO JUST WRITE $00 TO IT
	LD	C,(IY+3)
	OUT	(C),A
	XOR	A
	RET

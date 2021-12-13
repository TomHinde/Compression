#include <xc.inc>

;extrn	UART_Setup, UART_Transmit_Message  ; external uart subroutines
extrn	LCD_Setup, LCD_Write_Message, LCD_Write_Hex ; external LCD subroutines
extrn	ADC_Setup, ADC_Read		   ; external ADC subroutines
extrn	SPI_MasterInit, SPI_MasterTransmit
	
psect	udata_acs   ; reserve data space in access ram
counter:    ds 1    ; reserve one byte for a counter variable
delay_count:ds 1    ; reserve one byte for counter in the delay routine
input_h:    ds 1
input_l:    ds 1
sign_1:	    ds 1
carry:	    ds 1

    
psect	udata_bank4 ; reserve data anywhere in RAM (here at 0x400)
myArray:    ds 0x80 ; reserve 128 bytes for message data

psect	data    
	; ******* myTable, data in programme memory, and its length *****
myTable:
	db	'H','e','l','l','o',' ','W','o','r','l','d','!',0x0a
					; message, plus carriage return
	myTable_l   EQU	13	; length of data
	align	2
    
psect	code, abs	
rst: 	org 0x0
 	goto	setup

	; ******* Programme FLASH read Setup Code ***********************
setup:	bcf	CFGS	; point to Flash program memory  
	bsf	EEPGD 	; access Flash program memory
	;call	UART_Setup	; setup UART
	call	LCD_Setup	; setup UART
	call	ADC_Setup	; setup ADC
	call	SPI_MasterInit
	bcf	TRISD0
	bcf	TRISD2
	goto	start
	
	; ******* Main programme ****************************************
start: 	lfsr	0, myArray	; Load FSR0 with address in RAM	
	movlw	low highword(myTable)	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movlw	high(myTable)	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	movlw	low(myTable)	; address of data in PM
	movwf	TBLPTRL, A		; load low byte to TBLPTRL
	movlw	myTable_l	; bytes to read
	movwf 	counter, A	; our counter register

	
measure_loop:
	call	ADC_Read
	movf	ADRESH, W, A	;moves contents of ADRESH into W (can probably delete)
	
	movff	ADRESH,	input_h ;moves ADRESH to input_h
	movff	ADRESL, input_l	;moves ADRESL to input_l	
	
	;movlw	0b00001111
	;movwf	input_h
	;movlw	0b00111001
	;movwf	input_l
	
	movlw	0x00
	movwf	sign_1		;sets sign to 0 by default
	
	btfsc	input_h, 7	;checks sign of input_h
	call	set_sign	;calls sign function if negative
	
	movlw	0b00001111	
	andwf	input_h		;sets sign bits to 0
	
	btfsc	input_h, 3	;calls compression if voltage is above 50% of max input
	call	compression
	
	rrcf	input_h
	rrcf	input_l
	btfss	sign_1, 0
	call	add_offset
	btfsc	sign_1, 0
	call	sub_offset
	
	
	movf	input_h, W, A	
	call	LCD_Write_Hex
	movf	input_l, W, A
	call	LCD_Write_Hex
	
	movlw	0b00010000
	iorwf	input_h
	
	bsf	LATD2
	bcf	LATD2
	movf	input_h, W, A
	call	SPI_MasterTransmit
	movf	input_l, W, A
	call	SPI_MasterTransmit
	bsf	LATD2
	
	bsf	LATD0
	bcf	LATD0
	nop
	nop
	nop
	nop
	nop
	bsf	LATD0
	goto	measure_loop		; goto current line in code
	
	
	; a delay subroutine if you need one, times around loop in delay_count
delay:	decfsz	delay_count, A	; decrement until zero
	bra	delay
	return
	
set_sign:
	movlw	0x01
	movwf	sign_1	;sets sign variable to 1 if called
	return
	
compression:
	movlw	0x00
	movwf	carry		;sets carry bit to 0 by default
	movlw	0b00000111
	andwf	input_h		;subtract threshold voltage
	rrcf	input_h		;division by 2 (shifted right)
	movff	STATUS, carry	;moves status register into 'carry'
	btfsc	carry, 0	;checks if carry bit is 1
	call	carry_set
	rrcf	input_l
	btfsc	carry, 0
	call	set_las1
	
	movlw	0b00001000
	addwf	input_h


	return

carry_set:
	movlw	0x01
	movwf	carry		;sets carry to 1
	return

set_las1:
	movlw	0b00000000
	addwf	input_l
	return
	
add_offset:
	movlw	0b00001000
	addwf	input_h
	return
	
sub_offset:
	comf	input_l
	comf	input_h
	movlw	0b00000111
	andwf	input_h
	return

end	rst
	

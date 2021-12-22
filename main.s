#include <xc.inc>

extrn	LCD_Setup, LCD_Write_Message, LCD_Write_Hex ; external LCD subroutines
extrn	ADC_Setup, ADC_Read		   ; external ADC subroutines
extrn	SPI_MasterInit, SPI_MasterTransmit
	
psect	udata_acs   ; reserve data space in access ram
input_h:    ds 1    ; first 8 bits of input
input_l:    ds 1    ; second 8 bits of input
sign:	    ds 1    ; stores sign (+ve or -ve)
carry:	    ds 1    ; stores carry bit
   
psect	code, abs	
rst: 	org 0x0
 	goto	setup

	; ******* Programme FLASH read Setup Code ***********************
setup:	bcf	CFGS	; point to Flash program memory  
	bsf	EEPGD 	; access Flash program memory
	;call	UART_Setup	; setup UART
	call	LCD_Setup	; setup LDC (for testing only)
	call	ADC_Setup	; setup ADC
	call	SPI_MasterInit  ; calls SPI Initialisation function
	bcf	TRISD0		; initialise LDAC pin as output
	bcf	TRISD2		; initialise CS pin as output
	bcf	TRISD7		; initialise VDD pin as output
	bsf	PORTD, 7	; set VDD to 5V always
	goto	measure_loop
	
	; ******* Main programme ****************************************
	
measure_loop:
	call	ADC_Read	;calls ADC_Read function
	
	movff	ADRESH,	input_h ;moves ADRESH to input_h
	movff	ADRESL, input_l	;moves ADRESL to input_l	
	
	movlw	0b11110100	;these four lines were used to test various input
	movwf	input_h		;voltages instead of using an actual ADC input
	movlw	0b00111001
	movwf	input_l

	bcf	sign, 0		;sets sign variable to 0 by default
	
	btfsc	input_h, 7	;checks sign of input_h
	bsf	sign, 0		;sets sign as 1 if negative
	
	btfsc	sign, 0		;if -ve, inverts input (2s complement)
	call	invert_sign	;incorrect by 1 but this is lost in division by 2
				;for offset
				
	btfsc	input_h, 3	;calls compression if voltage is above 50% of max input,
	call	compression	;this is the threshold voltage
	
	rrcf	input_h		;division by 2
	rrcf	input_l		;division by 2
	btfss	sign, 0		;adds/subtracts offset as required.
	call	add_offset
	btfsc	sign, 0
	call	sub_offset
	
	
	;movf	input_h, W, A	;these four lines of code show the output as a hex
	;call	LCD_Write_Hex	;number on the LCD 
	;movf	input_l, W, A
	;call	LCD_Write_Hex
	
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
	
	

	
set_sign:
	movlw	0x01
	movwf	sign	;sets sign variable to 1 if called
	return
	
invert_sign:
	comf	input_h
	comf	input_l
	return
	
compression:
	bcf	carry, 0	;sets carry bit to 0 by default
	bcf	input_h, 3	;subtract threshold voltage
	rrcf	input_h		;division by 2 (shifted right)
	
	movf	input_l, W
	
	movff	STATUS, carry	;moves status register into 'carry'
	btfsc	carry, 0	;checks if carry bit is 1
	call	carry_set
	rrcf	input_l
	
	movf	input_l, W
	
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
	movlw	0b10000000
	addwf	input_l
	
	movf	input_l, W
	
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
;;; Directives
		PRESERVE8
		THUMB


;;; Equates

; constants

PrelimWait            EQU    0x80000 ; the preliminary wait before the game begins 
ReactTimer            EQU    0x1FFFFF ; reaction time timer
NumCycles             EQU    0x8 ; how many levels the player must complete in order to win
WinningSignalTime     EQU    0x1FFFF ; time the winning signal will be displayed (x2 since the diplay is flashing)
InfiniteWait          EQU    0xFFFFFFFF ; timer for the waiting for a player 
RandomSeedX           EQU    0x184ECA ; random seed X for random number generation
ConstantA             EQU    0x19660D ; constant a for random number generation
ConstantC             EQU    0x3C6EF35F ; constant c for random number generation
proficiencyLevelTime  EQU    0xFFFFFF ; how long the proficiency level of the player is shown
fifteenFlashes        EQU    0xF ; how many times the winning signal flashes
LosingSignalTime      EQU    0x6FFFF; time the losing signal will be displayed (x2 since the diplay is flashing)
	 
;clock enable
RCC_APB2ENR EQU 0x40021018;	
	
;PORT A GPIO - Base Addr: 0x40010800
GPIOA_CRL    EQU        0x40010800    ; (0x00) Port Configuration Register
GPIOA_IDR    EQU        0x40010808    ; (0x08) Port Input Data Register
GPIOA_ODR    EQU        0x4001080C    ; (0x0C) Port Output Data Register

;PORT B GPIO - Base Addr: 0x40010C00
GPIOB_CRL    EQU        0x40010C00    ; (0x00) Port Configuration Register
GPIOB_IDR    EQU        0x40010C08    ; (0x08) Port Input Data Register
GPIOB_ODR    EQU        0x40010C0C    ; (0x0C) Port Output Data Register
			
	
; Vector Table Mapped to Address 0 at Reset, Linker requires __Vectors to be exported
	AREA RESET, DATA, READONLY
	EXPORT 	__Vectors

		
__Vectors DCD 0x20002000 ; stack pointer value when stack is empty
	DCD Reset_Handler ; reset vector
	
	ALIGN


;My program, Linker requires Reset_Handler and it must be exported
	AREA MYCODE, CODE, READONLY
	ENTRY

	EXPORT Reset_Handler
		
	ALIGN
Reset_Handler  PROC 

	BL GPIO_ClockInit ; initialize clock
	BL GPIOx_CRL_Init ; Initialize light pins
	BL waitForPlayer ; period to wait for the player / will enter game play


done  b    done
	ENDP
	

;;;;;;;;;;;;;;;;;; CLOCK INITIALIZATION ;;;;;;;;;;;;;;;;;
;;;GPIO_ClockInit
;; enables clock for port A and B
;; Port A is used for LEDS
;; Port B is used for pushbuttons
;;
;; process: Get value at address of clock enable, enable port A and B (1100) and leave rest alone by ORing

;;; Require: 
;;;    None
;;;
;;; Promise:
;;;     Configures clock for port A and B
;;;		Returns nothing
;;;

	
	ALIGN
GPIO_ClockInit PROC
	MOV R0, #0x55555555

    MOV R1, #0x44444444

    ADDS R0, R0, R1
	push {LR}
	push {r0,r1}
	
	LDR R0, =RCC_APB2ENR 
	LDR R1, [R0]
	ORR R1, #0xC
	STR R1, [R0]
	
	pop {r1,r0}
	
	BX lr
	ltorg
	ENDP
		
;;;;;;;;;;;;;;;;;; I/O LINES INITIALIZATION ;;;;;;;;;;;;;;;;;
;;;GPIOx_CRL_Init
;; enables I/O lines for port A and B
;; Port A has 3 light so we want the pattern 30033 to activate portA0, 1, 4
;; Port B has 1 light so we want the patter 0x3 to activate portB0
;; 3 is pattern 0011 which is general purpose output push-pull with max speed 50MHz

;;; Require: 
;;;    None
;;;
;;; Promise:
;;;     Configures I/O lines for port A and B
;;;		Returns nothing
;;;

	ALIGN
GPIOx_CRL_Init PROC

	push {r0,r1,r3,r4}
	
;; configure the ouput lines for PortA 0, 1, 4
	LDR R3, =0xFFF3FF33
	MOV R3, R3
	LDR R4, =0x30033
	MOV R4, R4
	
	LDR R0, =GPIOA_CRL
	LDR R1, [R0]
	
	AND R1, R3 ; get rid of unwanted values
	ORR R1, R4 ; set only desired bits
	
	STR R1, [R0]
	
;; configure the ouput line for PortB 0
	LDR R3, =0xFFFFFFF3
	LDR R4, =0x3
	
	LDR R0, =GPIOB_CRL
	LDR R1, [R0]
	
	AND R1, R3 ; get rid of unwanted values
	ORR R1, R4 ; set only desired bits
	
	STR R1, [R0]

	pop{r0,r1,r3,r4}
	
	
		
	BX lr
	ltorg
	ENDP

;;;;;;;;;;;;;;;;;; waitForPlayer ;;;;;;;;;;;;;;;;;
;;; waitForPlayer
;; 
;; Read the value of the input, if no buttons are clicked, value will be 0xFFF6, if not that, return to main
;; Turn on / off each light one by one
;;     - the first three lights are on port A 
;;     - the last light is on port B
;; For each light, I have a delay time of 40000 to allow the user to clearly see the lights flashing on and off 

;;; Require: 
;;;    I/O lines must be configured for ports A and B
;;;    Clock must be configured for ports A and B
;;;
;;; Promise:
;;;     Lights flash until the player is ready to start the game
;;;		Returns nothing
;;;

		
	ALIGN
waitForPlayer PROC
	
	
beginWaitForPlayer	
	push{R0-R9}
	
	LDR R7, =InfiniteWait
	LDR R1, =GPIOB_IDR ; all 4 buttons are on input portB 
	
checkPushButton
	
	LDR R2, [R1]
	LDR R3, =0xFFF6
	CMP R2, R3 ; check if any input has changed, if yes, return to main 
	BNE finish
	
	
	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
; turn on the first light
	LDR R8, =0x1 ; first light is on portA0 
	STR R8, [R5]
	
	LDR R9, =0x40000 ; delay time
loop	
	SUB R9, R9, #1 ; decrement counter if not 0
	CMP R9, #0
	BNE loop
	
	
; turn on the second light	
	LDR R8, =0x2 ; second light is on portA1
	STR R8, [R5]
	
	LDR R9, =40000 ; delay time
loop1	
	SUB R9, R9, #1 ; decrement counter if not 0
	CMP R9, #0
	BNE loop1
	
	
; turn on the third light	
	LDR R8, =0x10 ; third light is on portA4
	STR R8, [R5]

	LDR R0, =40000 ; delay time
loop2	
	SUB R0, R0, #1 ; decrement counter if not 0
	CMP R0, #0
	BNE loop2

; turn off the third light	
	LDR R8, =0x0  
	STR R8, [R5]
	
; turn on the fourth light
	LDR R8, =0x1 ; fourth light is on portB0
	STR R8, [R6]
	
	LDR R0, =40000 ; delay time
loop3	
	SUB R0, R0, #1 ; decrement counter if not 0
	CMP R0, #0
	BNE loop3

; turn off the fourth light
	LDR R8, =0x10
	STR R8, [R6]

;decrement large loop counter
	SUB R7, R7, #1
	CMP R7, #0
	BNE checkPushButton
	
;since the lights should flash indefinitely, if counter is at 0, reset it and loop again
   LDR R7, =InfiniteWait
   CMP R7, #0
   BNE checkPushButton

finish

	pop{R0-R9}
	BL normalGamePlay
;the stack pointer will have this line in memory (the next line of the previously branched instruction)
;for it to always return to UC2 (waitForPlayer mode) indefinitely 

	LDR R0, =0x0 
	CMP R0, #0
	BEQ beginWaitForPlayer	

	BX lr
	ltorg
	ENDP

;;;;;;;;;;;;;;;;;; normalGamePlay ;;;;;;;;;;;;;;;;;
;;; normalGamePlay
;; 
;;; Generate a random number between 0 and 3 to randomly turn on the lights
;;; The user has a set amount of time to press the button to proceed to the next level
;;; If he succeeds, the counter is divided by the amount of levels completed
;;; If he fails, we will enter a different function to output his score

;;; Require: 
;;;    I/O lines must be configured for ports A and B
;;;    Clock must be configured for ports A and B
;;;    Must have values for following constants: ReactTimer, PreLimWait, RandomSeedX,
;;;    ConstantA, ConstantC, proficiencyLevelTime, WinningSignalTime, and NumCycles 
;;;
;;; Promise:
;;;     Player will be able to play the game and if they are successful, they
;;;     will see flashing lights to indicate that they won.
;;;     Once complete, they will be returned to the start of the game and will
;;;     be able to play again
;;;
;;;		Returns nothing
;;;

		
	ALIGN
normalGamePlay PROC
	
	push{LR}
	LDR R7, =ReactTimer ; reactTimer
	
	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
	LDR R8, =GPIOB_IDR ; all 4 buttons are on input portB 
	
	LDR R11, =0x0 ; count of how many levels they succeeded
	
;PrelimWait
	 LDR R0, =PrelimWait
PrelimWaitLoop	 
	 SUB R0, R0, #1
	 CMP R0, #0
	 BNE PrelimWaitLoop
	 
	 LDR R1, =RandomSeedX
	 LDR R2, =ConstantA
	 LDR R3, =ConstantC

;; generate a random number using a seed and 2 constants

;; by shifting and ANDing by 3, it is certain that we will generate
;; a number between 0 and 3

randNR 
	 MUL R1, R2, R1 ; a * x
	 ADD R1, R3, R1 ; new x =(a*x) + c
	 MOV R0, R1 ; R0 contains the new seed (copy) since R1 will be overwritten
	 
randomLED	 
	 LSR R1, 30 ; (x >> 30)
	 AND R1, #3 ; (x >> 30)&3

; in the decrementReactTimer function, i store the previous
; randomly generated number in R12 to avoid duplicates
;
; duplicates cause errors for the number of levels completed counter
; the code runs so fast that if there is a duplicate, ONE button press registers
; TWO completed levels if the same light turns on twice in a row
;
; if the number generated is duplicated, add 1 to the seed and regenerate until it generates a different number

; there are 4 number possibilities: 0, 1, 2, 3

 	 CMP R12, R1
	 BNE checkPA0
	 ADD R1, R1, #1
	 CMP R12, R1
	 BNE randNR

	 
;;;;;;;;;;;;;; next 3 'loops explained ;;;;;;;;;;;;;;;;;;;;;;;
;; check if the randomly generated number is 0
;; if not, move on to the next light
;; if it is, turn the light on and start the timer
;; read the input value
;; when the button is pressed, the input will have value 0xFFD6
;; keep decrementing the counter by 1 if the player does not press the button before the timer is up
;; once it is pressed, move to decerementReactTimer to get the player to the next level
;;
;; this process is repeated for each light

checkPA0	 
	 CMP R1, #0
	 BNE checkPA1
	 LDR R4, =0x1 ; first light is on portA0 -> turn it on
	 STR R4, [R5]
	 
startTimerPB4  
	 LDR R9, [R8]
	 LDR R10, =0xFFD6 ; if black button is pressed (associated with light 0),
	 CMP R9, R10
	 BEQ turnOffPB4
	 SUB R7, R7, #1 ; decrement reactTimer by 1
	 CMP R7, #0 ; if timer reaches 0, player lost
	 BEQ endhere
	 CMP R7, #0
	 BNE startTimerPB4 ; keep looping until player presses the button

turnOffPB4
	LDR R4, =0x0 ; first light is on portA0 -> turn it off
	STR R4, [R5]
	ADD R11, R11, #1 ; add 1 to completed levels
	CMP R4, #0
	BEQ decrementReactTimer
	
;;;;;;;;;;;;;; next 3 'loops' explained ;;;;;;;;;;;;;;;;;;;;;;;
;; check if the randomly generated number is 0
;; if not, move on to the next light
;; if it is, turn the light on and start the timer
;; read the input value
;; when the button is pressed, the input will have value 0xFFB6
;; keep decrementing the counter by 1 if the player does not press the button before the timer is up
;; once it is pressed, move to decerementReactTimer to get the player to the next level

checkPA1
	CMP R1, #1
	BNE checkPA4
	LDR R4, =0x2 ; second light is on portA1 -> turn it on
	STR R4, [R5]
	
startTimerPB6  
	 LDR R9, [R8]
	 LDR R10, =0xFFB6 ; if red button is pressed (associated with light 1),
	 CMP R9, R10
	 BEQ turnOffPB6
	 SUB R7, R7, #1 ; decrement reactTimer by 1
	 CMP R7, #0 ; if timer reaches 0, player lost
	 BEQ endhere
	 CMP R7, #0
	 BNE startTimerPB6 ; keep looping until player presses the button

turnOffPB6
	LDR R4, =0x0 ; second light is on portA1 -> turn it off
	STR R4, [R5]
	ADD R11, R11, #1 ; add 1 to completed levels
	CMP R4, #0
	BEQ decrementReactTimer

;;;;;;;;;;;;;; next 3 'loops' explained ;;;;;;;;;;;;;;;;;;;;;;;
;; check if the randomly generated number is 0
;; if not, move on to the next light
;; if it is, turn the light on and start the timer
;; read the input value
;; when the button is pressed, the input will have value 0xFEF6
;; keep decrementing the counter by 1 if the player does not press the button before the timer is up
;; once it is pressed, move to decerementReactTimer to get the player to the next level

checkPA4
	CMP R1, #2
	BNE checkPB0
	LDR R4, =0x10 ; third light is on portA4 -> turn it on
	STR R4, [R5]
	
startTimerPB8  
	 LDR R9, [R8]
	 LDR R10, =0xFEF6 ; if green button is pressed (associated with light 2),
	 CMP R9, R10
	 BEQ turnOffPB8
	 SUB R7, R7, #1 ; decrement reactTimer by 1
	 CMP R7, #0 ; if timer reaches 0, player lost
	 BEQ endhere
	 CMP R7, #0
	 BNE startTimerPB8 ; keep looping until player presses the button

turnOffPB8
	LDR R4, =0x0 ; third light is on portA4 -> turn it off
	STR R4, [R5]
	ADD R11, R11, #1 ; add 1 to completed levels
	CMP R4, #0
	BEQ decrementReactTimer
	
;;;;;;;;;;;;;; next 3 'loops' explained ;;;;;;;;;;;;;;;;;;;;;;;
;; check if the randomly generated number is 0
;; if not, move on to the next light
;; if it is, turn the light on and start the timer
;; read the input value
;; when the button is pressed, the input will have value 0xFDF7
;; keep decrementing the counter by 1 if the player does not press the button before the timer is up
;; once it is pressed, move to decerementReactTimer to get the player to the next level
	
checkPB0
    CMP R1, #3
	BNE decrementReactTimer
	LDR R4, =0x1 ; fourth light is on portB0 -> turn it on
	STR R4, [R6]
	
startTimerPB9  
	 LDR R9, [R8]
	 LDR R10, =0xFDF7 ; if blue button is pressed (associated with light 3),
	 CMP R9, R10
	 BEQ turnOffPB9
	 SUB R7, R7, #1 ; decrement reactTimer by 1
	 CMP R7, #0 ; if timer reaches 0, player lost
	 BEQ endhere
	 CMP R7, #0
	 BNE startTimerPB9 ; keep looping until player presses the button

turnOffPB9
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off
	STR R4, [R6]
	ADD R11, R11, #1 ; add 1 to completed levels
	CMP R4, #0
	BEQ decrementReactTimer
	
;;;;;;;;;;;;decrementing ReactTimer explanation ;;;;;;;;;;;;;;;;;;;
;;; if user succesfully completes the level, the reactTimer gets divided by the number of levels completed

decrementReactTimer
	LDR R4, =NumCycles ; check if the player has won the game
	CMP R11, R4
	BEQ playerWon
	
	LDR R7, =ReactTimer 
	UDIV R7, R7, R11 ; divide the amount of time by the number of levels completed 
	
	MOV R12, R1 ; store the randomly generated number in r12 to avoid duplicates (please see explanation after randLED)
	
	MOV R1, R0 ; reload R1 with the value of the new seed to generate a new random number between 0 and 3
	CMP R7, #0
	BNE randNR
	
endhere
	; if player ends up here, it is because they lost the game
	
	push {LR} ; keep track of link register
	BL whichNumber ; branch to subroutine
	pop{LR} ; pop the link register to be able to return to the waitForPlayer stage
	
playerWon
; if player ends up here, it is because they won the game
; the signal is flashing LEDS
	
	LDR R2, =fifteenFlashes
flashVisible
	LDR R4, =0x13 ; turn on all lights on port A
	STR R4, [R5]
	LDR R4, =0x1 ; turn on light on port B
	STR R4, [R6]
	
	LDR R3, =WinningSignalTime
innerLoop	
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop
	
	LDR R4, =0x0 ; turn off all lights on port A
	STR R4, [R5]
	LDR R4, =0x0 ; turn 0ff light on port B
	STR R4, [R6]
	
	LDR R3, =WinningSignalTime
innerLoopRepeat	
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoopRepeat

	SUB R2, R2, #1
	CMP R2, #0
	BNE flashVisible

;if player completed the game, he is 100% proficient so turn on all the lights

	LDR R4, =0x13 ; turn on all lights on port A
	STR R4, [R5]
	LDR R4, =0x1 ; turn on light on port B
	STR R4, [R6]
	
	LDR R2, =proficiencyLevelTime
proficiencyLevel
	SUB R2, R2, #1
	CMP R2, #0
	BNE proficiencyLevel
	
	LDR R4, =0x0 ; turn off all lights on port A
	STR R4, [R5]
	LDR R4, =0x0 ; turn 0ff light on port B
	STR R4, [R6]
	
	pop{r0-r11}

	BX lr
	ltorg
	ENDP

;;;;;;;;;;;;;;;;;;;whichNumber subroutine explained;;;;;;;;;;;;;;;;;
;; if the player loses the game, he will be branched to this subroutine
;; the goal of this subroutine is to determine how many levels
;; were completed and to branch to the appropriate subroutine
;; to display the correct binary signal

;;; Require: 
;;;   R11 : must contain the number of levels completed
;;;
;;; Promise:
;;;     Player will get branched to the appropriate function to see
;;;     his score dislayed in binary
;;;
;;;		Returns nothing
;;;

	ALIGN
whichNumber PROC

; explanation provided for 1 / 15 as it is the same process for each number

zero
	CMP R11, #0
	BNE one
	B startAgain1

one	
	CMP R11, #1 ; R11 contains the number of levels completed
	BNE two ; if it's not one, move on
	BL failureOne ; display binary signal for number ONE
	pop{LR} ; we want to return to the waitForPlayer afterwards
	LDR R9, =0x0
	CMP R9, #0
	B startAgain1 ; this will branch us back to the waitForPlayer to restart the game
two	
	CMP R11, #2
	BNE three
	BL failureTwo
	pop{LR}
	LDR R9, =0x0
	CMP R9, #0
	B startAgain1
	
three	
	CMP R11, #3
	BNE four
	BL failureThree
	pop{LR}
	LDR R9, =0x0
	CMP R9, #0
	B startAgain1
	
four	
	CMP R11, #4
	BNE five
	BL failureFour
	pop{LR}
	LDR R9, =0x0
	CMP R9, #0
	B startAgain1

five	
	CMP R11, #5
	BNE six
	BL failureFive
	pop{LR}
	LDR R9, =0x0
	CMP R9, #0
	B startAgain1
	
six	
	CMP R11, #6
	BNE seven
	BL failureSix
	pop{LR}
	LDR R9, =0x0
	CMP R9, #0
	B startAgain1
	
seven	
	CMP R11, #7
	BNE eight
	BL failureSeven
	pop{LR}
	LDR R9, =0x0
	CMP R9, #0
	B startAgain1

eight	
	CMP R11, #8
	BNE nine
	BL failureEight
	pop{LR}
	LDR R9, =0x0
	CMP R9, #0
	B startAgain1
	
nine	
	CMP R11, #9
	BNE ten
	BL failureNine
	pop{LR}
	LDR R9, =0x0
	CMP R9, #0
	B startAgain1

ten	
	CMP R11, #10
	BNE eleven
	BL failureTen
	pop{LR}
	LDR R9, =0x0
	CMP R9, #0
	B startAgain1
	
eleven	
	CMP R11, #11
	BNE twelve
	BL failureEleven
	pop{LR}
	LDR R9, =0x0
	CMP R9, #0
	B startAgain1

twelve	
	CMP R11, #12
	BNE thirteen
	BL failureTwelve
	pop{LR}
	LDR R9, =0x0
	CMP R9, #0
	B startAgain1
	
thirteen	
	CMP R11, #13
	BNE fourteen
	BL failureThirteen
	pop{LR}
	LDR R9, =0x0
	CMP R9, #0
	B startAgain1

fourteen	
	CMP R11, #14
	BNE fifteen
	BL failureFourteen
	pop{LR}
	LDR R9, =0x0
	CMP R9, #0
	B startAgain1
	
fifteen	
	CMP R11, #15
	BNE more
	BL failureFifteen
	pop{LR}
	LDR R9, =0x0
	CMP R9, #0
	B startAgain1
	
more	
	BL failureMore
	pop{LR}

startAgain1

	BX lr
	ltorg
	ENDP

;;;;;;;;;;;;;;;;;;;failureX explained;;;;;;;;;;;;;;;;;;;
;; the next 15 subroutines simply display the proper binary number on the lights
;; each subroutine is called from the whichNumber subroutine
;;
;; each function does the same thing:
; turn on the correct lights to display the correct binary number
; flash it 10 times
; return to waitForPlayer


;;; Require: 
;;;    I/O lines must be configured for ports A and B
;;;    Clock must be configured for ports A and B
;;;    Must have value for following constant: LosingSignalTime
;;;
;;; Promise:
;;;     Player will be able to see a visual representation of
;;;     their score. They will be branched back to the beginning 
;;;     of the game and will be able to play again.
;;;
;;;		Returns nothing
;;;


	ALIGN
failureOne PROC

	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
    LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R10, =0xF
oneLoop	
	LDR R4, =0x1 ; first light is on portA0 -> turn it on (0001)
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop1	
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop1
	
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop11
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop11

	SUB R10, R10, #1
	CMP R10, #0
	BNE oneLoop
	
	BX lr
	ltorg
	ENDP
		
	ALIGN
failureTwo PROC

	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
    LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
			
twoLoop
	LDR R4, =0x2 ; second light is on portA1 -> turn it on (0010)
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop2	
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop2
	
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop21	
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop21

	SUB R10, R10, #1
	CMP R10, #0
	BNE twoLoop
	
	BX lr
	ltorg
	ENDP		

	ALIGN
failureThree PROC

	LDR R10, =0xA
	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
    LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
			
threeLoop
	LDR R4, =0x3 ; first + second light on portA1 and portA0 -> turn it on (0011)
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop3	
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop3
	
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop31	
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop31
	

	SUB R10, R10, #1
	CMP R10, #0
	BNE threeLoop

	ADD R10, R10, #1
	
	BX lr
	ltorg
	ENDP
		
		
	ALIGN
failureFour PROC

	LDR R10, =0xA
	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
    LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
			
fourLoop
	LDR R4, =0x10 ; third light is on portA4 -> turn it on (0100)
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop4	
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop4
	
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop41	
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop41

	SUB R10, R10, #1
	CMP R10, #0
	BNE fourLoop
	
	BX lr
	ltorg
	ENDP		

		
	ALIGN
failureFive PROC

	LDR R10, =0xA
	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
    LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]

fiveLoop
	LDR R4, =0x11 ; first + third light on portA0 and portA4 -> turn it on (0101)
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop5
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop5
	
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop51
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop51

	SUB R10, R10, #1
	CMP R10, #0
	BNE fiveLoop
	
	BX lr
	ltorg
	ENDP

	ALIGN
failureSix PROC

	LDR R10, =0xA
	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
    LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]

sixLoop
	LDR R4, =0x12 ; second + third light on portA1 and portA4 -> turn it on (0110)
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop6
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop6
	
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop61
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop61

	SUB R10, R10, #1
	CMP R10, #0
	BNE sixLoop
	
	BX lr
	ltorg
	ENDP

	ALIGN
failureSeven PROC

	LDR R10, =0xA
	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
    LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]

sevenLoop
	LDR R4, =0x13 ; first + second + third light on portA0 and portA1 and portA4 -> turn it on (0111)
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop7
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop7
	
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop71
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop71

	SUB R10, R10, #1
	CMP R10, #0
	BNE sevenLoop
	
	BX lr
	ltorg
	ENDP


	ALIGN
failureEight PROC

	LDR R10, =0xA
	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
    LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]

eightLoop
	LDR R4, =0x1 ; fourth light is on portB0 -> turn it on (1000)
	STR R4, [R6]
	
	LDR R3, =LosingSignalTime
innerLoop8
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop8
	
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop81
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop81

	SUB R10, R10, #1
	CMP R10, #0
	BNE eightLoop
	
	BX lr
	ltorg
	ENDP


	ALIGN
failureNine PROC

	LDR R10, =0xA
	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
    LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]

nineLoop
	LDR R4, =0x1 ; fourth light is on portB0 -> turn it on (1000)
	STR R4, [R6]
	LDR R4, =0x1 ; first light is on portA0 -> turn it on (1001)
	STR R4, [R5]	

	
	LDR R3, =LosingSignalTime
innerLoop9
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop9
	
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop91
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop91

	SUB R10, R10, #1
	CMP R10, #0
	BNE nineLoop
	
	BX lr
	ltorg
	ENDP
	
	ALIGN
failureTen PROC

	LDR R10, =0xA
	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
    LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]

tenLoop
	LDR R4, =0x1 ; fourth light is on portB0 -> turn it on (1000)
	STR R4, [R6]
	LDR R4, =0x2 ; second light is on portA1 -> turn it on (1010)
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop10
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop10
	
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop101
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop101

	SUB R10, R10, #1
	CMP R10, #0
	BNE tenLoop
	
	BX lr
	ltorg
	ENDP

	ALIGN
failureEleven PROC

	LDR R10, =0xA
	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
    LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]

elevenLoop
	LDR R4, =0x1 ; fourth light is on portB0 -> turn it on (1000)
	STR R4, [R6]
	LDR R4, =0x3 ; first + second light on portA0 and portA1 -> turn it on (1011)
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop111
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop111
	
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop1111
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop1111

	SUB R10, R10, #1
	CMP R10, #0
	BNE elevenLoop
	
	BX lr
	ltorg
	ENDP
		
	ALIGN
failureTwelve PROC

	LDR R10, =0xA
	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
    LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]

twelveLoop
	LDR R4, =0x1 ; fourth light is on portB0 -> turn it on (1000)
	STR R4, [R6]
	LDR R4, =0x10 ; third light is on portA4 -> turn it on (1100)
	STR R4, [R5]

	
	LDR R3, =LosingSignalTime
innerLoop12
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop12
	
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop121
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop121

	SUB R10, R10, #1
	CMP R10, #0
	BNE twelveLoop
	
	BX lr
	ltorg
	ENDP

	ALIGN
failureThirteen PROC

	LDR R10, =0xA
	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
    LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]

thirteenLoop
	LDR R4, =0x1 ; fourth light is on portB0 -> turn it on (1000)
	STR R4, [R6]
	LDR R4, =0x11 ; first + third light are on portA4 and portA0 -> turn it on (1101)
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop13
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop13
	
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop131
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop131

	SUB R10, R10, #1
	CMP R10, #0
	BNE thirteenLoop
	
	BX lr
	ltorg
	ENDP
		
	ALIGN
failureFourteen PROC

	LDR R10, =0xA
	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
    LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]

fourteenLoop
	LDR R4, =0x1 ; fourth light is on portB0 -> turn it on (1000)
	STR R4, [R6]
	LDR R4, =0x12 ; second + third light on portA1 and portA4 -> turn it on (1110)
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop14
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop14
	
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop141
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop141

	SUB R10, R10, #1
	CMP R10, #0
	BNE fourteenLoop
	
	BX lr
	ltorg
	ENDP

	ALIGN
failureFifteen PROC

	LDR R10, =0xA
	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
    LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]

fifteenLoop
	LDR R4, =0x1 ; fourth light is on portB0 -> turn it on (1000)
	STR R4, [R6]
	LDR R4, =0x13 ; first + second + third light on portA0 and portA1 and portA4 -> turn it on (1111)
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop15
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop15
	
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoop151
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoop151

	SUB R10, R10, #1
	CMP R10, #0
	BNE fifteenLoop
	
	BX lr
	ltorg
	ENDP
			
	ALIGN
failureMore PROC

	LDR R10, =0xA
	LDR R5, =GPIOA_ODR ; address for 3 lights on port A
	LDR R6, =GPIOB_ODR ; address for light on port B
	
    LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]

moreLoop
	LDR R4, =0x1 ; fourth light is on portB0 -> turn it on (1000)
	STR R4, [R6]
	LDR R4, =0x13 ; first + second + third light on portA0 and portA1 and portA4 -> turn it on (1111)
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoopMore
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoopMore
	
	LDR R4, =0x0 ; fourth light is on portB0 -> turn it off if on
	STR R4, [R6]
	LDR R4, =0x0 ; all other lights on portA -> turn them off if on
	STR R4, [R5]
	
	LDR R3, =LosingSignalTime
innerLoopMore1
	SUB R3, R3, #1
	CMP R3, #0
	BNE innerLoopMore1

	SUB R10, R10, #1
	CMP R10, #0
	BNE moreLoop
	
	BX lr
	ltorg
	ENDP

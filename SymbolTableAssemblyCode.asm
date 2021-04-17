.data

curTok:		.word 	0:3				# 2-word token & its TYPE
tokenTab:	.word	0:60				# 10-entry token table
symTab:		.word	0:80				# 20-entry symbol table

newLine:	.asciiz	"\n"

inBuf:		.space	80
#pound:		.byte	'#'				# end an input line with '#'
saveReg:	.word	0,0,0,0				# space to save up to four registers

LOC:		.word	0x0400
	
		.text
#######################################################################
#
# Main
#
#	read an input line
#	call scanner driver
#	clear buffers
#
#  	Global Registers
#	  $t9: index to inBuf in bytes
#	  $s0: T, char type
#	  $s1: Qx, current State
#  	  $s3: index to the new char space in curTok
#  	  $a3: index to tokArray in 12 bytes per entry
#
######################################################################

newline:
		jal	getline			# get a new input string
	
		li	$t9,0			# $t5: index to inBuf
		li	$a3,0			# $a3: index to tokArray

		# State table driver
		la	$s1, Q0			# initial state ($s1) = Q0
		li	$s0, 1			# initial T ($s0) = 1
driver:		lw	$s2, 0($s1)		# get the action routine
		jalr	$v1, $s2		# execute the action

		sll	$s0, $s0, 2		# compute byte offset of T
		add	$s1, $s1, $s0		# locate the next state
		la	$s1, ($s1)
		lw	$s1, ($s1)		# next State in $s1
		sra	$s0, $s0, 2		# reset $s0 for T
		b	driver			# go to the next state

symStart:
		li	$t9, 0			# index to tokenTab
		li	$s5, 0
		
		
nextTok:	lb	$t8, tokenTab+12
		bne	$t8, ':', operator
		
		lw	$a0, tokenTab		# TOKEN
		lw	$a1, tokenTab+4
		li	$a2, 1			# DEFN = 1
		jal	VAR
		addi	$t9, $t9, 2
		
operator:		
		addi	$t9, $t9, 1
		
		li	$s7, 1			# isComma
chkVar:		
		li	$t0, 12
		mul	$t9, $t9, $t0		# x12 = x3x4
		#sll	$t8, $t9, 2		# x4
		#add	$t8, $t9, $t9
		#add	$t8, $t8, $t9
		
		lb	$t8, tokenTab($t9)
		beq	$t8, '#', dump
		beq	$s7, 0, nextVar
		lw	$t8, tokenTab+8($t9)
		bne	$t8, 2, nextVar
		
		lw	$a0, tokenTab($t9)		# TOKEN
		lw	$a1, tokenTab+4($t9)
		li	$a2, 0			# DEFN = 1
		jal	VAR

nextVar: 
		lb	$t8, tokenTab($t9)
		li	$t0, 12
		div	$t9, $t9, $t0
		li	$s7, 1
		bne	$t8, ',', resetFlag
		b	nextToken
		
resetFlag:	li	$s7, 0
nextToken:

		addi	$t9, $t9, 1
		b	chkVar
		
dump:		
		jal	clearInBuf		# clear input buffer
		jal	clearTokTab		# clear tokenTab
		jal	printSymTab
		
		lw	$t0, LOC
		addi	$t0, $t0, 4
		sw	$t0, LOC
		
		b 	newline



#####################
# VAR
#	$s5 will store the current index in the symbol table to add things in 
#
#       defn stored at a2
#	token stored at a0, a1  
######################
.data
test:	space	8

.text

VAR:
	
	la	$v0, srchSymTab
	jalr	$v1, $v0
	
	bge	$t5, 0, varElse
	li	$a3, 4
	or	$a3, $a3, $a2
	la	$v0, saveSymTab
	jalr	$v1, $v0

	move	$s1, $a3
	

	b	varReturn
varElse:

	sll	$t5, $t5, 4
	lw	$t4, symTab + 12($t5)
	and	$t3, $t4, 2
	and	$t2, $t4, 1
	sll	$t2, $t2, 1
	or	$a3, $t3, $t2
	or	$a3, $a3, $a2
	sw	$a3, symTab + 12($t5)
	move	$s1, $a3
	srl	$t5, $t5, 4

	
varReturn:
	la	$s0, symACTS
	sll	$s1, $s1, 2
	add	$s0, $s0, $s1
	jr	$s0
	
retSymAct: 		
	jr	$ra
		
		
		

########################
#
##########################
symACTS:	b	symACT0
		b	symACT1
		b	symACT2
		b	symACT3
		b	symACT4
		b	symACT5

	.data

errorCode:	.asciiz	"Double Definition Error"

	.text
symACT0:

	sll	$t5, $t5, 4
	lw	$t7, LOC
	sw	$t7, symTab + 8($t5)
	srl	$t5, $t5, 4
	b	retSymAct
	
symACT1:

	sll	$t5, $t5, 4
	lw	$t7, LOC
	sw	$t7, symTab + 8($t5)
	srl	$t5, $t5, 4
	b	retSymAct

symACT2:
	
	b	retSymAct

symACT3:

	la	$a0, errorCode
	li	$v0, 4
	syscall
	b	retSymAct

symACT4:
	
	sll	$t5, $t5, 4
	lw	$t7, LOC
	sw	$t7, symTab + 8($t5)
	srl	$t5, $t5, 4
	b	retSymAct

symACT5:	

	sll	$t5, $t5, 4
	lw	$t7, LOC
	sw	$t7, symTab + 8($t5)
	srl	$t5, $t5, 4
	b	retSymAct


##################
#
#	search symbol table
#	input: token stored in a0, a1
#	output: int -1 if not found in table or the index value where the label was found return in $t5
#################
	.text
srchSymTab:
		li	$t0, 0			#i = 0
searchLoop:	
		bge	$t0, 20, fail 
		sll	$t0, $t0, 4
		lw	$t1, symTab($t0)
		lw	$t6, symTab + 4($t0)
		srl	$t0, $t0, 4
		bne	$a0, $t1, else
		bne	$a1, $t6, else

		
		move	$t5, $t0
		b	return
else:
	addi	$t0, $t0, 1
	b	searchLoop
fail:
		li	$t5, -1
return:
		jr	$v1

##################
#
#	takes the input of the token you want to store in the a0 and a1 register and newstatus in a3 and stores it at the next avilable index in the table
#	
#	ouptut symbol index in t5
#################
saveSymTab:

	sll	$s5, $s5, 4

	sw	$a0, symTab($s5)
	sw	$a1, symTab + 4($s5)
	sw	$a3, symTab + 12($s5)
	
	srl	$s5, $s5, 4
	
	move	$t5, $s5
	
	addi	$s5, $s5, 1

	jr	$v1
		
##################
#
#	printSymTab
#	
#	
#################	
	.data
header:		.asciiz	"Token             Address         Status\n-------------------------------------------\n"
space:		.asciiz	"          "
hex:		.asciiz	"0x"
	
	.text
printSymTab:
		la	$a0, newLine
		li	$v0, 4
		syscall

		la	$a0, header
		syscall
		
		li	$t0, 0			#i = 0
printLoop:	
		bge	$t0, 20, printReturn
		
		sll	$t0, $t0, 4
		la	$a0, symTab($t0)
		lw	$s4, ($a0)
		beq	$zero, $s4, printReturn
		li	$v0, 4
		syscall

		la	$a0, space
		syscall	
		la	$a0, hex
		syscall
		lw	$a0, symTab + 8($t0)
		li	$v0, 1
		syscall
		la	$a0, space
		li	$v0, 4
		syscall
		la	$a0, hex
		syscall
		lw	$a0, symTab + 12($t0)
		li	$v0, 1
		syscall
		li	$v0, 4
		la	$a0, newLine
		syscall
	
		srl	$t0, $t0, 4
		
		addi	$t0, $t0, 1
		b	printLoop
printReturn:
		jr	$ra
		
####################### STATE ACTION ROUTINES #####################
##############################################
#
# ACT1:
#	$t9: global index to inBuf for the next char
#       $a0: search key char from inBuf[$t9]
#	return $s0 with T = char type
#
##############################################
ACT1:
	lb	$a0, inBuf($t9)			# $a0: next char
	jal	lin_search			# $s0 returns T (char type)
	addi	$t9, $t9, 1			# $t9++ to point to the next char in inBuf	lw	$a0, saveReg			# restore $a0
	jr	$v1
	
###############################################
#
# ACT2:
#	$a0: char to save into curTok for the first time
#	$s0: char type as curTok type
#	set remaining curTok space
#
##############################################
ACT2:
	li	$s3, 0				# initialize index to curTok char 
	sb	$a0, curTok($s3)			# save 1st char to curTok
	sb	$s0, curTok+8($s3)		# save T (curTok type)
	addi	$s3, $s3, 1
	jr 	$v1
	
#############################################
#
# ACT3:
#	collect char to curTok
#	update remaining token space
#
#############################################
ACT3:
	bgt	$s3, 7, lenError		# curTok length error
	sb	$a0, curTok($s3)			# save char to curTok
	addi	$s3, $s3, 1			# $s3: global index to curTok
	jr	$v1	
lenError:
	li	$s0, 7				# T=7 for token length error
	jr	$v1
					
#############################################
#
#  ACT4:
#	move curTok to TabTok
#	$a3 - global index into TabTok
#
############################################
ACT4:
	lw	$t0, curTok($0)			# get 1st word of curTok
	sw	$t0, tokenTab($a3)		# save 1st word to tokenTab
	lw	$t0, curTok+4($0)		# get 2nd word of curTok
	sw	$t0, tokenTab+4($a3)		# save 2nd word to tokenTab
	lw	$t0, curTok+8($0)		# get curTok Type
	blt	$t0, 6, ACT4Type		# chartype of 6
	addi	$t0, $t0, -1			#  into token type 5
ACT4Type:
	sw	$t0, tokenTab+8($a3)		# save Token Type to tokemTab
	addi	$a3, $a3, 12			# update index to tokenTab
	
	jal	clearTok			# clear 3-word curTok
	jr	$v1

############################################
#
#  RETURN:
#	End of the input string
#
############################################
RETURN:
	b	symStart				# leave the state table


#############################################
#
#  ERROR:
#	Error statement and quit
#
############################################
	.data
st_error:	.asciiz	"An error has occurred. \n"	

	.text
ERROR:
	la	$a0, st_error			# print error occurrence
	li	$v0, 4
	syscall
	b	dump


############################### BOOK-KEEPING FUNCTIONS #########################
#############################################
#
#  clearTok:
#	clear 3-word curTok after copying it to tokenTab
#
#############################################
clearTok:
	sw	$zero, curTok
	sw	$zero, curTok+4
	sw	$zero, curTok+8
	jr	$ra
	
#############################################
#
#  printline:
#	Echo print input string
#
#############################################
printline:
	la	$a0, inBuf			# input Buffer address
	li	$v0,4
	syscall
	jr	$ra



############################################
#
#  clearInBuf:
#	clear inbox
#
############################################
clearInBuf:
	li	$t0,0
loopInB:
	bge	$t0, 80, doneInB
	sb	$zero, inBuf($t0)		# clear inBuf to 0x0
	addi	$t0, $t0, 4
	b	loopInB
doneInB:
	jr	$ra
	
###########################################
#
# clearTokTab:
#	clear tokenTab
#
###########################################
clearTokTab:
	li	$t0, 0
loopCTok:
	bge	$t0, $a3, doneCTok
	sw	$zero, tokenTab($t0)		# clear
	sw	$zero, tokenTab+4($t0)		#  3-word entry
	sw	$zero, tokenTab+8($t0)		#  in tokArray
	addi	$t0, $t0, 12
	b	loopCTok
doneCTok:
	jr	$ra
	

###################################################################
#
#  getline:
#	get input string into inbox
#
###################################################################
	.data
st_prompt:	.asciiz	"Enter a new input line. \n"

	.text
getline: 
	la	$a0, st_prompt			# Prompt to enter a new line
	li	$v0, 4
	syscall

	la	$a0, inBuf			# read a new line
	li	$a1, 80	
	li	$v0, 8
	syscall
	jr	$ra


##################################################################
#
#  lin_search:
#	Linear search of Tabchar
#
#   	$a0: char key
#   	$s0: char type, T
#
#	return type is initialized to 7 for search failure
#	End of charTab is indicated by 0x7F
#
#################################################################
lin_search:
	li	$t0,0				# i = 0
	li	$s0, 7				# retVal = 7 (char type)
loopSrch:
	lb	$t1, charTab($t0)		# t1 = charTab[i]
	beq	$t1, 0x7F, charFail		# if (t1==end_of_table) goto charFail
	beq	$t1, $a0, charFound		# if (t1==key) goto charFound
	addi	$t0, $t0, 8			# i++8 in bytes
	b	loopSrch			# goto loopSrch

charFound:
	lw	$s0, charTab+4($t0)		# return char type
charFail:
	jr	$ra


	
	
	.data

stateTAB:
Q0:     .word  ACT1
        .word  Q1   # T1
        .word  Q1   # T2
        .word  Q1   # T3
        .word  Q1   # T4
        .word  Q1   # T5
        .word  Q1   # T6
        .word  Q11  # T7

Q1:     .word  ACT2
        .word  Q2   # T1
        .word  Q5   # T2
        .word  Q3   # T3
        .word  Q3   # T4
        .word  Q0   # T5
        .word  Q4   # T6
        .word  Q11  # T7

Q2:     .word  ACT1
        .word  Q6   # T1
        .word  Q7   # T2
        .word  Q7   # T3
        .word  Q7   # T4
        .word  Q7   # T5
        .word  Q7   # T6
        .word  Q11  # T7

Q3:     .word  ACT4
        .word  Q0   # T1
        .word  Q0   # T2
        .word  Q0   # T3
        .word  Q0   # T4
        .word  Q0   # T5
        .word  Q0   # T6
        .word  Q11  # T7

Q4:     .word  ACT4
        .word  Q10  # T1
        .word  Q10  # T2
        .word  Q10  # T3
        .word  Q10  # T4
        .word  Q10  # T5
        .word  Q10  # T6
        .word  Q11  # T7

Q5:     .word  ACT1
        .word  Q8   # T1
        .word  Q8   # T2
        .word  Q9   # T3
        .word  Q9   # T4
        .word  Q9   # T5
        .word  Q9   # T6
        .word  Q11  # T7

Q6:     .word  ACT3
        .word  Q2   # T1
        .word  Q2   # T2
        .word  Q2   # T3
        .word  Q2   # T4
        .word  Q2   # T5
        .word  Q2   # T6
        .word  Q11  # T7

Q7:     .word  ACT4
        .word  Q1   # T1
        .word  Q1   # T2
        .word  Q1   # T3
        .word  Q1   # T4
        .word  Q1   # T5
        .word  Q1   # T6
        .word  Q11  # T7

Q8:     .word  ACT3
        .word  Q5   # T1
        .word  Q5   # T2
        .word  Q5   # T3
        .word  Q5   # T4
        .word  Q5   # T5
        .word  Q5   # T6
        .word  Q11  # T7

Q9:     .word  ACT4
        .word  Q1  # T1
        .word  Q1  # T2
        .word  Q1  # T3
        .word  Q1  # T4
        .word  Q1  # T5
        .word  Q1  # T6
        .word  Q11 # T7

Q10:	.word	RETURN
        .word  Q10  # T1
        .word  Q10  # T2
        .word  Q10  # T3
        .word  Q10  # T4
        .word  Q10  # T5
        .word  Q10  # T6
        .word  Q11  # T7

Q11:    .word  ERROR 
	.word  Q4  # T1
	.word  Q4  # T2
	.word  Q4  # T3
	.word  Q4  # T4
	.word  Q4  # T5
	.word  Q4  # T6
	.word  Q4  # T7
	
	
charTab: 
	.word ' ', 5
 	.word '#', 6
 	.word '$', 4 
	.word '(', 4
	.word ')', 4 
	.word '*', 3 
	.word '+', 3 
	.word ',', 4 
	.word '-', 3 
	.word '.', 4 
	.word '/', 3 

	.word '0', 1
	.word '1', 1 
	.word '2', 1 
	.word '3', 1 
	.word '4', 1 
	.word '5', 1 
	.word '6', 1 
	.word '7', 1 
	.word '8', 1 
	.word '9', 1 

	.word ':', 4 

	.word 'A', 2
	.word 'B', 2 
	.word 'C', 2 
	.word 'D', 2 
	.word 'E', 2 
	.word 'F', 2 
	.word 'G', 2 
	.word 'H', 2 
	.word 'I', 2 
	.word 'J', 2 
	.word 'K', 2
	.word 'L', 2 
	.word 'M', 2 
	.word 'N', 2 
	.word 'O', 2 
	.word 'P', 2 
	.word 'Q', 2 
	.word 'R', 2 
	.word 'S', 2 
	.word 'T', 2 
	.word 'U', 2
	.word 'V', 2 
	.word 'W', 2 
	.word 'X', 2 
	.word 'Y', 2
	.word 'Z', 2

	.word 'a', 2 
	.word 'b', 2 
	.word 'c', 2 
	.word 'd', 2 
	.word 'e', 2 
	.word 'f', 2 
	.word 'g', 2 
	.word 'h', 2 
	.word 'i', 2 
	.word 'j', 2 
	.word 'k', 2
	.word 'l', 2 
	.word 'm', 2 
	.word 'n', 2 
	.word 'o', 2 
	.word 'p', 2 
	.word 'q', 2 
	.word 'r', 2 
	.word 's', 2 
	.word 't', 2 
	.word 'u', 2
	.word 'v', 2 
	.word 'w', 2 
	.word 'x', 2 
	.word 'y', 2
	.word 'z', 2

	.word 0x7F, 0

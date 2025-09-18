.section __TEXT,__text,regular,pure_instructions
.globl _main
.p2align 2

// learn about field programmable gate arrays

// clang -o darwint darwint.s
// DEBUG: lldb ./darwint
/*
    
(lldb) b do_ls
(lldb) b print_run_ls
(lldb) b print_loop

# Step one instruction at a time:
(lldb) si

# Or step over function calls:
(lldb) ni

# Continue to next breakpoint:
(lldb) c

# Show all registers:
(lldb) register read

# Show specific registers:
(lldb) register read x0 x1 x2 x19

# Show memory at address (like your buffer):
(lldb) memory read $x1
(lldb) memory read --size 1 --count 20 $x1    # 20 bytes as hex
(lldb) memory read --format s $x1             # As string

# Show memory at symbol:
(lldb) memory read input_buffer
(lldb) memory read --format s input_buffer

*/

_main:
// Setting up the stack pointer with a pre-decrement for insertion
STP     x29, x30, [sp, #-16]!
MOV	    x29, sp // puts the front of sp in x29 even if it changes

B skip_in_progress

// IN PROG SECTION
ADRP    x3, username@PAGE
ADD	    x3, x3, username@PAGEOFF
MOV	    x16, #24
SVC     #0x80

// Going into the /etc/passwd dir gaddamn it all
ADRP    x0, dir_get_user@PAGE
ADD	    x0, x0, dir_get_user@PAGEOFF
MOV	    x1, #0 // RDONLY i think
MOV	    x16, #5 // SYS_OPEN
SVC     #0x80
MOV	    x19, x0

// SYS_CLOSE



// ls -altFh --color=always
// ls -aAbBcCdDfhiklmnoqrRsStTuvwWxX --block-size=SIZE --color=always --full-time --group-directories-first --human-readable --inode --literal --numeric-uid-gid --quoting-style=WORD --recursive --reverse --si --sort=WORD --time-style=WORD --tabsize=COLS --width=COLS --indicator-style=WORD
// there is a lot going on with ls gadamn

read_passwd_file:
MOV     x16, #3 // SYS_READ
// we do not want an stdin or out we just want to save the username into the username buffer
// FIGURE OUT READING THIS
// Need to parse through the document looking for the UID
// then on match, record the username in the username buffer

skip_in_progress:
main_loop:

// CLEAR BUFFER
// ADRP	x0, input_buffer@PAGE
// ADD	    x0, x0, input_buffer@PAGEOFF
// MOV	    x1, #256
// BL	    clear_buf
// ADRP	x0, temp_buffer@PAGE
// ADD	    x0, x0, temp_buffer@PAGEOFF
// BL	    clear_buf
// ADRP	x0, dir_buffer@PAGE
// ADD	    x0, x0, dir_buffer@PAGEOFF
// MOV	    x1, #4096
// BL	    clear_buf
// THE INITIAL OUTPUT
MOV	    x16, #4 // SYS_WRITE
MOV	    x0, #1  // STDOUT
ADRP    x1, prompt@PAGE
ADD     x1, x1, prompt@PAGEOFF // GETS SPECIFIC ADDY FOR OUR PROMPT
MOV	    x2, #3  // SIZE OF THE PROMPT WE PRINTING
SVC	    #0x80
// USER INPUT
MOV	    x16, #3 // SYS_READ
MOV	    x0, #0 // STDIN
ADRP    x1, input_buffer@PAGE
ADD     x1, x1, input_buffer@PAGEOFF // GETS SPECIFIC ADDY FOR OUR PROMPT
MOV	    x2, #255 // leaving final byte for null term
SVC	    #0x80

ADRP    x1, input_buffer@PAGE
ADD     x1, x1, input_buffer@PAGEOFF
// check for a non_space before a newline
MOV	    x8, #0
empty_check:
LDRB    w4, [x1, x8]
CMP	    w4, #32 // ' '
B.NE    empty_check_2
ADD     x8, x8, #1
B empty_check
empty_check_2:
CMP	    w4, #10 // '\n'
B.EQ main_loop
// Cleaning the input of leading spaces
MOV     x25, #0
copy: // successfully overwriting out input to the start of the input buffer
LDRB    w4, [x1, x8] // should be not 0
STRB    w4, [x1, x25]
CMP	    w4, #10
B.EQ    compare_input
ADD     x8, x8, #1
ADD	    x25, x25, #1
B copy

// NOW READ THE INPUT FROM THE INPUT BUFFER AND COMPARE IT TO KNOWN

compare_input:
ADRP    x1, input_buffer@PAGE
ADD	    x1, x1, input_buffer@PAGEOFF
MOV     x9, #0
BL	    set_up_compare
ADRP    x3, ls@PAGE
ADD	    x3, x3, ls@PAGEOFF
BL	    compare
CMP	    x9, #1
B.EQ	do_ls

exit:
MOV	    x16, #1 // THE SYSTEM CALL FOR EXIT
MOV	    x0, #0 // SUCCESSFUL EXIT
SVC	    #0x80

set_up_compare:
MOV	    x2, #0
RET

compare:
LDRB    w4, [x1, x2]
LDRB    w5, [x3, x2]
CBZ	    w5, skip_check
CMP	    w4, w5
B.NE	compare_fail
ADD	    x2, x2, #1
B       compare
skip_check:
B	    check_word_end
compare_success:
MOV	    x9, 1
compare_fail:
RET

check_word_end:
CMP	    w4, #32
B.EQ	check_word_end_pt2
CMP	    w4, #10
B.EQ    check_word_end_pt2
CMP	    w4, #0
B.EQ    check_word_end_pt2
B exit
check_word_end_pt2:
B	    compare_success

do_ls:
// NEED TO GRAB MY DIRECTORY NOW 
BL	    get_path_details
// NOW ACC IMPLEMENT OUR LS
MOV     x16, #5 // SYS_OPEN
ADRP    x0, input_buffer@PAGE
ADD	    x0, x0, input_buffer@PAGEOFF
ADD	    x0, x0, x2
MOV	    x1, #0x100000 // O_RDONLY | O_DIRECTORY
SVC	    #0x80 // SENDS OUT FILEPATH TO GET BACK FILES IN DIR (READ ONLY)

CMP	    x0, #0
B.LT	exit
MOV	    x19, x0

// Works now litty
MOV	    x16, #344  // SYS_GETDIRENTRIES64 //also may be 196 or 344
MOV	    x0, x19
ADRP    x1, dir_buffer@PAGE // Where dir entries r stored
ADD	    x1, x1, dir_buffer@PAGEOFF
MOV	    x2, #4096
// MOV	    x3, #0
ADRP    x3, base_offset@PAGE
ADD	    x3, x3, base_offset@PAGEOFF // Pointer loc
SVC	    #0x80
CMP	    x0, #0
B.LT	exit
MOV x21, x0 // save bytes returned

/*
Bytes 0-7: inode number (8 bytes)
Bytes 8-15: reserved (8 bytes)
Bytes 16-17: record length (2 bytes) = 0x0020 (32 bytes)
Bytes 18-19: file type (2 bytes)
Byte 20: name length (1 byte) = 0x04 (4 chars)
Byte 21+: filename = "."
*/

// x1 has the dir_buffer 
// check for null terminator
// then we need to move 8 in to get record length
// then increment by anothr 3 so moving total 11
// then increment by another one to get the filename
// Output the filename using the file length to know when to terminate
// Then add record length to get to next item, checking for null terminator

// Thru test bit placement I know ls gets to this point

print_run_ls:
MOV	    x8, #0
ADRP    x7, dir_buffer@PAGE // Where dir entries r stored
ADD	    x7, x7, dir_buffer@PAGEOFF
print_loop:
CMP     x8, x21 // check offset and bytes
B.GE    main_loop

ADD	    x9, x7, x8 // Check current entry pointer
// BL test_successful_input

LDRH    w3, [x9, #16] // record length 8 or 16
CBZ	    w3, sys_close // same check as above
// LDRB    w4, [x9, #20] // filename length 11 or 19 || LDRB or LDRH
// Now to SYS WRITE THE NAME OF THE FILE WITH 
MOV	    x23, #21

print_filename_loop: // filename length unreliable as appears to be set len UPDATE - FIXED
MOV	    x16, #4 // SYS_WRITE
LDRB    w24, [x9, x23]
CBZ	    w24, print_newline
MOV	    x0, #1  // STDOUT
ADD	    x1, x9, x23 // 12 or 21
// UXTW    x2, w4 // convert 32 to 64 bit
MOV	    x2, #1
SVC	    #0x80
ADD	    x23, x23, #1
B print_filename_loop
print_newline:
MOV x16, #4
MOV x0, #1
ADRP x1, newline@PAGE
ADD x1, x1, newline@PAGEOFF
MOV x2, #1
SVC #0x80

// AFTER SYS WRITE RUN FOR NEXT MEM
UXTW    x3, w3 // convert 32 to 64 bit
ADD	    x8, x8, x3 // adding our record length so we get to next item
B print_loop
sys_close:
MOV     x16, #6
MOV	    x0, x19
SVC	    0x80
B	    main_loop

get_path_details: // for ls if not dot before / assume from the users folder and for ~/ thats supposed to be just user folder as well
// FIND NUM OF SPACES OR IF NULL TERMINATOR THEN JUST strb a / there and put len 1 so we get current directory
ADRP    x1, input_buffer@PAGE
ADD	    x1, x1, input_buffer@PAGEOFF
path_check_1: // skips spaces
LDRB    w4, [x1, x2]
CMP	    w4, #32
B.NE    path_check_2
ADD     x2, x2, #1
B       path_check_1
path_check_2:
CMP	    w4, #10
B.EQ    store_default_path
CMP     w4, #0            // Null ter 
B.EQ    store_default_path

find_path_end:
LDRB    w4, [x1, x2]
CMP     w4, #10           // Newl
B.EQ    terminate_path
CMP     w4, #0            // Null
B.EQ    path_set
ADD     x2, x2, #1
B       find_path_end

terminate_path:
MOV     w9, #0
STRB    w9, [x1, x2] // path ends null term

path_set:
SUB     x2, x2, #1        // Move back to last char of path
find_path_start:
LDRB    w4, [x1, x2]
CMP     w4, #32           // Space
B.EQ    found_path_start
SUB     x2, x2, #1
B       find_path_start

found_path_start:
ADD     x2, x2, #1        // Move to first char of path
RET

store_default_path:
// MOV	    w9, #' '
// STRB    w9, [x1, x2]
// ADD	    x2, x2, #1
MOV	    w9, #'.'
STRB    w9, [x1, x2]
ADD	    x2, x2, #1
MOV	    w9, #0
STRB    w9, [x1, x2]
SUB	    x2, x2, #1
RET


B exit

test_successful_input:
MOV	    x16, #4 // These are all to set up our func
MOV	    x0, #1
ADRP    x1, input_buffer@PAGE
ADD	    x1, x1, input_buffer@PAGEOFF
// ADRP    x1, dir_buffer@PAGE // Where dir entries r stored
// ADD	    x1, x1, dir_buffer@PAGEOFF
// ADD	    x1, x1, x2
MOV	    x2, #0 // setting x2 to 0 for now
// get byte from x1
LDRB    w3, [x1, x2] // getting 1 byte from out input
test_input_loop:
CBZ	    x3, post_test_input_loop // checking null terminator
ADD	    x2, x2, #1 // add one to get next byte
LDRB    w3, [x1, x2]
B	    test_input_loop // run it again
post_test_input_loop:
SVC	    #0x80 // run our function
RET

// clear_buf:
// // x0 = buffer address
// // mov     x1, #256
// MOV     w2, #0             // value to clear with (null byte)
// clear_loop:
// STRB    w2, [x0, #1]       // write 0 and post-increment pointer
// SUBS    x1, x1, #1         // decrement counter
// B.NE    clear_loop
// RET

.section __TEXT,__cstring,cstring_literals
prompt: 
    .asciz "$ " // DONE
newline:
    .asciz "\n" // DONE
ls:
    .asciz "ls" // TODO
errno:
    .asciz "errno:" // TODO - HANDLING ERRORS
touch:
    .asciz "touch" // TODO
cd:
    .asciz "cd" // TODO
mkdir:
    .asciz "mkdir" // TODO
rm:
    .asciz "rm" // TODO
rmdir:
    .asciz "rmdir" // TODO
open:  
    .asciz "open" // TODO
code:
    .asciz "code" // TODO
pwd:
    .asciz "pwd" // TODO
grep:
    .asciz "grep" // TODO
mv:
    .asciz "mv" // TODO
tar:
    .asciz "tar" // TODO
cp:
    .asciz "cp" // TODO
date:
    .asciz "date" // TODO
dir_get_user:
    .asciz "/etc/passwd" // To get the username from our UID

// REACH: DIFF FLAGS e.g. ls -la (long form and showing hidden files)
// REACH: OUTPUT REAL ERROR MESSAGES BY ERRNO (VERY TEXT HEAVY BUT NOT HARD)
// REACH: CUSTOM COMMANDS e.g. qtc TO OPEN QT CREATOR or tron TO DO SOME ART OR PRINT TRON'S PLOT


.section __DATA,__bss
input_buffer: .space 256
temp_buffer:  .space 256 // for converting our int errnos into strings for handling errors thru outputting "errno: x"
dir_buffer:   .space 4096
base_offset:  .space 8
username:     .space 32
# 30jul15abu
# (c) Software Lab. Alexander Burger

# PilOS Boot Sector
(code '_start)
(here "# vi:")

   .code16

   jmp $0, $.boot                # Reload CS to 0x0000
.boot:
   cli                           # Disable IRQs
   xor %ax, %ax                  # Clear segment registers
   mov %ax, %ss
   mov $_start, %sp              # Stack below boot code
   mov %ax, %ds
   mov %ax, %es
   mov %ax, %fs
   mov %ax, %gs
   cld                           # Clear direction flag
   mov %dl, (Drive)              # Save boot device

   # Load sectors from drive in DL
   mov $LoadMsg, %si             # Print message
   call print
   mov $DAP, %si                 # Disk Address Packet
   mov $0x42, %ah                # Extended Read Sectors
   int $0x13                     # Drive interrupt
   jc readError

   # Check for long mode
   mov $LongMsg, %si             # Print message
   call print
   mov $0x80000000, %eax         # Assuming CPUID is supported
   cpuid
   cmp $0x80000001, %eax         # Extended function available?
   jb noLongMode                 # No
   mov $0x80000001, %eax         # Check long mode
   cpuid
   test $0x20000000, %edx        # Bit 29 set?
   jz noLongMode                 # No
   mov $0x00000001, %eax         # Check local APIC
   cpuid
   test $0x00000200, %edx        # Bit 9 set?
   jnz pageTables                # Yes: Build Page Tables
   mov $NoLocalApic, %si         # No local APIC
   jmp bootError
noLongMode:
   mov $NoLongMode, %si          # No long mode
   jmp bootError

# Print string in SI
print:
   lodsb                         # Next byte
   or %al, %al                   # Any?
   jz 1f                         # No
   mov $0x0E, %ah                # Print char
   int $0x10                     # Video interrupt
   jmp print
1: ret

nibble:
   and $0x0F, %al                # Lowest 4 bits
   add $0x30, %al                # Make numeric digit
   cmp $0x39, %al                # Overflow?
   jna 1f                        # No
   add $7, %al                   # Else make alpha digit
1: ret

# Read error
readError:
   mov $ReadError, %si
   mov %ah, %al                  # Error code low nibble
   call nibble
   movb %al, 12(%si)
   shr $12, %ax                  # High nibble
   call nibble
   movb %al, 11(%si)
bootError:
   call print                    # Print error message
stop:
   hlt
   jmp stop

### Data Area ##########################################################

DAP:                             # Disk Address Packet
   .word 16                      # Size
   .word (K_END-_start-1)/512    # Number of sectors
   .word 0x7E00                  # Offset
   .word 0                       # Segment
   .quad 1                       # Start sector

Drive:
   .byte 0                       # Boot device

LoadMsg:     .asciz "Loading PilOS\r\n"
ReadError:   .asciz "READ ERROR 00"
LongMsg:     .asciz "Checking long mode\r\n"
NoLocalApic: .asciz "ERROR: CPU has no local APIC\r\n"
NoLongMode:  .asciz "ERROR: CPU does not support long mode\r\n"

   # Boot info
   .space _start+446-.

   ### Partition table ###
   # Two 1 GiB dummy partitions
   .byte 0x80                    # Bootable
   .byte 0x01                    # Start head
   .byte 0x01                    # Start sector
   .byte 0x00                    # Start cylinder
   .byte 0x83                    # System ID Linux
   .byte 0xF6                    # End head
   .byte 0x3E                    # End sector
   .byte 0x82                    # End cylinder
   .long 0x0000003E              # Relative sector
   .long 0x001E9C38              # Total Sectors in partition

   .byte 0x00                    # Not bootable
   .byte 0x00                    # Start head
   .byte 0x01                    # Start sector
   .byte 0x83                    # Start cylinder
   .byte 0x82                    # System ID Linux swap
   .byte 0xF6                    # End head
   .byte 0x7E                    # End sector
   .byte 0x05                    # End cylinder
   .long 0x001E9C76              # Relative sector
   .long 0x001E9C76              # Total Sectors in partition

   # Two empty partitions
   .long 0, 0, 0, 0
   .long 0, 0, 0, 0

   .byte 0x55                    # Mark boot sector
   .byte 0xAA

### Second Sector ######################################################

.equ CODE64, 0x0008             # GDT Offsets
.equ DATA64, 0x0010
.equ CODE16, 0x0018
.equ DATA16, 0x0020

GDT:
   .quad 0x0000000000000000      # Null descriptor
   .quad 0x0020980000000000      # 64-bit code descriptor
   .quad 0x0000900000000000      # 64-bit data descriptor
   .quad 0x000F9A000000FFFF      # 16-bit code descriptor
   .quad 0x000F92000000FFFF      # 16-bit data descriptor

   .long 0                       # Padding to 64 bit
   .word 0
GDTR:
   .word .-GDT-7                 # 16-bit Size of GDT - 1
   .quad GDT                     # 64-bit Base Address of GDT

IDT:
   .word irqDE, CODE64, 0x8F00, 0, 0, 0, 0, 0   # DE Div/0
   .word irqDB, CODE64, 0x8F00, 0, 0, 0, 0, 0   # DB Debug
   .word irq02, CODE64, 0x8F00, 0, 0, 0, 0, 0   # NMI
   .word irqBP, CODE64, 0x8F00, 0, 0, 0, 0, 0   # BP Breakpoint (INT3 instruction)
   .word irqOF, CODE64, 0x8F00, 0, 0, 0, 0, 0   # OF Overflow
   .word irq05, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq06, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq07, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irqDF, CODE64, 0x8F00, 0, 0, 0, 0, 0   # DF Double fault
   .word irq09, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq0A, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq0B, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq0C, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irqGP, CODE64, 0x8F00, 0, 0, 0, 0, 0   # GP General protection
   .word irqPF, CODE64, 0x8F00, 0, 0, 0, 0, 0   # PF Page fault
   .word irq0F, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq10, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq11, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq12, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq13, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq14, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq15, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq16, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq17, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq18, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq19, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq1A, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq1B, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq1C, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq1D, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq1E, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irq1F, CODE64, 0x8F00, 0, 0, 0, 0, 0
   .word irqTick, CODE64, 0x8E00, 0, 0, 0, 0, 0 # IRQ 0
   .word irqKey, CODE64, 0x8E00, 0, 0, 0, 0, 0  # IRQ 1
   .rept 255-(.-IDT)/16
   .word irqXX, CODE64, 0x8E00, 0, 0, 0, 0, 0
   .endr
   .word irqSI, CODE64, 0x8E00, 0, 0, 0, 0, 0   # Spurious interrupt

   .long 0                       # Padding to 64 bit
   .word 0
IDTR:
   .word .-IDT-7                 # 16-bit Size of IDT - 1
   .quad IDT                     # 64-bit Base Address of IDT

Tick:
   .quad 0                       # Tick count (PIT 1000.15 Hz)

RIDTR:
   .word 0x3FF                   # Real mode IDT
   .long 0

Loaded:
   .byte                         # Sector loaded flag
Errno:
   .byte 0                       # BIOS error code

memError:
   mov $MemError, %si
   jmp bootError
a20Error:
   mov $A20Error, %si
   jmp bootError

InitMsg:  .asciz "Initializing memory\r\n"
MemError: .asciz "ERROR: Can't get memory map\r\n"
A20Error: .asciz "A20 ERROR"

### 16-bit Code ########################################################

.equ PTAB_BEG, 0x60000           # 128 K at end of 0x07C00 .. 0x7FFFF (353 K free)
.equ PTAB_SIZ, 0x20000           # PML4, PDP and 30 PDs (30 GiB virtual memory)
.equ PTAB_END, 0x80000

pageTables:
   mov $InitMsg, %si             # Print message
   call print
   mov $PTAB_BEG, %edi           # Page-aligned space for PML4, PDP and PDs
   push %edi
   xor %eax, %eax                # Fill with zero
   mov $PTAB_SIZ/4, %ecx         # Bytes / 4
   addr32 rep stosl
   pop %edi

   lea 0x1003(%edi), %eax        # P | R/W
   mov %eax, (%edi)              # Store single PML4 entry
   push %edi                     # Save PML4 address

   add $0x1000, %edi             # Build the Page Directory Pointer (PDP) Table
doPDP:
   add $0x1000, %eax             # Increment PD pointer
   cmp $PTAB_END, %eax           # Done?
   jg pdpDone                    # Yes
   mov %eax, (%edi)              # Store PDPTE
   add $8, %edi                  # Increment PDP pointer
   jmp doPDP
pdpDone:
   mov $PTAB_BEG+0x2000, %esi    # Point ESI to the Page Directory (PD) Table
   movl $0x83, (%esi)            # 2 MiB + P | R/W lowest 2 MiB identity map
   add $8*8, %esi                # Heap starts at 0x1000000

   # Get memory map and build Page Directory Table
   mov $0x500, %di               # Temporary buffer in DI
   xor %ebx, %ebx                # Clear EBX
   mov $0x0534D4150, %edx        # "SMAP"
   mov $24, %ecx                 # 24 bytes
   movl $1, 20(%di)              # Force ACPI 3.0 entry
   mov $0xE820, %eax             # BIOS E820
   int $0x15                     # OK?
   jc memError                   # No
   mov $0x0534D4150, %edx        # Set to "SMAP" again
   cmp %eax, %edx                # Returned "SMAP"?
   jne memError                  # No
   or %ebx, %ebx                 # Entries?
   jz memError                   # No
memLoop:
   cmpl $1, 16(%di)              # Type = 1?
   jne skipMem                   # No
   cmp $20, %cl                  # Got 24 byte ACPI 3.X response?
   jbe doMem                     # No
   testb $1, 20(%di)             # Else ignore?
   jz skipMem                    # Yes
doMem:
   mov (%di), %eax               # Pointer low
   and $0x1FFFFF, %eax           # Non-2MiB-aligned offset?
   jz aligned                    # Yes
   xor $0x1FFFFF, %eax           # 21-bit 2's complement
   inc %eax
   sub %eax, 8(%di)              # Subtract from region length
   sbbl $0, 12(%di)              # Less than zero?
   jb skipMem                    # Yes
   add %eax, (%di)               # Add to pointer
   adcl $0, 4(%di)
aligned:
   mov 12(%di), %ecx             # Region length high word
   or %ecx, %ecx                 # Any?
   jne storePD                   # Yes
   cmpl $0x200000, 8(%di)        # Region length low < 2 MiB?
   jb skipMem                    # Yes
storePD:
   mov (%di), %eax               # Pointer low
   or $0x83, %eax                # 2 MiB + P | R/W
   mov %eax, (%esi)              # Store in Page Directory
   mov 4(%di), %eax              # Pointer high
   mov %eax, 4(%esi)             # Store in Page Directory
   add $8, %esi
   cmp $PTAB_END, %esi           # Reached maximum?
   je enterLongMode              # Yes
   addl $0x200000, (%di)         # Increment pointer by 2 MiB
   adcl $0, 4(%di)
   subl $0x200000, 8(%di)        # Decrement region length by 2 MiB
   sbbl $0, 12(%di)
   jmp doMem
skipMem:
   or %ebx, %ebx                 # Done?
   jz enterLongMode              # Yes
   mov $24, %ecx                 # 24 bytes
   movl $1, 20(%di)              # Force ACPI 3.0 entry
   mov $0xE820, %eax             # BIOS E820
   int $0x15                     # OK?
   jc memError
   mov $0x0534D4150, %edx        # Set to "SMAP" again
   jmp memLoop                   # Continue

# Switch to 16-bit real mode
seg16:
   mov $DATA16, %eax             # Store DS in segment registers
   mov %ax, %ss
   mov %ax, %ds
   mov %ax, %es
   mov %ax, %fs
   mov %ax, %gs
   mov %cr0, %eax                # Deactivate long mode
   and $0x7FFFFFFE, %eax         # by disabling paging and protection simultaneously
   mov %eax, %cr0
   jmp $0, $.real
.real:
   mov $_start, %sp              # Stack below boot code
   xor %ax, %ax
   mov %ax, %ss
   mov %ax, %ds
   mov %ax, %es
   mov %ax, %fs
   mov %ax, %gs
   lidt (RIDTR)                  # Load real mode IDT
   sti                           # Enable IRQs
   jmp *%esi                     # Return

# Switch back to long mode
longMode:
   pop %si                       # Get return address
   cli                           # Disable IRQs
   mov %cr0, %eax                # Activate long mode
   or $0x80000001, %eax          # by enabling paging and protection simultaneously
   mov %eax, %cr0
   jmp $CODE64, $LongMode2       # Load CS with 64 bit segment

# Enter initial long mode
enterLongMode:
   sub $PTAB_BEG+0x2000, %esi    # Page table length in ESI
   movw $0x500, (DAP+4)          # I/O buffer at 0500
   call vgaText                  # Set text mode
   mov $0x2401, %ax              # Enable A20
   int $0x15
   jc a20Error
   mov $0xA9, %al                # PIT Timer 1193182 Hz / 1193 = 1000.15 Hz
   out %al, $0x40
   mov $0x04, %al
   out %al, $0x40

   # Enter long mode
   pop %eax                      # Restore PML4 address
   mov %eax, %cr3                # Store in CR3
   mov $0b10100000, %eax         # Set the PAE and PGE bit
   mov %eax, %cr4
   mov $0xC0000080, %ecx         # Read from the EFER MSR
   rdmsr
   or $0x00000100, %eax          # Set LME bit
   wrmsr
   mov %cr0, %eax                # Activate long mode
   or $0x80000001, %eax          # by enabling paging and protection simultaneously
   mov %eax, %cr0
   lgdt (GDTR)                   # Load GDT register
   jmp $CODE64, $LongMode        # Load CS with 64 bit segment

### VGA Graphics #######################################################
vgaText:
   mov $0x0103, %ax              # Text and cursor mode
   mov $0x2020, %cx              # Cursor off
   int $0x10
   ret

# 320*240 * 256 VGA Mode X (Michael Abrash, DDJ Jul91)
.equ SC_INDEX     0x03C4         # Sequence controller index
.equ GC_INDEX     0x03CE         # Graphics controller index
.equ CRTC_INDEX   0x03D4         # CRT controller index
.equ INP_STAT_1   0x03DA         # Input Status 1 register
.equ MISC_OUTPUT  0x03C2         # Miscellaneous output register
.equ SCREEN_SEG   0x0A000        # Segment of display memory
.equ MAP_MASK     2              # Index in SC of Map Mask register
.equ BIT_MASK     8              # Index in GC of Bit Mask register
.equ S_WIDTH      80             # Screen width in bytes
.equ T_WIDTH      40             # 40 characters per line

vgaModeX:
   mov $0x13, %ax                # BIOS stardard 256-color mode (320*200)
   int $0x10
   mov $SC_INDEX, %dx

   ret

### 64-bit Code ########################################################

   .code64

# IRQ handlers
irqDE:
   push %rax
   mov $0x4445, %ax
   jmp irq
irqDB:
   push %rax
   mov $0x4442, %ax
   jmp irq
irq02:
   push %rax
   mov $0x3032, %ax
   jmp irq
irqBP:
   push %rax
   mov $0x4250, %ax
   jmp irq
irqOF:
   push %rax
   mov $0x4F46, %ax
   jmp irq
irq05:
   push %rax
   mov $0x3035, %ax
   jmp irq
irq06:
   push %rax
   mov $0x3036, %ax
   jmp irq
irq07:
   push %rax
   mov $0x3037, %ax
   jmp irq
irqDF:
   push %rax
   mov $0x4446, %ax
   jmp irq
irq09:
   push %rax
   mov $0x3039, %ax
   jmp irq
irq0A:
   push %rax
   mov $0x3041, %ax
   jmp irq
irq0B:
   push %rax
   mov $0x3042, %ax
   jmp irq
irq0C:
   push %rax
   mov $0x3043, %ax
   jmp irq
irqGP:
   push %rax
   mov $0x4750, %ax
   jmp irq
irqPF:
   push %rax
   mov $0x5046, %ax
   jmp irq
irq0F:
   push %rax
   mov $0x3046, %ax
   jmp irq

irq10:
   push %rax
   mov $0x3130, %ax
   jmp irq
irq11:
   push %rax
   mov $0x3131, %ax
   jmp irq
irq12:
   push %rax
   mov $0x3132, %ax
   jmp irq
irq13:
   push %rax
   mov $0x3133, %ax
   jmp irq
irq14:
   push %rax
   mov $0x3134, %ax
   jmp irq
irq15:
   push %rax
   mov $0x3135, %ax
   jmp irq
irq16:
   push %rax
   mov $0x3136, %ax
   jmp irq
irq17:
   push %rax
   mov $0x3137, %ax
   jmp irq
irq18:
   push %rax
   mov $0x3138, %ax
   jmp irq
irq19:
   push %rax
   mov $0x3139, %ax
   jmp irq
irq1A:
   push %rax
   mov $0x3141, %ax
   jmp irq
irq1B:
   push %rax
   mov $0x3142, %ax
   jmp irq
irq1C:
   push %rax
   mov $0x3143, %ax
   jmp irq
irq1D:
   push %rax
   mov $0x3144, %ax
   jmp irq
irq1E:
   push %rax
   mov $0x3145, %ax
   jmp irq
irq1F:
   push %rax
   mov $0x3146, %ax
   jmp irq

irqTick:
   push %rax
   mov (Tick), %rax              # Get timeout
   or %rax, %rax                 # Any?
   jz 1f                         # No
   dec %rax                      # Else derement
   mov %rax, (Tick)
1: addq $1000, (USec)            # Increment microseconds (1000.15 Hz)
   mov $0x20, %al                # EOI
   out %al, $0x20
   pop %rax
   iretq

irqKey:
   push %rax
   in $0x60, %al                 # Read keyboard
   push %r11                     # Save registers
   push %r10
   push %rdi
   push %rsi
   push %rcx
   call keyIrqB                  # Call handler
   pop %rcx                      # Restore registers
   pop %rsi
   pop %rdi
   pop %r10
   pop %r11
   mov $0x20, %al                # EOI
   out %al, $0x20
   pop %rax
   iretq

irqXX:
   push %rax
   mov $0x3F3F, %ax              # "??"
irq:
   ror $8, %ax
   call ttyOutB
   shr $8, %ax
   call ttyOutB
   mov $'!', %al
   call ttyOutB
   jmp stop                      # Halt

irqSI:                           # Spurious interrupt
   movw $0x4F53, (0xB8000)       # Show red "S"
   iretq

# Initialize interrupts
initIR:
   mov $0x11, %al                # Initialize PICs
   out %al, $0x20                # Master Command
   out %al, $0xA0                # Slave Command
   mov $0x20, %al                # ICW2 Offsets
   out %al, $0x21
   mov $0x28, %al
   out %al, $0xA1
   mov $0x04, %al                # ICW3 Master/Slave
   out %al, $0x21
   mov $0x02, %al
   out %al, $0xA1
   mov $0x01, %al
   out %al, $0x21
   out %al, $0xA1
   mov $0xFC, %al                # Only timer and keyboard
   out %al, $0x21
   mov $0xFF, %al
   out %al, $0xA1
   lidt (IDTR)                   # Load IDT
   sti                           # Enable IRQs
   ret

# Screen I/O
clearScreen:
   mov $0xB8000, %edi            # VGA text buffer
   mov $500, %rcx                # Count/4
   mov $0x1F201F201F201F20, %rax # Blue background, white foreground, blank spaces
   rep stosq                     # Write to screen buffer
   xor %edi, %edi                # Init TTY position
   mov %edi, (TtyRow)
   mov %edi, (TtyCol)
   ret

screen_D:
   push %rax
   push %rdx
   mov (TtyRow), %eax            # Get TTY row
   mov $160, %edi                # 2 bytes per character
   mull %edi
   lea 0xB8000(%eax), %edi
   add (TtyCol), %edi
   pop %rdx
   pop %rax
   ret

ttyBeep:
   push %rdx
   mov $0xB6, %al                # Prepare speaker
   out %al, $0x43
   mov $0x4B, %al                # Frequency 1355 = 0x054B (880 Hz)
   out %al, $0x42                # Output low byte
   mov $0x05,%al
   out %al, $0x42                # Output high byte
   in $0x61, %al                 # Turn on
   or $3, %al                    # Set bits 0 and 1
   out %al, $0x61
   mov $88, %rdx                 # Wait 88 ms
   xor %rax, %rax                # No events
   call wait
   in $0x61, %al                 # Turn off
   and $0xFC, %al                # Clear bits 0 and 1
   out %al, $0x61
   pop %rdx
   ret

ttyOutB:
   cmp $7, %al                   # Bell?
   je ttyBeep                    # Yes
   call screen_D                 # Get screen pointer
   movb $0x1F, 1(%edi)           # Remove cursor
   cmp $8, %al                   # Backspace?
   je ttyBS                      # Yes
   cmp $10, %al                  # Newline?
   je ttyNL                      # Yes
   mov %al, (%edi)               # Store byte
   addl $2, (TtyCol)             # Increment column
   cmpl $160, (TtyCol)           # Reached end?
   jne ttyCursor                 # No
   jmp ttyNL
ttyBS:
   mov (TtyCol), %edi            # Get column
   or %edi, %edi                 # At beginning?
   jz 1f                         # Yes
   sub $2, %edi                  # Else decrement column
   mov %edi, (TtyCol)
   jmp ttyCursor
1: cmpl $0, (TtyRow)             # At top left?
   jz ttyCursor                  # Yes
   movl $158, (TtyCol)           # Go to end of upper line
   decl (TtyRow)
   jmp ttyCursor
ttyNL:
   mov (TtyRow), %edi            # Get row
   cmp $24, %edi                 # At bottom?
   jb 1f                         # No
   cld                           # Else scroll up
   mov $0xB8000, %edi
   lea 160(%edi), %esi           # one line
   mov $(24*160)/4, %ecx         # Bytes / 4
   rep movsl
   push %rax
   mov $0x1F201F20, %eax         # Clear last line
   mov $0xB8000+(24*160), %edi
   mov $160/4, %ecx              # Bytes / 4
   rep stosl
   pop %rax
   jmp 2f
1: inc %edi                      # Increment row
   mov %edi, (TtyRow)
2: xor %edi, %edi                # Zero column
   mov %edi, (TtyCol)
ttyCursor:
   call screen_D                 # Get screen pointer
   movb $0x3F, 1(%edi)           # Set cursor cyan
   ret

wait:
   mov %rdx, (Tick)              # Set timeout
1: testb $1, %al                 # Want key events?
   jz 2f                         # No
   testb $0xFF, (Keybuf)         # Key event?
   jz 2f                         # No
   mov $1, %al                   # Return key event
   ret                           # (no carry)
2: or %rdx, %rdx                 # Timeout?
   jnz 3f                        # No
   xor %rax, %rax                # Return timeout
   ret                           # (no carry)
3: cmp %r12, (Signal)            # Signal?
   jz 4f                         # No
   stc                           # Return carry
   ret
4: hlt
   mov (Tick), %rdx              # Get timer
   jmp 1b

# Switch to real mode
realMode:
   pop %r10                      # Get return address
   push %rbp                     # Save registers
   push %rdi
   push %rsi
   push %rdx
   push %rcx
   push %rbx
   mov %r10, %rsi                # Return address in ESI
   mov %rsp, %r10                # Save RSP
   cli                           # Disable IRQs
   in $0x70, %al                 # Disable NMI
   or $0x80, %al
   out %al, $0x70
   pushq $CODE16                 # 16-bit code segment
   xor %rax, %rax
   mov $seg16, %eax
   push %rax
   retfq                         # Jump to code segment

# Back to long mode
LongMode2:
   mov $DATA64, %eax             # Store DS in segment registers
   mov %eax, %ds
   mov %eax, %es
   mov %eax, %fs
   mov %eax, %gs
   mov %r10, %rsp                # Restore RSP
   mov %rsi, %r10                # return address
   pop %rbx                      # and registers
   pop %rcx
   pop %rdx
   pop %rsi
   pop %rdi
   pop %rbp
   in $0x70, %al                 # Enable NMI
   and $0x7F, %al
   out %al, $0x70
   call initIR                   # Initialize interrupts (each time?)
   jmp *%r10                     # Return

reboot:
   mov $0xFE, %al                # Reset command
   out %al, $0x64
   jmp stop                      # Halt if still running

pread:
   push %rdx
   push %rcx                     # RCX: size
   push %rsi                     # RSI: Position
   add $511, %rcx                # Round up size
   shr $9, %rcx                  # Sector size 512
   mov %cx, (DAP+2)              # Number of sectors in DAP
   shr $9, %rsi                  # Sector size 512
   add $1024, %rsi               # Add sector offset
   mov %rsi, (DAP+8)             # Start sector in DAP
   call realMode
   .code16
   mov (Drive), %dl              # Get boot device
   mov $DAP, %si                 # Disk Address Packet
   mov $0x42, %ah                # Extended Read Sectors
   int $0x13                     # Drive interrupt
   mov %ah, (Errno)              # Save error code
   call longMode
   .code64
   cld                           # RDI: Data destination
   pop %rsi                      # Get position
   mov (%rsp), %rcx              # Get size
   cmp $64, %rcx                 # Full block?
   jb 1f                         # No
   shr $3, %rcx                  # Long words
   mov $0x500, %rsi              # Use buffer at 0500
   rep movsq                     # Copy data from buffer
   jmp 2f
1: and $63, %rsi                 # Offset in sector
   add $0x500, %rsi              # Use buffer at 0500
   rep movsb
2: pop %rax                      # Return size
   testb $0xFF, (Errno)          # or error
   jz 3f
   mov $-1, %rax
3: pop %rdx
   ret

pwrite:
   push %rdx
   push %rcx                     # RCX: size
   push %rdi                     # RDI: Position
   cld                           # RSI: Data source
   movb $1, (Loaded)             # Assume loaded
   cmp $64, %rcx                 # Full block?
   jb 1f                         # No
   shr $3, %rcx                  # Long words
   mov $0x500, %rdi              # Use buffer at 0500
   rep movsq                     # Copy data to buffer
   pop %rdi                      # Get Position
   mov (%rsp), %rcx              # Get size
   shr $9, %rcx                  # Sector size 512
   mov %cx, (DAP+2)              # Number of sectors in DAP
   shr $9, %rdi                  # Sector size 512
   add $1024, %rdi               # Add sector offset
   mov %rdi, (DAP+8)             # Start sector in DAP
   jmp 3f
1: movw $1, (DAP+2)              # Load single sector
   shr $9, %rdi                  # Sector size 512
   add $1024, %rdi               # Add sector offset
   cmp %rdi, (DAP+8)             # Current sector loaded?
   jne 2f                        # No
   pop %rdi                      # Get Position
   and $63, %rdi                 # Offset in sector
   add $0x500, %rdi              # Use buffer at 0500
   rep movsb
   jmp 3f
2: movb $0, (Loaded)             # Set not loaded
   mov %rdi, (DAP+8)
   mov %rcx, %rax                # Save count
   mov $0x6000, %rdi             # Use temporary buffer at 06000
   rep movsb
   pop %rdi                      # Get Position
   and $63, %rdi                 # Offset in sector
   mov %rax, %rcx                # Count in RCX, position in RDI
3: call realMode
   .code16
   testb $0xFF, (Loaded)         # Already loaded?
   jnz 4f                        # Yes: Skip
   mov (Drive), %dl              # Get boot device
   mov $DAP, %si                 # Disk Address Packet
   mov $0x42, %ah                # Extended Read Sectors
   int $0x13                     # Drive interrupt
   jc 5f                         # Skip on error
   mov $0x6000, %si              # Get temporary buffer
   add $0x500, %di               # Use buffer at 0500
   rep movsb                     # Copy new bytes
4: mov (Drive), %dl              # Get boot device again
   mov $DAP, %si                 # Disk Address Packet
   mov $0x4300, %ax              # Extended Write Sectors
   int $0x13                     # Drive interrupt
5: mov %ah, (Errno)              # Save error code
   call longMode
   .code64
   pop %rax                      # Return size
   testb $0xFF, (Errno)          # or error
   jz 6f
   mov $-1, %rax
6: pop %rdx
   ret

# Graphics
vga:
   call realMode
   .code16
   call vgaModeX                 # Set graphic mode
   call longMode
   .code64
   ret

# Get current date and time
dateTime:
   xor %r11, %r11                # Clear tmp in R11
   mov $0x0B, %al                # Register B
   out %al, $0x70
   in $0x71, %al
   mov %al, %cl                  # Register B in CL
1:
   mov $0x0A, %al                # Register A
   out %al, $0x70
   in $0x71, %al
   and $0x80, %al                # Update in process?
   jnz 1b                        # Yes
   xor %rax, %rax                # Clear result
   mov $0x09, %al                # Year
   call rtc
   add $(2000<<8), %rax          # Hardcode 2000
   mov $0x08, %al                # Month
   call rtc
   mov $0x07, %al                # Day
   call rtc
   mov $0x04, %al                # Hour (assume 24 h mode)
   call rtc
   mov $0x02, %al                # Minute
   call rtc
   xor %al, %al                  # Second
   out %al, $0x70
   in $0x71, %al
   call bcd                      # Convert BCD
   cmp %r11, %rax                # Value changed?
   je 1f                         # No
   mov %rax, %r11                # Keep value
   jmp 1b
rtc:
   out %al, $0x70                # Set CMOS register
   in $0x71, %al                 # Read value
   call bcd                      # Convert BCD
   shl $8, %rax                  # Shift
1: ret
bcd:
   test $4, %cl                  # BCD flag?
   jnz 1f                        # No
   mov %al, %dl                  # Save value
   and $0x0F, %dl                # Low nibble
   and $0x70, %al                # High nibble
   shr $1, %al                   # Times 10
   mov %al, %dh
   shr $2, %al
   add %dh, %al
   add %dl, %al                  # Add low nibble
1: ret

### Start PilOS ########################################################
LongMode:
   mov $DATA64, %eax             # Store DS in segment registers
   mov %eax, %ds
   mov %eax, %es
   mov %eax, %fs
   mov %eax, %gs
   shl $(21-3), %rsi             # Scale page table index to 2 MiB per 8-byte entry
   mov %rsi, %rsp                # Initial stack pointer
   mov $PTAB_BEG+0x2000, %edi    # EDI on Page Directory (PD) Table
   mov $0x0000001B, %ecx         # APIC Base MSR
   rdmsr
   or $0x0800, %eax              # Enable APIC (Bit 11)
   wrmsr
   and $0xFFFFF000, %eax         # Get base address
   or $0x93, %eax                # 2 MiB + P | R/W | PCD
   mov %eax, 8(%edi)             # Map APICs to 0x200000
   movl $0xFEC00093, 16(%edi)    # Map IO-APIC 0x400000
   movw $0x1FF, (0x2000F0)       # Spurious IR vector + APIC enable
   call initIR                   # Initialize interrupts
   xor %r12, %r12                # Init NULL register
   mov $0x1000000, %rax          # Heap starts at 0x1000000 (16 MiB)

### PilOS main ###
# vi:et:ts=3:sw=3

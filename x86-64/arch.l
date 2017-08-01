# 02jul15abu
# (c) Software Lab. Alexander Burger

# PilOS specific instructions
(let M (loc "*Mode" *Instructions)
   (balance '*Instructions
      (list
         (list 'di)
         (list 'ei)
         (list 'read '(source) M '(destination) M '(source) M '(source) M)
         (list 'wait)
         (list 'write '(source) M '(destination) M '(source) M '(source) M)
         (list 'reboot) )
      T ) )

# Disable interrupts
(asm di ()
   (prinst "cli") )

# Enable interrupts
(asm ei ()
   (prinst "sti") )

# Read src dst cnt pos
(asm read (Src S Dst D Cnt C Pos P)
   (prinst "mov" (src Cnt C) "%rcx")  # Get size
   (prinst "mov" (src Pos P) "%rsi")  # position
   (lea Dst D "%rdi")                 # and destination
   (prinst "call" "pread") )          # Read data

# Write src dst cnt pos
(asm write (Src S Dst D Cnt C Pos P)
   (prinst "mov" (src Cnt C) "%rcx")  # Get size
   (prinst "mov" (src Pos P) "%rdi")  # position
   (lea Dst D "%rsi")                 # and source
   (prinst "call" "pwrite") )         # Write data

# Wait for interrupts in 'A' for 'C' ms [z..]
(asm wait ()
   (prinst "call" "wait") )

(asm reboot ()
   (prinst "jmp" "reboot") )

(asm T stop ()
   (prinst "jmp" "stop") )

# vi:et:ts=3:sw=3

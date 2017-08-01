# 04oct15abu
# (c) Software Lab. Alexander Burger

### Keyboard ###
(equ KEYBUF 32)                  # Keyboard buffer size
(equ KEY_KP1 79)                 # Key codes
(equ KEY_LEFTSHIFT 42)
(equ KEY_RIGHTSHIFT 54)
(equ KEY_CAPSLOCK 58)
(equ KEY_LEFTCTRL 29)
(equ KEY_RIGHTCTRL 97)

(data 'Keybuf 0)
   bytes `(need KEYBUF 0)        # Keyboard buffer
: ModKeys word 0                 # Modifier Keys
: Keys                           # Layout
   ascii "?\27\1234567890-=\8\"
   ascii "\9\qwertyuiop[]\\n\?"
   ascii "asdfghjkl;'??\\\\"
   ascii "zxcvbnm,./??? "
   asm ".space 128 - (. - Keys)"
: Shift
   ascii "?\27\!@#$%\^&*()_+\8\"
   ascii "\9\QWERTYUIOP{}\\n\?"
   ascii "ASDFGHJKL:\\\"??|"
   ascii "ZXCVBNM<>???? "
   asm ".space 128 - (. - Shift)"
: Ctrl
   bytes (0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
   bytes (9 17 23 5 18 20 25 21 9 15 16 27 29 10 0)
   bytes (1 19 4 6 7 8 10 11 12 63 28 0 0 0)
   bytes (26 24 3 22 2 14 10 0 0 127)
   asm ".space 128 - (. - Ctrl)"

: Repeat byte 0

# TTY Input
(code 'ttyIn_B)
   push X
   di  # Disable interrupts
   ld B (Keybuf)  # Next key
   ld X Keybuf
   do
      set (X) (X 1)  # Shift bytes
      inc X  # Next
      nul (X)  # More?
   until z  # No
   ei  # Enable interrupts
   pop X
   ret

# Interrupt handler
(code 'keyIrqB 0)
   cmp B KEY_KP1  # END key?
   jeq reboot  # Yes
   call pentiB  # Penti?
   jeq ret  # Yes
   test B (hex "80")  # Up?
   if nz  # Yes
      cmp B (| (hex "80") KEY_LEFTSHIFT)  # Left shift?
      if eq  # Yes
         off (ModKeys) 1
         ret
      end
      cmp B (| (hex "80") KEY_RIGHTSHIFT)  # Right shift?
      if eq  # Yes
         off (ModKeys) 2
         ret
      end
      cmp B (| (hex "80") KEY_CAPSLOCK)  # Control?
      if eq  # Yes
         off (ModKeys) 4
         ret
      end
      cmp B (| (hex "80") KEY_LEFTCTRL)  # Left control?
      if eq  # Yes
         off (ModKeys) 8
         ret
      end
      cmp B (| (hex "80") KEY_RIGHTCTRL)  # Right control?
      if eq  # Yes
         off (ModKeys) 16
      end
      ret
   end
   # Down
   cmp B KEY_LEFTSHIFT  # Left shift?
   if eq  # Yes
      or (ModKeys) 1
      ret
   end
   cmp B KEY_RIGHTSHIFT  # Right shift?
   if eq  # Yes
      or (ModKeys) 2
      ret
   end
   cmp B KEY_CAPSLOCK  # Control?
   if eq  # Yes
      or (ModKeys) 4
      ret
   end
   cmp B KEY_LEFTCTRL  # Left control?
   if eq  # Yes
      or (ModKeys) 8
      ret
   end
   cmp B KEY_RIGHTCTRL  # Right control?
   if eq  # Yes
      or (ModKeys) 16
      ret
   end
   zxt  # Extend B
   test (ModKeys) (hex "1C")  # Control?
   if nz  # Yes
      ld B (A Ctrl)  # Get Ctrl-ASCII
   else
      test (ModKeys) 3  # Shift?
      if nz  # Yes
         ld B (A Shift)  # Get shifted ASCII
      else
         ld B (A Keys)  # Get normal ASCII
      end
   end
# Store key in buffer
: bufKeyB
   nul B  # Any?
   if nz  # Yes
      cmp B 3  # Ctrl-C?
      if eq  # Yes
         inc (Signal)  # Register signal
         inc (SigInt)  # Ctrl-C interrupt
         ret
      end
      ld (Repeat) B  # Save key
      push C
      slen C Keybuf  # Find free slot
      cmp C KEYBUF  # Any?
      if lt  # Yes
         ld (C Keybuf) B
      end
      pop C
   end
   ret

### Penti Chorded Keyboard (Regenaxer Special) ###
(equ KEY_KP0 82)
(equ KEY_KP7 71)
(equ KEY_KP8 72)
(equ KEY_KP9 73)
(equ KEY_KPPLUS 78)
(equ KEY_KP5 76)

(equ PENTI_S  1)
(equ PENTI_P  2)
(equ PENTI_D  4)
(equ PENTI_C  8)

(data 'Penti)
   bytes (0 `(char "n") `(char "i") `(char "g") `(char "e") 0 `(char "o") `(char "m"))
   bytes (`(char "s") `(char "j") `(char "c") `(char "v") `(char "l") 0 `(char "u") `(char "k"))
   bytes (32 `(char "d") `(char "a") `(char "y") `(char "r") 0 `(char "b") `(char "t"))
   bytes (`(char "f") `(char "h") `(char "q") `(char "x") `(char "z") 0 `(char "p") `(char "w"))
: PentiPunct
   bytes (0 `(char ")") `(char "!") `(char "=") `(char "[") 0 `(char "|") `(char ">"))
   bytes (`(char "*") `(char ";") `(char "]") `(char "(") `(char "_") 0 `(char "&") `(char "@"))
   bytes (32 `(char "/") `(char "`") `(char "\^") `(char "$") 0 `(char "{") `(char "%"))
   bytes (`(char "?") `(char "#") `(char "'") `(char "\\") `(char "\"") 0 `(char "}") `(char "<"))
: PentiDigit
   bytes (0 0 `(char "3") `(char "9") `(char "2") 0 `(char "8") `(char "-"))
   bytes (`(char "1") `(char ":") `(char ",") 0 `(char "7") 0 `(char "0") `(char "^?"))
   bytes (32 `(char ".") `(char "6") 0 `(char "5") 0 0 `(char "~"))
   bytes (`(char "4") 0 0 0 0 0 `(char "+") 0)

: PentiChord   word 0            # Chord
: PentiStat    word 0            # Status
: PentiBeg     word 0            # Begin
: PentiEnd     word 0            # End
: PentiMod     word 0            # Modifiers
: PentiLock    word 0            # Locked

: PentiRev     byte 0            # Reverse flag

(code 'pentiB 0)
   test B (hex "80")  # Down?
   if z  # Yes
      null (PentiStat)  # Already started?
      if nz  # Yes
         ld (PentiEnd) (USec)  # Set end
      else
         ld (PentiBeg) (USec)  # Set begin
      end
      cmp B KEY_KP0
      if eq
         test (PentiChord) (hex "0F")
         if nz
            set (PentiRev) 1
         end
         or (PentiChord) (hex "10")
         or (PentiStat) (hex "10")
      else
         cmp B KEY_KP7
         if eq
            test (PentiChord) (hex "07")
            if nz
               set (PentiRev) 1
            end
            or (PentiChord) (hex "08")
            or (PentiStat) (hex "08")
         else
            cmp B KEY_KP8
            if eq
               test (PentiChord) (hex "03")
               if nz
                  set (PentiRev) 1
               end
               or (PentiChord) (hex "04")
               or (PentiStat) (hex "04")
            else
               cmp B KEY_KP9
               if eq
                  test (PentiChord) (hex "01")
                  if nz
                     set (PentiRev) 1
                  end
                  or (PentiChord) (hex "02")
                  or (PentiStat) (hex "02")
               else
                  cmp B KEY_KPPLUS
                  if eq
                     or (PentiChord) (hex "01")
                     or (PentiStat) (hex "01")
                  else
                     cmp B KEY_KP5
                     jne Ret  # Non-zero
                     ld B (Repeat)  # Key repeat
                     call bufKeyB  # Store
                  end
               end
            end
         end
      end
   else # Up
      cmp B (| (hex "80") KEY_KP0)
      if eq
         and (PentiStat) (hex "0F")
      else
         cmp B (| (hex "80") KEY_KP7)
         if eq
            and (PentiStat) (hex "17")
         else
            cmp B (| (hex "80") KEY_KP8)
            if eq
               and (PentiStat) (hex "1B")
            else
               cmp B (| (hex "80") KEY_KP9)
               if eq
                  and (PentiStat) (hex "1D")
               else
                  cmp B (| (hex "80") KEY_KPPLUS)
                  if eq
                     and (PentiStat) (hex "1E")
                  else
                     cmp B (| (hex "80") KEY_KP5)
                     ret  # Zero or non-zero
                  end
               end
            end
         end
      end
      null (PentiStat)  # Chord complete?
      if z  # Yes
         push C
         ld C (PentiChord)  # Chord in C
         nul (C Penti)  # Reset?
         if z  # Yes
            ld (PentiMod) 0
            ld (PentiLock) 0
         else
            ld A (PentiEnd)  # Arpeggio?
            null A
            if nz
               sub A (PentiBeg)
               cmp A 60000  # Longer than 60 ms
               if gt
                  ld A (USec)
                  sub A (PentiEnd)
                  cmp A 240000  # and not more than 240 ms ago
                  if lt
                     cmp C (hex "18")
                     if eq
                        nul (PentiRev)
                        if nz
                           xor (PentiLock) PENTI_S
                        else
                           or (PentiMod) PENTI_S
                        end
                     else
                        cmp C (hex "14")
                        if eq
                           nul (PentiRev)
                           if nz
                              xor (PentiLock) PENTI_P
                           else
                              or (PentiMod) PENTI_P
                           end
                        else
                           cmp C (hex "12")
                           if eq
                              nul (PentiRev)
                              if nz
                                 xor (PentiLock) PENTI_D
                              else
                                 or (PentiMod) PENTI_D
                              end
                           else
                              cmp C (hex "11")
                              if eq
                                 nul (PentiRev)
                                 if nz
                                    xor (PentiLock) PENTI_C
                                 else
                                    or (PentiMod) PENTI_C
                                 end
                              else
                                 cmp C (hex "0A")
                                 if eq
                                    nul (PentiRev)
                                    if nz
                                       ld B 27  # ESC
                                    else
                                       ld B 10  # ENTER
                                    end
                                    call bufKeyB  # Store
                                    ld (PentiLock) 0
                                    ld (PentiMod) 0
                                 else
                                    cmp C (hex "0C")
                                    jne 10  # Other
                                    nul (PentiRev)
                                    if nz
                                       ld B 8  # BS
                                    else
                                       ld B 9  # TAB
                                    end
                                    call bufKeyB  # Store
                                    ld (PentiMod) 0
                                 end
                              end
                           end
                        end
                     end
                     jmp 20
                  end
               end
            end
10          null (PentiMod)  # Modifiers?
            if z  # No
               ld (PentiMod) (PentiLock)  # Else try lock
            end
            test (PentiMod) PENTI_P  # Punctuation?
            if nz  # Yes
               ld B (C PentiPunct)
            else
               test (PentiMod) PENTI_D  # Digit?
               if nz  # Yes
                  ld B (C PentiDigit)
               else
                  ld B (C Penti)  # Get letter
                  nul B  # Any?
                  if nz  # Yes
                     test (PentiMod) PENTI_S  # Shift?
                     if nz
                        sub B (hex "20")  # Yes
                     end
                     test (PentiMod) PENTI_C  # Ctrl?
                     if nz
                        and B (hex "1F")  # Yes
                     end
                  end
               end
            end
            call bufKeyB  # Store
            ld (PentiMod) 0
         end
20       ld (PentiChord) 0
         set (PentiRev) 0
         ld (PentiEnd) 0
         pop C
      end
   end
   eq  # 'z'
   ret

# vi:et:ts=3:sw=3

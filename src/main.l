# 03mar17abu
# (c) Software Lab. Alexander Burger

### PilOS main ###
# Free memory in A - S
(code 'main)
   ld (Heap) A  # Save heap start address
   ld (Limit) A  # Set heap limit
   ld (Stack0) S  # Set top level stack pointer
   ld A S  # Stack top in A
   sub A (* 4 STACK)  # Decrement by main segment size
   ld (Stack1) A  # Set coroutine stack base
   ld L 0  # Init link register
   call heapAlloc  # Allocate initial heap
   ld E Nil  # Init NIL
   ld X (E TAIL)  # Get name
   ld Y Pico  # Use initial symbol namespace
   ld Z E  # NIL: No more namespaces
   call internEXYZ_FE  # Store NIL to internals
   add E VI  # Skip padding and 'Pico' cell
   do  # Init internal symbols
      ld X (E TAIL)  # Get name
      call internEXYZ_FE  # Store to internals
      cnt (E TAIL)  # Short name?
      if nz  # Yes
         add E II  # Next symbol
      else
         add E IV
      end
      cmp E SymTabEnd
   until gt
   call cons_A  # Create external symbol tree root node
   ld (A) Db1  # '{1}'
   ld (A CDR) Nil
   ld (Extern) A
   call clearScreen  # Clear screen
   ld (Get_A) getStdin_A  # Standard input
   ld (PutB) putStdoutB  # Standard output
   ld C PilOSmsg  # Print greeting
   call outStringC
   ld E Nil  # and version
   call doVersion
   ld C Heapm1sg  # Show heap size
   call outStringC
   ld A S  # TOS
   sub A (Heap)  # minus heap start
   shr A 20  # in MiB
   call outWordA
   ld C Heap2msg
   call outStringC
   ? (gt0 SSD)  # Solid state disks?
      ld X 0  # Yes: Init counter
      ld Y DbFiles  # Get DbFile index
      do
         ld (Y I) X  # Store file number
         ld (DbFile) Y  # Set current file
         ld C (+ BLK BLK 1)  # Read block shift
         ld E 0  # from block zero
         ld Z Buf  # into 'Buf'
         call blkPeekCEZ
         ld B (Z (+ BLK BLK))  # Get block shift
         ld (Y II) B  # Store in DB structure
         ld C BLKSIZE  # Calculate block size
         shl C B
         ld (Y III) C  # Set in dbFile
         ld (Y IV) 0  # Clear 'flgs'
         ld (Y V) 0  # mark vector size
         ld (Y VI) 0  # and mark bit vector
         ld (Y VII) -1  # Init 'fluse'
         add Y VIII  # Increment index by sizeof(dbFile)
         inc X   # Next file number
         cmp X SSD  # Done?
      until eq  # Yes
      ld X 0  # No context
      ld E (DB)  # Get *DB
      ld C TSym  # and T
      call getnECX_E  # (get *DB T)
      cmp E Nil  # Any?
      if ne  # Yes
         call dbFetchEX  # Fetch it
         ld Y E  # into Y
         do
            atom Y  # More files?
         while z  # Yes
            ld E (Y)  # Get next
            ld X 0  # Runtime expression
            call loadBEX_E  # Load file
            ld Y (Y CDR)
         loop
      end
   =
(code 'restart)
   ld B (char ":")  # Prompt
   ld E Nil  # REPL
   ld X 0  # Runtime expression
   call loadBEX_E
   jmp restart

# Global return labels
(code 'Ret 0)
   ret
(code 'RetEq 0)
   eq
   ret
(code 'RetGt 0)
   gt
   ret
(code 'RetLt 0)
   lt
   ret
(code 'RetNil 0)
   ld E Nil
   ret
(code 'RetT 0)
   ld E TSym
   ret
(code 'RetE_E 0)
   ld E (E)  # Get value or CAR
   ret

# Allocate cell heap
(code 'heapAlloc 0)  # AEX
   ld A (Limit)  # Get heap limit
   add A HEAP  # Increment
   null (Stacks)  # Coroutines?
   if z  # No
      lea (StkLimit) (A 4096)  # Set stack limit
      cmp S (StkLimit)  # Stack check
   else
      ld X (Stack1)  # Coroutine stack base
      ld E (Stacks)  # Segment count
      do
         sub X (StkSize)  # Segment size
         dec E  # Find lowest
      until z
      cmp X A  # Stack check
   end
   jlt allocErr
   ld E (Limit)  # Old limit in E
   ld (Limit) A  # Set new limit
   ld X (Avail)  # Initialize free list
   do
      sub A II  # Next cell
      ld (A) X  # Link avail
      ld X A
      cmp A E  # Done?
   until eq  # Yes
   ld (Avail) X  # Set new Avail
   ret

# Signal handler
(code 'sighandler0)
   push E
   ld E 0
   call sighandlerE
   pop E
   ret

(code 'sighandlerX)
   push E
   ld E X
   call sighandlerE
   pop E
   ret

(code 'sighandlerE)
   null (EnvProtect)  # Protected?
   if z  # No
      inc (EnvProtect)
      push A
      push C
      do
         null (SigIO)  # I/O signal?
         if nz  # Yes
            nop
         else
            null (SigAlarm)  # Timeout signal?
            if nz  # Yes
               nop
            else
               null (SigInt)  # Ctrl-C interrupt?
               if nz  # Yes
                  dec (Signal)
                  dec (SigInt)
                  null E  # Runtime expression?
                  ldz E Nil  # No: Default to NIL
                  call brkLoadE_E  # Enter debug breakpoint
               end
            end
         end
         null (Signal)  # More signals?
      until z  # No
      pop C
      pop A
      ld (EnvProtect) 0
   end
   ret

#  (raw ['flg]) -> flg
(code 'doRaw 2)
   ld E (E CDR)  # Arg?
   atom E
   if nz  # No
      nul (Raw)  # Return raw flag
      jnz retT
      ld E Nil
      ret
   end
   ld E (E)  # Evaluate arg
   eval
   cmp E Nil  # NIL?
   if eq  # Yes
      set (Raw) 0  # Set raw cooked mode
      ld E Nil
      ret
   end
   set (Raw) 1  # Set raw mode
   ld E TSym
   ret

# (protect . prg) -> any
(code 'doProtect 2)
   push X
   ld X (E CDR)  # Get 'prg'
   inc (EnvProtect)
   prog X  # Run 'prg'
   dec (EnvProtect)
   pop X
   ret

# (heap 'flg) -> cnt
(code 'doHeap 2)
   ld E ((E CDR))  # Get arg
   eval  # Eval it
   cmp E Nil  # NIL?
   if eq  # Yes
      ld E (Limit)  # Get heap limit
      sub E (Heap)  # Heap size
      shr E 20 # Divide by 1M, clear tags
      shl E 4  # Make short number
      or E CNT
      ret
   end
   ld E 0  # Init count
   ld C (Avail)  # Get avail list
   do
      null C  # Any?
   while nz  # Yes
      inc E  # Increment count
      ld C (C)  # Follow link
   loop
   shr E (- 20 4)  # Divide by 1M/16, clear tags
   shl E 4  # Make short number
   or E CNT
   ret

# (stack ['cnt]) -> cnt | (.. sym . cnt)
(code 'doStack 2)
   push X
   ld X E
   ld E (E CDR)  # Arg?
   atom E
   if z  # Yes
      null (Stacks)  # Stack segments allocated?
      if z  # No
         ld E (E)  # Eval 'cnt'
         call evCntEX_FE
         shl E 12  # Main stack segment size [times 4 kB]
         ld A (Stack0)  # Get stack top
         sub A E  # Decrement by main segment size
         ld (Stack1) A  # New coroutine stack base
         shr E 2  # [to bytes]
         ld (StkSize) E  # Set new stack size
         shr E 6  # Make short number [kB]
         or E CNT
         pop X
         ret
      end
   end
   ld E (StkSize)  # Return current stack size
   shr E 6  # Make short number [kB]
   or E CNT
   ld X (Stack1)  # Collect coroutines
   ld C (Stacks)  # Segment bitmask
   do
      null C  # Any?
   while nz  # Yes
      null (X -I)  # In use?
      if nz  # Yes
         call consE_A  # Cons 'tag'
         ld (A) (X -I)
         ld (A CDR) E
         ld E A
         dec C  # Decrement count
      end
      sub X (StkSize)  # Next segment
   loop
   pop X
   ret

# (ptr 'num ['cnt]) -> cnt
(code 'doPtr 2)
   push X
   push Y
   push Z
   ld X E
   ld Y (E CDR)  # Y on args
   ld E (Y)  # Eval address
   eval
   num E  # Number?
   jz numErrEX  # No
   cnt E  # Short
   if nz  # Yes
      shr E 4  # Normalize
      ld Z E  # Address in Z
   else
      ld Z (E DIG)  # Else get full 64-bit address
   end
   ld Y (Y CDR)  # Store arg?
   atom Y
   if nz  # No
      ld B (Z)  # Fetch byte
      zxt
      ld E A
   else
      call evCntXY_FE  # New value
      ld A E
      ld (Z) B  # Store it
   end
   shl E 4  # Make short number
   or E CNT
   pop Z
   pop Y
   pop X
   ret

# (ptr32 'num ['cnt]) -> cnt
(code 'doPtr32 2)
   push X
   push Y
   push Z
   ld X E
   ld Y (E CDR)  # Y on args
   ld E (Y)  # Eval address
   eval
   num E  # Number?
   jz numErrEX  # No
   cnt E  # Short
   if nz  # Yes
      shr E 4  # Normalize
      ld Z E  # Address in Z
   else
      ld Z (E DIG)  # Else get full 64-bit address
   end
   ld Y (Y CDR)  # Store arg?
   atom Y
   if nz  # No
      ld4 (Z)  # Fetch 32 bits
      ld E A
   else
      call evCntXY_FE  # New value
      ld A E
      st4 (Z)  # Store it
   end
   shl E 4  # Make short number
   or E CNT
   pop Z
   pop Y
   pop X
   ret

# (adr 'var) -> num
# (adr 'num) -> var
(code 'doAdr 2)
   ld E ((E CDR))  # Eval arg
   eval
   num E  # 'num' argument?
   if nz  # Yes
      off E CNT  # Make 'var'
      ret
   end
   or E CNT  # Make 'num'
   ret

# (env ['lst] | ['sym 'val] ..) -> lst
(code 'doEnv 2)
   push X
   ld X (E CDR)
   link
   push Nil  # <L II> Safe
   push Nil  # <L I> Result
   link
   atom X  # Args?
   if nz  # No
      push Y
      ld Y (EnvBind)  # Bindings
      do
         null Y  # Any?
      while nz  # Yes
         ld C (Y)  # End of bindings
         null (Y -I)  # Env swap zero?
         if z  # Yes
            add Y I  # Y on bindings
            do
               ld E (Y)  # Next symbol
               ld X (L I)  # Get result
               do
                  atom X  # More result items?
                  if nz  # No
                     call cons_A  # Cons symbol and its value
                     ld (A) E
                     ld (A CDR) (E)
                     call consA_X  # Cons to result
                     ld (X) A
                     ld (X CDR) (L I)
                     ld (L I) X
                     break T
                  end
                  cmp E ((X))  # Symbol already in result?
               while ne  # No
                  ld X (X CDR)  # Next result item
               loop
               add Y II  # Skip value
               cmp Y C  # More?
            until eq  # No
         end
         ld Y (C I)  # Bind link
      loop
      pop Y
   else
      do
         ld E (X)  # Eval 'lst' or 'sym'
         eval
         ld (L II) E  # Save
         atom E  # 'lst'?
         if z  # Yes
            do
               call cons_A  # Prepare new cell
               ld C (E)  # Next item already a pair?
               atom C
               if z  # Yes
                  ld (A) (C)  # Copy it
                  ld (A CDR) (C CDR)
               else
                  ld (A) C  # Cons symbol and its value
                  ld (A CDR) (C)
               end
               call consA_C  # Cons to result
               ld (C) A
               ld (C CDR) (L I)
               ld (L I) C
               ld E (E CDR)  # Next item in 'lst'
               atom E  # Any?
            until nz  # No
         else
            cmp E Nil  # NIL?
            if ne  # No
               ld X (X CDR)  # Next arg
               ld E (X)  # Eval
               eval
               call consE_A  # Cons symbol and value
               ld (A) (L II)  # Safe
               ld (A CDR) E
               call consA_C  # Cons to result
               ld (C) A
               ld (C CDR) (L I)
               ld (L I) C
            end
         end
         ld X (X CDR)  # More args?
         atom X
      until nz  # No
   end
   ld E (L I)  # Get result
   drop
   pop X
   ret

# (trail ['flg]) -> lst
(code 'doTrail 2)
   push X
   push Y
   push Z
   ld E ((E CDR))  # Evaluate arg
   eval
   ld Z E  # Keep 'flg' in Z
   ld X (EnvBind)  # Bindings
   ld E Nil  # Result
   do
      null X  # Bindings?
   while nz  # Yes
      ld C (X)  # End of bindings
      null (X -I)  # Env swap zero?
      if z  # Yes
         add X I  # X on bindings
         do
            ld Y (X)  # Next symbol
            add X II  # Next entry
            cmp Y At  # Lambda frame?
            if eq  # Yes
               cmp X C  # Last entry?
               if eq  # Yes
                  call consE_A  # Cons 'exe'
                  ld (A) (C II)
                  ld (A CDR) E
                  ld E A
                  break T
               end
            end
            cmp Z Nil  # 'flg'?
            if ne  # Yes
               call consE_A  # Cons value
               ld (A) (Y)
               ld (A CDR) E
               call consA_E  # Cons symbol
               ld (E) Y
               ld (E CDR) A
               ld (Y) (X -I)  # Set old value
            end
            cmp X C  # More?
         until eq  # No
      end
      ld X (C I)  # Bind link
   loop
   ld X E  # Restore values
   do
      atom X  # More?
   while z  # Yes
      ld Y (X)  # Next entry
      ld X (X CDR)
      atom Y # Symbol?
      if nz  # Yes
         ld (Y) (X)  # Set old value
         ld X (X CDR)
      end
   loop
   pop Z
   pop Y
   pop X
   ret

# (up [cnt] sym ['val]) -> any
(code 'doUp 2)
   push X
   ld C 1  # Count
   ld E (E CDR)  # First arg
   ld X (E)  # Get 'sym'
   cnt X  # 'cnt'?
   if nz  # Yes
      ld C X  # Count
      shr C 4  # Normalize
      ld E (E CDR)  # Skip arg
      ld X (E)  # 'sym'
   end
   cmp X Nil  # NIL?
   if eq  # Yes
      ld X (EnvBind)  # Bindings
      do
         null X  # Any?
      while nz  # Yes
         ld A (X)  # End of bindings in A
         cmp (A -II) At  # Lambda frame?
         if eq  # Yes
            dec C  # Done?
            if z  # Yes
               ld E (A II)  # Return 'exe'
               pop X
               ret
            end
         end
         ld X (A I)  # Bind link
      loop
      ld E Nil  # Return NIL
      pop X
      ret
   end
   push Y
   push Z
   ld E (E CDR)  # Last arg
   ld Y (EnvBind)  # Bindings
   ld Z X  # Value pointer
   do
      null Y  # Bindings?
   while nz  # Yes
      ld A (Y)  # End of bindings in A
      add Y I
      do
         cmp X (Y)  # Found symbol?
         if eq  # Yes
            lea Z (Y I)  # Point to saved value
            dec C  # Decrement count
            jz 10  # Done
         end
         add Y II
         cmp Y A  # More?
      until eq  # No
      ld Y (A I)  # Bind link
   loop
10 atom E  # 'val' arg?
   if nz  # No
      ld E (Z)  # Get value
   else
      ld E (E)  # Eval last arg
      eval
      ld (Z) E  # Store value
   end
   pop Z
   pop Y
   pop X
   ret

(code 'circE_EF)
   atom E  # Atom?
   jnz 10  # Yes
   ld A E  # List in A
   do
      or (A) 1  # Mark
      ld A (A CDR)  # Normal list?
      atom A
      if nz  # Yes
         ld A E  # List in A again
         do
            off (A) 1  # Unmark
            ld A (A CDR)
            atom A  # Done?
         until nz  # Yes
10       ret  # 'nz' - No circularity found
      end
      test (A) 1  # Detected circularity?
      if nz  # Yes
         do
            cmp E A  # Skip non-circular part
         while ne
            off (E) 1  # Unmark
            ld E (E CDR)
         loop
         do
            off (A) 1  # Unmark circular part
            ld A (A CDR)
            cmp A E  # Done?
         until eq  # Yes
         ret  # 'eq' - Circularity in E
      end
   loop

### Comparisons ###
(code 'equalAE_F 0)
   cmp A E  # Pointer-equal?
   jeq ret  # Yes: 'eq'
   cnt A  # A short?
   jnz ret  # Yes: 'ne'
   big A  # A big?
   if nz  # Yes
      big E  # E also big?
      jz RetGt  # No: 'ne'
      test A SIGN  # A negative?
      if nz  # Yes
         test E SIGN  # E also negative?
         jz RetGt  # No: 'ne'
         off A SIGN  # Make both positive
         off E SIGN
      end
      do
         cmp (A DIG) (E DIG)  # Digits equal?
      while eq  # Yes
         ld A (A BIG)  # Else next digits
         ld E (E BIG)
         cmp A E  # Pointer-equal?
      while ne  # No
         cnt A  # A short?
      while z  # No
         cnt E  # E short?
      until nz  # Yes
      ret
   end
   sym A  # A symbolic?
   if nz  # Yes
      num E  # E also symbolic?
      jnz RetGt
      sym E
      jz RetGt  # No: 'ne'
      ld A (A TAIL)
      call nameA_A  # Get name of A
      cmp A ZERO  # Any?
      jeq retGt  # No: 'ne'
      ld E (E TAIL)
      call nameE_E  # Get name of E
      cmp E ZERO  # Any?
      jeq retGt  # No: 'ne'
      jmp equalAE_F
   end
   atom E  # E atomic?
   jnz ret  # Yes: 'ne'
   cmp S (StkLimit)  # Stack check
   jlt stkErr
   push X
   push Y
   ld X A  # Keep list heads
   ld Y E
   do
      push A  # Save lists
      push E
      ld A (A)  # Recurse on CARs
      ld E (E)
      off E 1  # Clear possible mark
      call equalAE_F  # Equal?
      pop E  # Retrieve lists
      pop A
      break ne  # No: 'ne'
      atom (A CDR)  # A's CDR atomic?
      if nz  # Yes
         push A  # Save lists
         push E
         ld A (A CDR)  # Recurse on CDRs
         ld E (E CDR)
         call equalAE_F  # Compare with E's CDR
         pop E  # Retrieve lists
         pop A
         break T
      end
      atom (E CDR)  # E's CDR atomic?
      break nz  # Yes: 'ne'
      or (A) 1  # Mark
      ld A (A CDR)
      ld E (E CDR)
      test (A) 1  # Detected circularity?
      if nz
         do
            cmp X A  # Skip non-circular parts
            if eq  # Done
               cmp Y E  # Circular parts same length?
               if eq  # Perhaps
                  do
                     ld X (X CDR)  # Compare
                     ld Y (Y CDR)
                     cmp Y E  # End of second?
                     if eq  # Yes
                        cmp X A  # Also end of first?
                        break T
                     end
                     cmp X A  # End of first?
                     break eq  # Yes
                  loop
               end
               break T
            end
            cmp Y E
            if eq
               gt  # Result "No"
               break T
            end
            off (X) 1  # Unmark
            ld X (X CDR)
            ld Y (Y CDR)
         loop
         push zsc  # Save result
         do
            off (X) 1  # Unmark circular part
            ld X (X CDR)
            cmp X A
         until eq
         pop zsc  # Get result
         pop Y
         pop X
         ret
      end
   loop
   push zsc  # Save result
   do
      cmp X A  # Skip non-circular part
   while ne
      off (X) 1  # Unmark
      ld X (X CDR)
   loop
   pop zsc  # Get result
   pop Y
   pop X
   ret

(code 'compareAE_F 0)  # C
   cmp A E  # Pointer-equal?
   jeq ret  # Yes
   cmp A Nil
   if eq
10    lt  # [NIL E]
      ret
   end
   cmp A TSym
   if eq  # [T E]
20    gt
      ret
   end
   num A  # Number?
   if nz  # Yes
      num E  # Both?
      jnz cmpNumAE_F  # [<num> <num>]
      cmp E Nil
      jeq 20  # [<num> NIL]
      lt  # [<num> <sym|pair>]
      ret
   end
   sym A
   if nz  # [<sym> ..]
      num E
      jnz 20  # [<sym> <num>]
      cmp E Nil
      jeq 20  # [<sym> NIL]
      atom E
      jz 10  # [<sym> <pair>]
      cmp E TSym
      jeq 10  # [<sym> T]
      push X  # [<sym> <sym>]
      ld X (A TAIL)
      call nameX_X  # Get A's name in X
      cmp X ZERO  # Any?
      if eq  # No
         ld X (E TAIL)
         call nameX_X  # Second name in X
         cmp X ZERO  # Any?
         if eq  # No
            cmp A E  # Compare symbol addresses
         else
            lt
         end
         pop X
         ret
      end
      ld E (E TAIL)
      call nameE_E  # Get E's name in E
      cmp E ZERO  # Any?
      if eq  # No
30       gt
40       pop X
         ret
      end
      do
         cnt X  # Get next digit from X into A
         if nz
            ld A X  # Short
            shr A 4  # Normalize
            and A (hex "3FFFFFFFFFFFFFF")  # Mask status bits
            ld X 0
         else
            ld A (X DIG)  # Get next digit
            ld X (X BIG)
         end
         cnt E  # Get next digit from E into C
         if nz
            ld C E  # Short
            shr C 4  # Normalize
            and C (hex "3FFFFFFFFFFFFFF")  # Mask status bits
            ld E 0
         else
            ld C (E DIG)  # Get next digit
            ld E (E BIG)
         end
         do
            cmp B C  # Bytes equal?
            jne 40  # No: lt or gt
            shr A 8  # Next byte in A?
            if z  # No
               shr C 8  # Next byte in C?
               if nz  # Yes
                  lt
                  pop X
                  ret
               end
               null X  # X done?
               if z  # Yes
                  null E  # E also done?
                  jz 40  # Yes: eq
                  lt
                  pop X
                  ret
               end
               null E  # E done?
               jz 30  # Yes: gt
               break T
            end
            shr C 8  # Next byte in C?
            jz 30  # No: gt
         loop
      loop
   end
   atom E
   if nz  # [<pair> <sym>]
      cmp E TSym
      if eq
         lt  # [<pair> T]
         ret
      end
      gt
      ret
   end
   cmp S (StkLimit)  # Stack check
   jlt stkErr
   push X  # [<pair> <pair>]
   push Y
   ld X A  # Keep originals
   ld Y E
   do
      push A  # Recurse on CAR
      push E
      ld A (A)
      ld E (E)
      call compareAE_F  # Same?
      pop E
      pop A
   while eq  # Yes
      ld A (A CDR)  # Next elements
      ld E (E CDR)
      atom A  # End of A?
      if nz  # Yes
         call compareAE_F  # Compare CDRs
         break T
      end
      atom E  # End of E?
      if nz  # Yes
         cmp E TSym
         if ne
            gt  # [<pair> <atom>]
            break T
         end
         lt  # [<pair> T]
         break T
      end
      cmp A X  # Circular list?
      if eq
         cmp E Y
         break eq  # Yes
      end
   loop
   pop Y
   pop X
   ret  # F

(code 'binSizeX_A 0)
   cnt X  # Short number?
   if nz  # Yes
      shr X 3  # Normalize short, keep sign bit
      jmp 20
   end
   big X  # Big number?
   if nz  # Yes
      off X SIGN  # Make positive
      ld A 9  # Count 8 significant bytes plus 1
      do
         ld C (X DIG)  # Keep digit
         ld X (X BIG)  # More cells?
         cnt X
      while z  # Yes
         add A 8  # Increment count by 8
      loop
      shr X 4  # Normalize short
      add C C  # Get most significant bit of last digit
      addc X X  # Any significant bits in short number?
      jmp 40
   end
   ld A 1  # Preload 1
   cmp X Nil  # NIL?
   if ne  # No
      sym X  # Symbol?
      if nz  # Yes
         ld X (X TAIL)
         call nameX_X  # Get name
         cmp X ZERO  # Any?
         if ne  # Yes
            cnt X  # Short name?
            if nz  # Yes
               shl X 2  # Strip status bits
               shr X 6  # Normalize
20             ld A 2  # Count significant bytes plus 1
               do
                  shr X 8  # More bytes?
               while nz  # Yes
                  inc A  # Increment count
               loop
               ret
            end
            ld A 9  # Count significant bytes plus 1
            do
               ld X (X BIG)  # More cells?
               cnt X
            while z  # Yes
               add A 8  # Increment count by 8
            loop
            shr X 4  # Any significant bits in short name/number?
40          if nz  # Yes
               do
                  inc A  # Increment count
                  shr X 8  # More bytes?
               until z  # No
            end
            cmp A (+ 63 1)  # More than one chunk?
            if ge  # Yes
               ld X A  # Keep size+1 in X
               sub A 64  # Size-63
               ld C 0  # Divide by 255
               div 255
               lt  # Plus 1
               addc A X  # Plus size+1
            end
         end
         ret
      end
      push X  # <S I> List head
      push 2  # <S> Count
      do
         push (X CDR)  # Save rest
         ld X (X)  # Recurse on CAR
         call binSizeX_A
         pop X
         add (S) A  # Add result to count
         cmp X Nil  # CDR is NIL?
      while ne  # No
         cmp X (S I)  # Circular?
         if eq  # Yes
            inc (S)  # Increment count once more
            break T
         end
         atom X  # Atomic CDR?
         if nz  # Yes
            call binSizeX_A  # Get size
            add (S) A  # Add result to count
            break T
         end
      loop
      pop A  # Get result
      add S I  # Drop list head
   end
   ret

(code 'memberXY_FY 0)
   ld C Y  # Keep head in C
   do
      atom Y  # List?
   while z  # Yes
      ld A X
      ld E (Y)
      call equalAE_F  # Member?
      jeq ret  # Return list
      ld Y (Y CDR)  # Next item
      cmp C Y  # Hit head?
      jeq retGt  # Yes
   loop
   ld A X
   ld E Y
   jmp equalAE_F  # Same atoms?

# (quit ['any ['any]])
(code 'doQuit 2)
   ld X (E CDR)  # Args
   call evSymX_E  # Evaluate to a symbol
   call bufStringE_SZ  # Write to stack buffer
   ld X (X CDR)  # Next arg?
   atom X
   ldnz E 0  # No
   if z  # Yes
      ld E (X)
      eval  # Eval
   end
   ld X 0  # No context
   ld Y S  # Buffer pointer
   jmp errEXY  # Jump to error handler

### Evaluation ###
# Apply EXPR in C to CDR of E
(code 'evExprCE_E 0)
   cmp S (StkLimit)  # Stack check
   jlt stkErrE
   push X
   push Y
   push Z
   ld X (E CDR)  # Get CDR
   ld Y (C)  # Parameter list in Y
   ld Z (C CDR)  # Body in Z
   push E  # Save 'exe'
   push (EnvBind)  # Build bind frame
   link
   push (At)  # Bind At
   push At
   do
      atom Y  # More evaluating parameters?
   while z  # Yes
      ld E (X)  # Get next argument
      ld X (X CDR)
      eval+  # Evaluate and save
      push E
      push (Y)  # Save symbol
      ld Y (Y CDR)
   loop
   cmp Y Nil  # NIL-terminated parameter list?
   if eq  # Yes: Bind parameter symbols
      ld Y L  # Y on bindings
      do
         sub Y II  # Next binding
         xchg ((Y)) (Y I)  # Exchange symbol value
         cmp Y S  # End?
      until eq  # Yes
      link
      ld (EnvBind) L  # Close bind frame
      push 0  # Init env swap
      prog Z  # Run body
      add S I  # Drop env swap
      pop L  # Get link
      do  # Unbind symbols
         pop X  # Next symbol
         pop (X)  # Restore value
         cmp S L  # More?
      until eq  # No
      pop L  # Restore link
      pop (EnvBind)  # Restore bind link
      add S I  # Drop 'exe'
      pop Z
      pop Y
      pop X
      ret
   end
   # Non-NIL parameter
   cmp Y At  # '@'?
   if ne  # No
      push (Y)  # Save last parameter's old value
      push Y  # and the last parameter
      ld (Y) X  # Set to unevaluated argument list
      lea C (S II)  # End of bindings in C
      ld Y L  # Y on bindings
      do
         sub Y II  # Next binding
         xchg ((Y)) (Y I)  # Exchange symbol value
         cmp Y C  # End?
      until eq  # Yes
      link
      ld (EnvBind) L  # Close bind frame
      push 0  # Init env swap
      prog Z  # Run body
      add S I  # Drop env swap
      pop L  # Get link
      do  # Unbind symbols
         pop X  # Next symbol
         pop (X)  # Restore value
         cmp S L  # More?
      until eq  # No
      pop L  # Restore link
      pop (EnvBind)  # Restore bind link
      add S I  # Drop 'exe'
      pop Z
      pop Y
      pop X
      ret
   end
   # Evaluated argument list
   link  # Close bind frame
   ld Y L  # Y on frame
   push 0  # Init env swap
   push (EnvArgs)  # Save varArgs base
   atom X  # Any args?
   if nz  # No
      ld (EnvArgs) 0
      push (EnvNext)   # Save current 'next'
      ld (EnvNext) 0
   else
      link  # Build varArgs frame
      do
         ld E (X)  # Get next argument
         eval+  # Evaluate and save
         push E
         ld X (X CDR)
         atom X  # More args?
      until nz  # No
      ld (EnvArgs) S  # Set new varArgs base
      link  # Close varArgs frame
      push (EnvNext)   # Save current 'next'
      ld (EnvNext) (L)  # Set new 'next'
   end
   ld (EnvBind) Y  # Close bind frame
   lea C (Y I)  # End of bindings in C
   ld X (Y)  # X on bindings
   do
      sub X II  # Next binding
      xchg ((X)) (X I)  # Exchange symbol value
      cmp X C  # End?
   until eq  # Yes
   prog Z  # Run body
   pop (EnvNext)   # Restore 'next'
   null (EnvArgs)  # VarArgs?
   if nz  # Yes
      drop  # Drop varArgs
   end
   pop (EnvArgs)  # Restore varArgs base
   add S I  # Drop env swap
   pop L  # Get link
   do  # Unbind symbols
      pop X  # Next symbol
      pop (X)  # Restore value
      cmp S L  # More?
   until eq  # No
   pop L  # Restore link
   pop (EnvBind)  # Restore bind link
   add S I  # Drop 'exe'
   pop Z
   pop Y
   pop X
   ret

# Evaluate a list
(code 'evListE_E 0)
   ld C (E)  # Get CAR in C
   num C  # Number?
   jnz ret  # Yes: Return list
   sym C  # Symbol?
   if nz  # Yes
: evListSym
      do  # C is a symbol
         null (Signal)  # Signal?
         if nz  # Yes
            push E
            call sighandlerE
            pop E
         end
         ld A (C)  # Get VAL
         cnt A  # Short number?
         jnz (A T)  # Yes: Eval SUBR
         big A  # Undefined if bignum
         if z
            cmp A (A)  # Auto-symbol?
            if ne  # No
               ld C A
               atom C  # Symbol?
               jz evExprCE_E  # No: Apply EXPR
            end
         end
         jmp undefinedCE
      loop
   end
   cmp S (StkLimit)  # Stack check
   jlt stkErr
   push E
   ld E C
   call evListE_E
   ld C E
   pop E
   cnt C  # Short number?
   jnz (C T)  # Yes: Eval SUBR
   big C  # Undefined if bignum
   jnz undefinedCE
   link
   push C  # Save function
   link
   atom C  # Symbol?
   if z
      call evExprCE_E  # No: Apply EXPR
   else
      call evListSym
   end
   drop
   ret

(code 'execE 0)
   push X
   ld X E
   link
   push (At)  # <L I> Preserve '@'
   link
   exec X  # Execute body
   ld (At) (L I)
   drop
   pop X
   ret

(code 'runE_E 0)
   push X
   ld X E
   link
   push (At)  # <L I> Preserve '@'
   link
   prog X  # Run body
   ld (At) (L I)
   drop
   pop X
   ret

(code 'funqE_FE 0)
   cnt E  # Short number?
   jnz retEq  # Yes
   big E  # Big number?
   jnz ret  # No
   sym E  # Symbol?
   jnz ret  # Yes
   call circE_EF  # Circular?
   jeq retGt  # Yes
   ld C (E CDR)  # Check function body
   do
      atom C  # More?
   while z  # Yes
      ld A (C)  # Next item
      atom A  # Pair?
      if z  # Yes
         num (A)  # CAR a number?
         if nz  # Yes
            atom (C CDR)  # Must be the last
            jz retGt
         else
            cmp (A) Nil  # CAR is NIL?
            jeq retGt  # Yes
            cmp (A) TSym  # CAR is T?
            jeq retGt  # Yes
         end
      else
         cmp (C CDR) Nil  # Atomic item must be the last
         jne ret
      end
      ld C (C CDR)
   loop
   cmp C Nil  # Must be NIL-terminated
   jne ret
   ld E (E)  # Get parameter(s)
   cmp E Nil  # Any?
   ldz E TSym  # No: Return T
   if ne  # Yes
      call circE_EF  # Circular?
      jeq retGt  # Yes
      ld C E
      do
         atom C  # Atomic parameter?
      while z  # No
         ld A (C)  # Next parameter
         num A  # Number?
         jnz ret  # Yes
         atom A  # List?
         jz retGt  # Yes
         cmp A Nil  # NIL?
         jeq retGt  # Yes
         cmp A TSym  # T?
         jeq retGt  # Yes
         ld C (C CDR)  # Rest
      loop
      cmp C TSym  # T?
      jeq retGt  # Yes
      num C  # Number?
      jnz ret  # Yes
   end
   ret

(code 'evSymX_E 0)
   ld E (X)  # Get CAR
   jmp evSymE_E
(code 'evSymY_E 0)
   ld E (Y)  # Get CAR
(code 'evSymE_E)
   eval  # Evaluate
(code 'xSymE_E)
   num E  # Number?
   if z  # No
      sym E  # Symbol?
      jnz ret  # Yes
   end
   push X
   link
   push E  # Save 'any'
   push ZERO  # <L II> Number safe
   push ZERO  # <L I> Result
   ld C 4  # Build name
   ld X S
   link
   call packECX_CX
   ld X (L I)  # Get result
   call consSymX_E  # Make transient symbol
   drop
   pop X
   ret

(code 'evCntXY_FE 0)
   ld E (Y)  # Get CAR
(code 'evCntEX_FE)
   eval  # Evaluate
(code 'xCntEX_FE 0)
   cnt E  #  # Short number?
   jz cntErrEX  # No
   shr E 4  # Normalize
   if x  # Sign?
      neg E  # Yes
   end
   ret  # 'z' if null, 's' if negative

(code 'xCntCX_FC 0)
   cnt C  #  # Short number?
   jz cntErrCX  # No
   shr C 4  # Normalize
   if x  # Sign?
      neg C  # Yes
   end
   ret  # 'z' if null, 's' if negative

(code 'xCntAX_FA 0)
   cnt A  #  # Short number?
   jz cntErrAX  # No
   shr A 4  # Normalize
   if x  # Sign?
      neg A  # Yes
   end
   ret  # 'z' if null, 's' if negative

(code 'boxE_E 0)
   null E  # Positive?
   if ns  # Yes
      test E (hex "F000000000000000")  # Fit in short number?
      jnz boxNumE_E  # No
      shl E 4  # Make short number
      or E CNT
      ret
   end
   neg E  # Else negate
   test E (hex "F000000000000000")  # Fit in short?
   if z  # Yes
      shl E 4  # Make negative short number
      or E (| SIGN CNT)
      ret
   end
   call boxNumE_E  # Make bignum
   or E SIGN  # Set negative
   ret

(code 'putStringB 0)
   push X
   push C
   ld X (StrX)  # Get string status
   ld C (StrC)
   call byteSymBCX_CX  # Add byte to result
   ld (StrC) C  # Save string status
   ld (StrX) X
   pop C
   pop X
   ret

(code 'begString_S 0)
   tos A  # Get return entry
   link
   push ZERO  # <L I> Result
   ld (StrC) 4  # Build name
   ld (StrX) S
   link
   push (PutB)  # Save 'put'
   ld (PutB) putStringB  # Set new
   jmp (A)  # Return

(code 'endStringS_E 0)
   tos A  # Get return entry
   pop (PutB)  # Restore 'put'
   ld E Nil  # Preload NIL
   cmp (L I) ZERO  # Name?
   if ne  # Yes
      call cons_E  # Cons symbol
      ld (E) (L I)  # Set name
      or E SYM  # Make symbol
      ld (E) E  # Set value to itself
   end
   drop
   jmp (A)  # Return

# (args) -> flg
(code 'doArgs 2)
   cmp (EnvNext) (EnvArgs)  # VarArgs?
   ld E Nil
   ldnz E TSym  # Yes
   ret

# (next) -> any
(code 'doNext 2)
   ld C (EnvNext)  # VarArgs
   cmp C (EnvArgs)  # Any?
   if ne  # Yes
      sub C I  # Get next
      ld E (C)
      ld (EnvNext) C
      ret
   end
   ld E Nil  # No (more) arguments
   null C  # Any previous arg?
   if nz  # Yes
      ld (C) E  # Set to NIL
   end
   ret

# (arg ['cnt]) -> any
(code 'doArg 2)
   null (EnvArgs)  # Any args?
   jz retNil  # No
   ld E (E CDR)  # 'cnt' arg?
   atom E
   if nz  # No
      ld E ((EnvNext))  # Return arg from last call to 'next'
      ret
   end
   ld E (E)
   eval  # Eval 'cnt'
   test E SIGN  # Negative?
   if z  # No
      shr E 1  # Normalize to word index
      off E 1  # Clear 'cnt' tag
      if nz  # Greater zero
         ld C (EnvNext)  # VarArgs
         sub C E  # Subtract from VarArgs pointer
         cmp C (EnvArgs)  # Out of range?
         if ge  # No
            ld E (C)  # Get value
            ret
         end
      end
   end
   ld E Nil
   ret

# (rest) -> lst
(code 'doRest 2)
   ld E Nil  # Return value
   ld C (EnvArgs)  # VarArgs
   do
      cmp C (EnvNext)  # Any?
   while ne  # Yes
      call consE_A  # New cell
      ld (A) (C)
      ld (A CDR) E
      ld E A
      add C I  # Next
   loop
   ret

(code 'tmDateA_E 0)
   shr A 24  # Skip second, hour and minute
   ld X A  # Get day
   and X 255
   shr A 8  # month
   ld Y A
   and Y 255
   shr A 8  # and year
   ld Z A
# Date function
(code 'dateXYZ_E 0)
   null Z  # Year <= 0?
   jsz retNil
   null Y  # Month <= 0?
   jsz retNil
   cmp Y 12  # Month > 12?
   jgt retNil
   null X  # Day <= 0?
   jsz retNil
   ld B (Y Month)  # Max monthly days
   cmp X B  # Day > max?
   if gt  # Yes
      cmp Y 2  # February?
      jne retNil
      cmp X 29  # 29th?
      jne retNil
      test Z 3  # year a multiple of 4?
      jnz retNil
      ld A Z  # Year
      ld C 0
      div 100
      null C  # Multiple of 100?
      if z  # Yes
         ld A Z  # Year
         div 400
         null C  # Multiple of 400?
         jnz retNil
      end
   end
   ld A Z  # Get year
   mul 12  # times 12
   add A Y  # plus month
   sub A 3  # minus 3
   ld C 0
   div 12  # divide by 12
   ld E A  # n =  (12 * year + month - 3) / 12
   ld C 0
   div 100  # divide by 100
   ld C E
   shr E 2  # n/4
   add C C  # n*2
   sub E C  # n/4 - n*2
   sub E A  # n/4 - n*2 - n/100
   shr A 2  # n/400
   add E A  # E = n/4 - n*2 - n/100 + n/400
   ld A Z  # Year
   mul 4404  # times 4404
   ld Z A
   ld A Y  # Month
   mul 367  # times 367
   add A Z  # plus year*4404
   sub A 1094  # minus 1094
   div 12  # A = (4404*year + 367*month - 1094) / 12
   add E A  # Add up
   add E X  # plus days
   shl E 4  # Make short number
   or E CNT
   ret

# (date 'dat) -> (y m d)
# (date 'y 'm 'd) -> dat | NIL
# (date '(y m d)) -> dat | NIL
(code 'doDate 2)
   push X
   push Y
   push Z
   ld X E
   ld Y (E CDR)  # Y on args
   atom Y  # Any?
   if nz  # No
      call dateTime  # Get current time
      ld (Time) A  # Keep in 'Time'
      call tmDateA_E  # Extract date
   else
      ld E (Y)  # Eval first
      eval
      cmp E Nil  # NIL?
      if ne  # No
         atom E  # List?
         if z  # Yes
            ld C (E)  # Extract year
            call xCntCX_FC
            ld Z C
            ld E (E CDR)
            ld C (E)  # month
            call xCntCX_FC
            ld Y C
            ld C ((E CDR))  # and day
            call xCntCX_FC
            ld X C
            call dateXYZ_E
         else
            ld Y (Y CDR)  # More args?
            atom Y
            if nz  # No
               call xCntEX_FE  # Get date
               if s
                  ld E Nil  # Can't convert date
                  jmp 90
               end
               ld A E  # 100 * n
               mul 100
               sub A 20  # minus 20
               ld C 0  # divide by 3652425
               div 3652425
               ld Z A  # year = (100*n - 20) / 3652425
               add E A  # n += (year - year/4)
               shr A 2
               sub E A
               ld A E  # n
               mul 100  # 100 * n
               sub A 20  # minus 20
               div 36525  # divide by 36525
               ld Z A  # year = (100*n - 20) / 36525
               mul 36525  # times 36525
               div 100  # divide by 100
               sub E A  # n -= 36525*y / 100
               ld A E  # n
               mul 10  # times 10
               sub A 5  # minus 5
               div 306  # divide by 306
               ld Y A  # month = (10*n - 5) / 306
               mul 306  # times 306
               ld X A
               ld A E  # n
               mul 10  # times 10
               sub A X  # minus 306*month
               add A 5  # push 5
               div 10  # divide by 10
               ld X A  # day = (10*n - 306*month + 5) / 10
               cmp Y 10  # month < 10?
               if lt  # Yes
                  add Y 3  # month += 3
               else
                  inc Z  # Increment year
                  sub Y 9  # month -= 9
               end
               shl X 4  # Make short day
               or X CNT
               call cons_E  # into cell
               ld (E) X
               ld (E CDR) Nil
               shl Y 4  # Make short month
               or Y CNT
               call consE_C  # Cons
               ld (C) Y
               ld (C CDR) E
               shl Z 4  # Make short year
               or Z CNT
               call consC_E  # Cons
               ld (E) Z
               ld (E CDR) C
            else
               call xCntEX_FE  # Extract year
               ld Z E  # into Z
               call evCntXY_FE  # Eval month
               push E  # Save
               ld Y (Y CDR)  # Eval day
               call evCntXY_FE
               ld X E  # Get day
               pop Y  # and month
               call dateXYZ_E
            end
         end
      end
   end
90 pop Z
   pop Y
   pop X
   ret

(code 'tmTimeA_E 0)
   ld Y A  # Save value
   shr A 16  # Get hour
   and A 255
   mul 3600
   ld E A  # Result in E
   ld A Y  # Value again
   shr A 8  # Get minute
   and A 255
   mul 60
   add E A
   and Y 255  # Get second
   add E Y
   shl E 4  # Make short number
   or E CNT
   ret

# (time ['T]) -> tim
# (time 'tim) -> (h m s)
# (time 'h 'm ['s]) -> tim | NIL
# (time '(h m [s])) -> tim | NIL
(code 'doTime 2)
   push X
   push Y
   ld Y (E CDR)  # Y on args
   atom Y  # Any?
   if nz  # No
      call dateTime  # Get current time
      call tmTimeA_E  # Extract time
   else
      ld E (Y)  # Eval first
      eval
      cmp E TSym  # T?
      if eq  # Yes
         ld A (Time)  # Get time from last call to 'dateTime'
         null A  # Any?
         ldz E Nil
         if nz  # Yes
            call tmTimeA_E  # Extract time
         end
      else
         cmp E Nil  # NIL?
         if ne  # No
            atom E  # List?
            if z  # Yes
               ld A (E)  # Extract hour
               call xCntAX_FA
               js 90
               mul 3600
               ld Y A
               ld E (E CDR)
               ld A (E)  # minute
               call xCntAX_FA
               js 90
               cmp A 59
               jgt 90
               mul 60
               add Y A
               ld E (E CDR)  # and second
               atom E  # Any?
               ldnz E Y  # No
               if z  # Yes
                  ld E (E)
                  call xCntEX_FE
                  js 90
                  cmp E 60
                  jgt 90
                  add E Y  # add minutes and hours
               end
               shl E 4  # Make short number
               or E CNT
            else
               ld Y (Y CDR)  # More args?
               atom Y
               if nz  # No
                  call xCntEX_FE  # Get time in total seconds
                  js 90
                  ld A E
                  ld C 0
                  div 60  # Seconds in C
                  shl C 4  # Make short number
                  or C CNT
                  call cons_Y  # into cell
                  ld (Y) C
                  ld (Y CDR) Nil
                  ld A E
                  ld C 0
                  div 60  # Total minutes in A
                  ld C 0
                  div 60  # Minutes in C
                  shl C 4  # Make short number
                  or C CNT
                  call consY_X
                  ld (X) C
                  ld (X CDR) Y
                  xchg A E  # Get total seconds again
                  ld C 0
                  div 3600  # Hours in A
                  shl A 4  # Make short number
                  or A CNT
                  call consX_E
                  ld (E) A
                  ld (E CDR) X
               else
                  call xCntEX_FE  # Extract hour
                  js 90
                  ld A E
                  mul 3600
                  push A  # Save hour
                  call evCntXY_FE  # Eval minute
                  js 80
                  cmp E 59
                  jgt 80
                  ld A E
                  mul 60
                  add (S) A  # Add to hour
                  ld Y (Y CDR)  # Eval second
                  atom Y  # Any?
                  if z  # Yes
                     call evCntXY_FE
                     js 80
                     cmp E 60
                     jgt 80
                     add (S) E
                  end
                  pop E  # Get result
                  shl E 4  # Make short number
                  or E CNT
               end
            end
         end
      end
   end
   pop Y
   pop X
   ret
80 add S I  # Drop partial result
90 ld E Nil  # Can't convert time
   pop Y
   pop X
   ret

# (usec) -> num
(code 'doUsec 2)
   ld E (USec)  # Get microseconds
   shl E 4  # Make short number
   or E CNT
   ret

# (version ['flg]) -> lst
(code 'doVersion 2)
   ld E ((E CDR))  # Eval flg
   eval
   cmp E Nil  # Suppress output?
   if eq  # No
      ld E Version  # Print version
      do
         ld A (E)  # Next number
         shr A 4  # Normalize
         call outWordA  # Print it
         ld E (E CDR)  # More numbers?
         atom E
      while z  # Yes
         ld B `(char ".")  # Output dot
         call (PutB)
      loop
      call newline
   end
   ld E Version  # Return version
   ret

# vi:et:ts=3:sw=3

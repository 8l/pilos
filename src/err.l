# 07jul17abu
# (c) Software Lab. Alexander Burger

# Debug print routine
(code 'dbg)
   push zscx  # Save flags
   push A  # Save registers
   push C
   push E
   push (OutFile)  # Save output channel
   ld (OutFile) 0  # TTY
   push (PutB)  # Save 'put'
   ld (PutB) putStdoutB  # Set new
   ld E (Dbg)  # Print item
   call printE_E
   call newline  # and a newline
   pop (PutB)  # Restore 'put'
   pop (OutFile)  # and output channel
   pop E
   pop C
   pop A
   pop zscx
   ret

# E reason
# X context
# Y message
(code 'errEXY)
   null E  # Reason?
   if nz  # Yes
      link
      push E  # Save reason
      link
   else
      push E  # Push reason
      sub S I  # and dummy
   end
   sub S IV  # <S> outFrame, <S V> reason
   null X  # Error context?
   ld A Nil
   ldnz A X  # Yes
   ld (Up) A  # Save it
   nul (Y)  # Message empty?
   if nz  # No
      ld E Y  # Get message
      call mkStrE_E  # Make transient symbol
      ld (Msg) E  # Store in '*Msg'
      ld C (Catch)  # Search catch frames
      do
         null C  # Any?
      while nz  # Yes
         ld Y (C I)  # Tag non-zero?
         null Y
         if nz  # Yes
            do
               atom Y  # List?
            while z  # Yes
               ld A (Y)  # Next element of tag list
               ld E (Msg)  # Substring of '*Msg'?
               push C
               call subStrAE_F
               pop C
               if eq  # Yes
                  ld Y (Y)  # Get tag list element
                  cmp Y Nil  # NIL?
                  ldz Y (Msg)  # Yes: Use *Msg instead
                  push Y  # Save tag list element
                  call unwindC_Z  # Unwind environments
                  pop E  # Return tag list element from 'catch'
                  ld S Z  # Restore stack
                  pop (Catch)  # Restore catch link
                  add S (pack II "+(EnvEnd-Env)")  # Clean up
                  pop L
                  pop Z
                  pop Y
                  pop X
                  throw
               end
               ld Y (Y CDR)  # Tag list
            loop
         end
         ld C (C)  # Next frame
      loop
   end
   ld (Chr) 0  # Init globals
   ld (ExtN) 0
   ld (Break) 0
   ld (LineX) ZERO
   ld (LineC) -1
   push (OutFile)  # Output
   ld (OutFile) 0  # to TTY
   push (PutB)
   ld (PutB) putStdoutB
   null X  # Error context?
   if nz  # Yes
      ld C ErrTok  # Print error token
      call outStringC
      ld E X  # Get context
      call printE  # Print context
      call newline
   end
   ld E (S VII)  # Get reason
   null E  # any?
   if nz  # Yes
      call printE  # Print reason
      ld C Dashes  # Print " -- "
      call outStringC
   end
   nul (Y)  # Message empty?
   if nz  # No
      ld E (Msg)  # Print message
      call prinE
      call newline
      cmp (Err) Nil  # Error handler?
      if ne  # Yes
         nul (Jam)  # Jammed?
         if z  # No
            set (Jam) 1  # Set flag
            ld X (Err)  # Run error handler
            prog X
            set (Jam) 0  # Reset flag
         end
      end
      pop (PutB)  # Restore output
      pop (OutFile)
      ld B (char "?")  # Prompt
      ld E Nil  # Load argument
      ld X 0  # Runtime expression
      call loadBEX_E
   end
   ld C 0  # Top frame
   call unwindC_Z  # Unwind
   ld (EnvProtect) 0  # Reset environments
   ld (EnvTask) Nil
   ld (EnvCo7) 0
   ld (EnvArgs) 0
   ld (EnvNext) 0
   ld (EnvMake) 0
   ld (EnvYoke) 0
   ld (EnvTrace) 0
   ld L 0  # Init link register
   ld S (Stack0)  # stack pointer
   null (Stacks)  # Coroutines?
   if z  # No
      lea (StkLimit) ((Limit) 4096)  # Reset stack limit
   else
      lea A (S 4096)  # Set stack limit
      sub A (StkSize)
      ld (StkLimit) A
   end
   ld (PutB) putStdoutB
   ld (Get_A) getStdin_A
   jmp restart  # Restart interpreter

(code 'unwindC_Z 0)
   push C  # <S> Target frame
   ld X (Catch)  # Catch link
   ld Y (EnvBind)  # Bindings
   do
      null X  # Catch frames?
   while nz  # Yes
      do
         null Y  # Bindings?
      while nz  # Yes
         ld C (Y -I)  # First env swap
         null C  # Zero?
         if nz  # No
            ld A C  # 'j'
            ld E 0  # 'n'
            ld Z Y  # Bindings in Z
            do
               inc E  # Increment 'n'
               inc A  # Done?
            while nz  # No
               ld Z ((Z) I)  # Follow link
               null Z  # Any?
            while nz  # Yes
               cmp (Z -I) C  # Env swap nesting?
               if lt  # Yes
                  dec A  # Adjust
               end
            loop
            do
               ld Z Y  # Get bindings
               ld A E  # and 'n'
               do
                  dec A  # 'n-1' times
               while nz
                  ld Z ((Z) I)  # Follow link
               loop
               sub (Z -I) C  # Increment 'eswp' by absolute first eswp
               if ge  # Last pass
                  if gt  # Overflowed
                     ld (Z -I) 0  # Reset
                  end
                  lea A ((Z) -II)  # End of bindings in A
                  do
                     xchg ((A)) (A I)  # Exchange next symbol value with saved value
                     sub A II
                     cmp A Z  # More?
                  until lt  # No
               end
               dec E  # Decrement 'n'
            until z  # Done
         end
         cmp Y (X III)  #  Reached last bind frame?
      while ne  # No
         ld C (Y)  # C on link
         null (Y -I)  # Env swap now zero?
         if z  # Yes
            add Y I  # Y on bindings
            do
               ld Z (Y)  # Next symbol
               add Y I
               ld (Z) (Y)  # Restore value
               add Y I
               cmp Y C  # More?
            until eq  # No
         end
         ld Y (C I)  # Bind link
      loop
      do
         cmp (EnvInFrames) (X (pack III "+(EnvInFrames-Env)"))  # Open input frames?
      while ne  # Yes
         call popInFrames  # Clean up
      loop
      do
         cmp (EnvOutFrames) (X (pack III "+(EnvOutFrames-Env)"))  # Open output frames?
      while ne  # Yes
         call popOutFrames  # Clean up
      loop
      ld Z (EnvCo7)  # Get coroutines
      do
         cmp Z (X (pack III "+(EnvCo7-Env)"))  # Skipped?
      while ne  # Yes
         ld C (Stack1)  # Find stack segment
         do
            cmp C (Z II)  # Found 'seg'?
         while ne  # No
            sub C (StkSize)  # Next segment
         loop
         ld (C -I) 0  # Mark segment as unused
         dec (Stacks)  # Last coroutine?
         if z  # Yes
            lea (StkLimit) ((Limit) 4096)  # Reset stack limit
         end
         ld Z (Z)  # Next coroutine
      loop
      load (Env) (EnvEnd) (X III)  # Restore environment
      ld E (X II)  # 'fin'
      eval  # Evaluate 'finally' expression
      cmp X (S)  # Reached target catch frame?
      ld X (X)  # Catch link
      ld (Catch) X
      if eq  # Yes
         pop Z  # Get target frame
         ret
      end
   loop
   add S I  # Drop target frame
   do  # Top level bindings
      null Y  # Any?
   while nz  # Yes
      ld C (Y)  # C on link
      null (Y -I)  # Env swap zero?
      if z  # Yes
         add Y I  # Y on bindings
         do
            ld Z (Y)  # Next symbol
            add Y I
            ld (Z) (Y)  # Restore value
            add Y I
            cmp Y C  # More?
         until eq  # No
      end
      ld Y (C I)  # Bind link
   loop
   ld (EnvBind) 0
   do
      null (EnvInFrames)  # Open input frames?
   while nz  # Yes
      call popInFrames  # Clean up
   loop
   do
      null (EnvOutFrames)  # Open output frames?
   while nz  # Yes
      call popOutFrames  # Clean up
   loop
   ld X (Stack1)  # Search through stack segments
   ld C (Stacks)  # Segment count
   do
      null C  # Any?
   while nz  # Yes
      null (X -I)  # In use?
      if nz  # Yes
         null (X -II)  # Active?
         if z  # Yes
            ld (X -I) 0  # Mark segment as unused
            dec (Stacks)  # Last coroutine?
            if z  # Yes
               lea (StkLimit) ((Limit) 4096)  # Reset stack limit
            end
         end
         dec C  # Decrement count
      end
      sub X (StkSize)  # Next segment
   loop
   ret

### Checks ###
(code 'needSymAX 0)
   num A  # Need symbol
   jnz symErrAX
   sym A
   jz symErrAX
   cmp A Nil  # A < NIL ?
   jlt ret  # Yes
   cmp A TSym  # A > T ?
   jgt Ret  # Yes
   ld E A
   jmp protErrEX

(code 'needSymEX 0)
   num E  # Need symbol
   jnz symErrEX
   sym E
   jz symErrEX
   cmp E Nil  # E < NIL ?
   jlt ret  # Yes
   cmp E TSym  # E > T ?
   jgt Ret  # Yes
   jmp protErrEX

(code 'needVarAX 0)
   num A  # Need variable
   jnz varErrAX
   cmp A Nil  # A < NIL ?
   jlt ret  # Yes
   cmp A TSym  # A > T ?
   jgt Ret  # Yes
   ld E A
   jmp protErrEX

(code 'needVarEX 0)
   num E  # Need variable
   jnz varErrEX
   cmp E Nil  # E < NIL ?
   jlt ret  # Yes
   cmp E TSym  # E > T ?
   jgt Ret  # Yes
   jmp protErrEX

(code 'checkVarAX 0)
   cmp A Nil  # A < NIL ?
   jlt ret  # Yes
   cmp A TSym  # A > T ?
   jgt Ret  # Yes
   ld E A
   jmp protErrEX

(code 'checkVarYX 0)
   cmp Y Nil  # Y < NIL ?
   jlt ret  # Yes
   cmp Y TSym  # Y > T ?
   jgt Ret  # Yes
   ld E Y
   jmp protErrEX

(code 'checkVarEX 0)
   cmp E Nil  # E < NIL ?
   jlt ret  # Yes
   cmp E TSym  # E > T ?
   jgt Ret  # Yes
(code 'protErrEX)
   ld Y ProtErr
   jmp errEXY

(code 'symNsErrEX)
   ld Y SymNsErr
   jmp errEXY

### Error messages ###
(code 'allocErr)
   ld C AllocErr  # Give up
   call outStringC
   call newline
   stop

(code 'stkErr)
   ld E 0
(code 'stkErrE)
   ld X E
(code 'stkErrX)
   ld E 0
(code 'stkErrEX)
   ld Y StkErr
   null (Stacks)  # Coroutines?
   if nz  # Yes
      lea (StkLimit) ((Limit) 4096)  # Reset stack limit
   else
      cmp (StkLimit) (Limit)  # Already in error?
      jeq allocErr  # Yes
      ld (StkLimit) (Limit)  # Temporarily without safety offset
   end
   jmp errEXY

(code 'argErrAX)
   ld E A
(code 'argErrEX)
   ld Y ArgErr
   jmp errEXY

(code 'numErrAX)
   ld E A
(code 'numErrEX)
   ld Y NumErr
   jmp errEXY

(code 'cntErrAX)
   ld C A
(code 'cntErrCX)
   ld E C
(code 'cntErrEX)
   ld Y CntErr
   jmp errEXY

(code 'symErrAX)
   ld Y A
(code 'symErrYX)
   ld E Y
(code 'symErrEX)
   ld Y SymErr
   jmp errEXY

(code 'extErrEX)
   ld Y ExtErr
   jmp errEXY

(code 'pairErrAX)
   ld E A
(code 'pairErrEX)
   ld Y PairErr
   jmp errEXY

(code 'atomErrAX)
   ld E A
(code 'atomErrEX)
   ld Y AtomErr
   jmp errEXY

(code 'lstErrAX)
   ld E A
(code 'lstErrEX)
   ld Y LstErr
   jmp errEXY

(code 'varErrAX)
   ld E A
(code 'varErrEX)
   ld Y VarErr
   jmp errEXY

(code 'divErrX)
   ld E 0
   ld Y DivErr
   jmp errEXY

(code 'renErrEX)
   ld Y RenErr
   jmp errEXY

(code 'makeErrX)
   ld E 0
   ld Y MakeErr
   jmp errEXY

(code 'reentErrEX)
   ld Y ReentErr
   jmp errEXY

(code 'yieldErrX)
   ld E 0
(code 'yieldErrEX)
   ld Y YieldErr
   jmp errEXY

(code 'msgErrYX)
   ld A Y
(code 'msgErrAX)
   ld E A
(code 'msgErrEX)
   ld Y MsgErr
   jmp errEXY

(code 'brkErrX)
   ld E 0
   ld Y BrkErr
   jmp errEXY

# I/O errors
(code 'eofErr)
   ld E 0
   ld X 0
   ld Y EofErr
   jmp errEXY

(code 'suparErrE)
   ld X 0
   ld Y SuparErr
   jmp errEXY

(code 'badInputErr)
   ld E 0
   ld X 0
   ld Y BadInput
   jmp errEXY

(code 'badDotErrE)
   ld X 0
   ld Y BadDot
   jmp errEXY

(code 'dbfErrX)
   ld E 0
   ld Y DbfErr
   jmp errEXY

(code 'idErrXL)
   ld E (L I)  # Get symbol
   ld Y IdErr
   jmp errEXY

(code 'dbRdErr)
   ld E 0
   ld X 0
   ld Y DbRdErr
   jmp errEXY

(code 'dbWrErr)
   ld E 0
   ld X 0
   ld Y DbWrErr
   jmp errEXY

(code 'dbSizErr)
   ld E 0
   ld X 0
   ld Y DbSizErr
   jmp errEXY

### Undefined symbol ###
(code 'undefinedCE)
   ld X E
(code 'undefinedCX)
   ld E C
(code 'undefinedEX)
   ld Y UndefErr
   jmp errEXY

# vi:et:ts=3:sw=3

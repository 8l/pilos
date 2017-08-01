# 04mar17abu
# (c) Software Lab. Alexander Burger

### Low level I/O ###
(code 'stdinByte_A)
   call ttyIn_B  # Get byte
   nul (Raw)  # Raw mode?
   if z  # No
      call ttyOutB  # Echo
   end
   zxt
   ret

(code 'getBinaryZ_FB 0)
   null (Z VI)  # 'cnt'
   jz retLt  # EOF (lt)
   push C
   push E
   ld C (Z VII)  # 'ix'
   cmp C ((Z I) III)  # At 'size'?
   if eq  # Yes
      ld C (Z V)  # Get 'link'
      ld (Z IV) C  # Set 'blk'
      ld A (Z I)  # dbFile
      shl C (A II)  # Shift for current file
      add Z VIII  # Z on 'buf'
      read (A) Z (A III) C  # Read next block
      call getAdrZ_A  # Get link address
      sub Z VIII  # Restore Z
      off A BLKTAG
      ld (Z V) A  # Store as 'link'
      ld C BLK  # New 'ix'
   end
   lea E (Z VIII)  # Get 'buf'
   add E C  # Index
   inc C  # Increment 'ix'
   ld (Z VII) C
   ld B (E)  # Fetch byte
   dec (Z VI)  # Decrement 'cnt'
   pop E
   pop C
   gt
   ret

# Add next byte to a number
(code 'byteNumBCX_CX 0)
   zxt
   big X  # Big number?
   if z  # No: Direct buffer pointer
      # xxxxx.xxxxxxx.xxxxxxx.xxxxxxx.xxxxxxx.xxxxxxx.xxxxxxx.xxxxxxS010
      #    59      51      43      35      27      19      11       3
      cmp C 67  # Short full?
      if eq  # Yes
         ld C (X)  # Get short number
         shr C 3  # De-normalize, keep sign bit
         shl A 4  # New digit
         or A CNT  # Make short number
         call consNumCA_C  # Box number
         ld (X) C
         ld X C
         ld C 12  # Next digit in bignum
         ret
      end
      cmp C 59  # Short digit full?
      if eq  # Yes
         cmp A 32  # Fit into 5 bits?
         if ge  # No
            ld C (X)  # Get short number
            shr C 3  # De-normalize, keep sign bit
            shl A 56  # Combine byte with digit
            or A C
            call boxNumA_A  # Box number
            ld (X) A
            ld X A
            ld C 4  # Start next digit in bignum
            ret
         end
      end
      shl A C  # Shift byte to character position
      or (X) A  # Combine with short number
      add C 8  # Increment position
      ret
   end
   cmp C 68  # Last short full?
   if eq  # Yes
      ld C (X BIG)  # Get short number
      shr C 4  # De-normalize
      shl A 4  # New digit
      or A CNT  # Make short number
      call consNumCA_C  # Box number
      ld (X BIG) C
      ld X C
      ld C 12  # Next digit in bignum
      ret
   end
   cmp C 60  # Short digit full?
   if eq  # Yes
      cmp A 16  # Fit into 4 bits?
      if ge  # No
         ld C (X BIG)  # Get short number
         shr C 4  # De-normalize
         shl A 56  # Combine byte with digit
         or A C
         call boxNumA_A  # Box number
         ld (X BIG) A
         ld X A
         ld C 4  # Next digit in bignum
         ret
      end
   end
   shl A C  # Shift byte to character position
   or (X BIG) A  # Combine with name digit
   add C 8  # Increment position
   ret

# Read binary expression
(code 'binReadZ_FE)
   call (GetBinZ_FB)  # Tag byte?
   jlt ret  # No
   nul B  # NIX?
   jz retNil  # Return NIL
   zxt
   test B (hex "FC")  # Atomic?
   if z  # No
      ld E A
      cmp B BEG  # Begin a list?
      jne retEq  # No: Return DOT or END (also in B)
      call binReadZ_FE  # Else read list
      jlt ret
      push X
      call consE_X  # First cell
      ld (X) E
      ld (X CDR) Nil
      link
      push X  # <L I> Save it
      link
      do
         call binReadZ_FE  # Next item
         jlt 10  # EOF
         cmp E END  # Any?
      while ne  # Yes
         cmp E DOT  # Dotted pair?
         if eq
            cmp B DOT  # Only if B is also DOT (to distinguish from Zero)
            if eq  # Yes
               call binReadZ_FE  # Get CDR
               if lt  # EOF
10                drop
                  pop X
                  ret  # Return 'lt'
               end
               cmp E END  # Circular list?
               ldz E (L I)  # Yes: Get first cell
               ld (X CDR) E  # Store in last cell
               eq  # 'ge'
               break T
            end
         end
         call consE_C  # Append next cell
         ld (C) E
         ld (C CDR) Nil
         ld (X CDR) C
         ld X C
      loop
      ld E (L I)  # Return list
      drop  # Return 'ge'
      pop X
      ret
   end
   push X
   link
   push ZERO  # <L I> Result
   ld X S
   link
   ld E A  # Get tag byte
   shr E 2  # Count
   and A 3  # Tag
   if z  # NUMBER
      ld C 3  # Build signed number
      cmp E 63  # More than one chunk?
      if eq  # Yes
         do
            do
               call (GetBinZ_FB)  # Next byte?
               jlt 90  # No
               call byteNumBCX_CX
               dec E  # Decrement count
            until z
            call (GetBinZ_FB)  # Next count?
            jlt 90  # No
            zxt
            ld E A
            cmp B 255  # Another chunk?
         until ne  # No
         nul B  # Empty?
         jz 20  # Yes
      end
      do
         call (GetBinZ_FB)  # Next byte?
         jlt 90  # No
         call byteNumBCX_CX  # (B is zero (not DOT) if Zero)
         dec E  # Decrement count
      until z
20    ld E (L I)  # Get result
      big E  # Big number?
      if nz  # Yes
         ld X (E DIG)  # Keep lowest digit
         ld A E  # Half result
         call halfA_A
         ld E X  # Sign bit
         and E 1
         shl E 3
         or E A  # Set in result
      end
   else  # INTERN, TRANSIENT or EXTERN
      push A  # Tag
      ld C 4  # Build name
      cmp E 63  # More than one chunk?
      if eq  # Yes
         do
            do
               call (GetBinZ_FB)  # Next byte?
               jlt 90  # No
               call byteSymBCX_CX
               dec E  # Decrement count
            until z
            call (GetBinZ_FB)  # Next count?
            jlt 90  # No
            zxt
            ld E A
            cmp B 255  # Another chunk?
         until ne  # No
         nul B  # Empty?
         jz 30  # Yes
      end
      do
         call (GetBinZ_FB)  # Next byte?
         jlt 90  # No
         call byteSymBCX_CX
         dec E  # Decrement count
      until z
30    ld X (L I)  # Get name
      pop A  # Get tag
      cmp A TRANSIENT  # Transient?
      if eq  # Yes
         call consSymX_E  # Build symbol
      else
         cmp A INTERN  # Internal?
         if eq  # Yes
            push Y
            call findSymX_E  # Find or create it
            pop Y
         else  # External
            null (Extn)  # External symbol offset?
            if nz  # Yes
               ld A X  # Get file number
               shr A 24  # Lower 8 bits
               ld C A  # into C
               and C (hex "FF")
               shr A 12  # Upper 8 bits
               and A (hex "FF00")
               or A C
               add A (Extn)  # Add external symbol offset
               shl A 24
               ld C A  # Lower result bits
               shl A 12
               or A C
               and A (hex "000FF000FF000000")  # Mask file number
               and X (hex "FFF00FFF00FFFFFF")  # Mask object ID
               or X A  # Combine
            end
            call externX_E  # New external symbol
         end
      end
   end
   eq  # 'ge'
90 drop
   pop X
   ret

# Binary print next byte from a number
(code 'prByteCEXY 0)
   null C  # New round?
   if z  # Yes
      cnt X  # Short number?
      if z  # No
         ld E (X DIG)  # Next digit
         ld X (X BIG)
      else
         ld E X  # Get short
         shr E 4  # Normalize
      end
      shr Y 1  # Get overflow bit
      rxl E 1  # Shift into digit
      rxl Y 1  # Keep new overflow bit
      ld C 8  # Init count
   end
   ld A E  # Output next byte
   call (PutBinBZ)
   shr E 8  # Shift to next
   dec C  # Decrement count
   ret

# Binary print short number
(code 'prCntCE 0)
   ld A E
   do
      shr A 8  # More bytes?
   while nz  # Yes
      add C 4  # Increment count
   loop
   ld A C  # Output tag byte
   call (PutBinBZ)
   shr C 2  # Discard tag bits
   do
      ld A E  # Next data byte
      shr E 8
      call (PutBinBZ)  # Output data byte
      dec C  # More?
   until z  # No
   ret

(code 'prE)
   ld (PutBinBZ) putStdoutB  # Set binary print function
(code 'binPrintEZ)
   cnt E  # Short number?
   if nz  # Yes
      ld C 4  # Count significant bytes (adjusted to tag)
      shr E 3  # Normalize
      jmp prCntCE  # Output 'cnt'
   end
   big E  # Big number?
   if nz  # Yes
      push X
      push Y
      push E  # Save signed number
      off E SIGN  # Make positive
      ld X E  # Keep in X
      ld A 8  # Count 8 significant bytes
      do
         ld C (E DIG)  # Keep digit
         ld E (E BIG)  # More cells?
         cnt E
      while z  # Yes
         add A 8  # Increment count by 8
      loop
      shr E 4  # Normalize short
      add C C  # Get most significant bit of last digit
      addc E E  # Any significant bits in short number?
      if nz  # Yes
         do
            inc A  # Increment count
            shr E 8  # More bytes?
         until z  # No
      end
      pop Y  # Get sign
      shr Y 3  # into lowest bit
      ld C 0  # Init byte count
      cmp A 63  # Single chunk?
      if lt  # Yes
         push A  # <S> Count
         shl A 2  # Adjust to tag byte
         call (PutBinBZ)  # Output tag byte
         do
            call prByteCEXY  # Output next data byte
            dec (S)  # More?
         until z  # No
      else
         sub A 63  # Adjust count
         push A  # <S I> Count
         ld B (* 4 63)  # Output first tag byte
         call (PutBinBZ)
         push 63  # <S> and first 63 data bytes
         do
            call prByteCEXY  # Output next data byte
            dec (S)  # More?
         until z  # No
         do
            cmp (S I) 255  # Count greater or equal 255?
         while ge  # Yes
            ld A 255  # Next chunk
            ld (S) A  # and the next 255 data bytes
            call (PutBinBZ)  # Output count byte
            do
               call prByteCEXY  # Output next data byte
               dec (S)  # More?
            until z  # No
            sub (S I) 255  # Decrement counter
         loop
         add S I  # Drop second count
         ld A (S)  # Retrieve count
         call (PutBinBZ)  # Output last count
         do
            sub (S) 1  # More?
         while ge  # Yes
            call prByteCEXY  # Output next data byte
         loop
      end
      add S I  # Drop count
      pop Y
      pop X
      ret
   end
   sym E  # Symbol?
   if nz  # Yes
      cmp E Nil  # NIL?
      if eq  # Yes
         ld B NIX  # Output NIX
         jmp (PutBinBZ)
      end
      sym (E TAIL)  # External symbol?
      if nz  # Yes
         ld E (E TAIL)
         call nameE_E  # Get name
         null (Extn)  # External symbol offset?
         if nz  # Yes
            ld A E  # Get file number
            shr A 24  # Lower 8 bits
            ld C A  # into C
            and C (hex "FF")
            shr A 12  # Upper 8 bits
            and A (hex "FF00")
            or A C
            sub A (Extn)  # Subtract external symbol offset
            shl A 24
            ld C A  # Lower result bits
            shl A 12
            or A C
            and A (hex "000FF000FF000000")  # Mask file number
            and E (hex "FFF00FFF00FFFFFF")  # Mask object ID
            or E A  # Combine
         end
         shl E 2  # Strip status bits
         shr E 6  # Normalize
         ld C (+ 4 EXTERN)  # Count significant bytes (adjusted to tag)
         jmp prCntCE  # Output external name
      end
      push X
      push Y
      ld X (E TAIL)
      call nameX_X  # Get name
      cmp X ZERO  # Any?
      if eq  # No
         ld B NIX  # Output NIX
         call (PutBinBZ)
      else
         call isEnvInternEX_FCE  # Internal symbol?
         ld C INTERN  # Yes
         ldnz C TRANSIENT  # No
         cnt X  # Short name?
         if nz  # Yes
            add C 4  # Count significant bytes (adjusted to tag)
            ld E X  # Get name
            shr E 4  # Normalize
            call prCntCE  # Output internal or transient name
         else  # Long name
            ld E X  # Into E
            ld A 8  # Count significant bytes
            do
               ld E (E BIG)  # More cells?
               cnt E
            while z  # Yes
               add A 8  # Increment count
            loop
            shr E 4  # Any significant bits in short name?
            if nz  # Yes
               do
                  inc A  # Increment count
                  shr E 8  # More bytes?
               until z  # No
            end
            ld E A  # Keep count in E
            cmp A 63  # Single chunk?
            if lt  # Yes
               shl A 2  # Adjust to tag byte
               or A C  # Combine with tag
               call (PutBinBZ)  # Output tag byte
               ld C 0
               do
                  call symByteCX_FACX  # Next data byte
                  call (PutBinBZ)  # Output it
                  dec E  # More?
               until z  # No
            else
               ld B (* 4 63)  # Output first tag byte
               or A C  # Combine with tag
               call (PutBinBZ)
               sub E 63  # Adjust count
               push E  # <S> Count
               ld E 63  # and first 63 data bytes
               ld C 0
               do
                  call symByteCX_FACX  # Next data byte
                  call (PutBinBZ)  # Output it
                  dec E  # More?
               until z  # No
               do
                  cmp (S) 255  # Count greater or equal 255?
               while ge  # Yes
                  ld A 255  # Next chunk
                  ld E A  # and the next 255 data bytes
                  call (PutBinBZ)  # Output count byte
                  do
                     call symByteCX_FACX  # Next data byte
                     call (PutBinBZ)  # Output it
                     dec E  # More?
                  until z  # No
                  sub (S) 255  # Decrement counter
               loop
               pop E  # Retrieve count
               ld A E
               call (PutBinBZ)  # Output last count
               do
                  sub E 1  # More?
               while ge  # Yes
                  call symByteCX_FACX  # Next data byte
                  call (PutBinBZ)  # Output it
               loop
            end
         end
      end
      pop Y
      pop X
      ret
   end
   push X
   push Y
   ld B BEG  # Begin list
   call (PutBinBZ)
   ld X E  # Keep list in X
   call circE_EF  # Circular?
   if nz  # No
      do
         ld E (X)  # Next item
         call binPrintEZ
         ld X (X CDR)  # NIL-terminated?
         cmp X Nil
      while ne  # No
         atom X  # Atomic tail?
         if nz  # Yes
            ld B DOT  # Output dotted pair
            call (PutBinBZ)
            ld E X  # Output atom
            call binPrintEZ
            pop Y  # Return
            pop X
            ret
         end
      loop
   else
      ld Y E  # Non-circular part
      cmp X E  # Fully circular?
      if eq  # Yes
         do
            ld E (X)  # Output CAR
            call binPrintEZ
            ld X (X CDR)  # Done?
            cmp X Y
         until eq  # Yes
         ld B DOT  # Output dotted pair
         call (PutBinBZ)
      else
         do  # Non-circular part
            ld E (X)  # Output CAR
            call binPrintEZ
            ld X (X CDR)  # Done?
            cmp X Y
         until eq  # Yes
         ld B DOT  # Output DOT+BEG
         call (PutBinBZ)
         ld B BEG
         call (PutBinBZ)
         do  # Circular part
            ld E (X)  # Output CAR
            call binPrintEZ
            ld X (X CDR)  # Done?
            cmp X Y
         until eq  # Yes
         ld B DOT  # Output DOT
         call (PutBinBZ)
      end
   end
   pop Y
   pop X
   ld B END  # End list
   jmp (PutBinBZ)

# Return next byte from symbol name
(code 'symByteCX_FACX 0)
   null C  # New round?
   if z  # Yes
      cmp X ZERO  # Done?
      jeq ret  # Yes: Return 'z'
      cnt X  # Short?
      if nz  # Yes
         ld C X  # Get short
         shr C 4  # Normalize
         ld X ZERO  # Clear for next round
      else
         ld C (X DIG)  # Get next digit
         ld X (X BIG)
      end
   end
   ld A C  # Get byte
   shr C 8  # Shift out
   zxt  # Return B
   null A
   ret

(code 'symCharCX_FACX 0)  # Return next char from symbol name
   call symByteCX_FACX  # First byte
   jz ret  # Return 'z' if none
   cmp B (hex "FF")  # Special?
   if ne  # No
      cmp B 128  # Single byte?
      if ge  # No
         test B (hex "20")  # Two bytes?
         if z  # Yes
            and B (hex "1F")  # First byte 110xxxxx
            shl A 6  # xxxxx000000
            push A
         else  # Three bytes
            and B (hex "F")  # First byte 1110xxxx
            shl A 6  # xxxx000000
            push A
            call symByteCX_FACX  # Second byte
            and B (hex "3F")  # 10xxxxxx
            or A (S)  # Combine
            shl A 6  # xxxxxxxxxx000000
            ld (S) A
         end
         call symByteCX_FACX  # Last byte
         and B (hex "3F")  # 10xxxxxx
         or (S) A  # Combine
         pop A  # Get result
      end
      ret
   end
   ld A TOP  # Return special "top" character
   gt
   ret

(code 'bufStringE_SZ 0)
   tos (Buf)  # Get return entry
   sub S 8  # 8-byte-buffer
   ld Z S  # in Z
   cmp E Nil  # Empty?
   if ne  # No
      ld (Buf I) X  # Save X
      ld X (E TAIL)
      call nameX_X  # Get name
      ld C 0
      do
         call symByteCX_FACX
      while nz
         ld (Z) B  # Store next byte
         inc Z
         test Z 7  # Buffer full?
         if z  # Yes
            cmp S (StkLimit)  # Stack check
            jlt stkErr
            sub S 8  # Extend buffer
            save (S 8) (Z) (S)
            sub Z 8  # Reset buffer pointer
         end
      loop
      ld X (Buf I)  # Restore
   end
   set (Z) 0  # Null byte
   add Z 8  # Round up
   off Z 7
   jmp (Buf)  # Return

(code 'pathStringE_SZ 0)
   tos (Buf)  # Get return entry
   sub S 8  # 8-byte-buffer
   ld Z S  # in Z
   cmp E Nil  # Empty?
   if ne  # No
      ld (Buf I) X  # Save X
      ld X (E TAIL)
      call nameX_X  # Get name
      ld C 0
      call symByteCX_FACX  # First byte
      if nz
         cmp B (char "+")  # Plus?
         if eq
            ld (Z) B  # Store "+"
            inc Z
            call symByteCX_FACX  # Second byte
            jz 90
         end
         cmp B (char "@")  # Home path?
         if ne  # No
            do
               ld (Z) B  # Store byte
               inc Z
               test Z 7  # Buffer full?
               if z  # Yes
                  sub S 8  # Extend buffer
                  save (S 8) (Z) (S)
                  sub Z 8  # Reset buffer pointer
               end
               call symByteCX_FACX  # Next byte?
            until z  # No
         else
            push E
            ld E (Home)  # Home directory?
            null E
            if nz  # Yes
               do
                  ld B (E)
                  ld (Z) B  # Store next byte
                  inc Z
                  test Z 7  # Buffer full?
                  if z  # Yes
                     sub S 8  # Extend buffer
                     save (S 8) (Z) (S)
                     sub Z 8  # Reset buffer pointer
                  end
                  inc E
                  nul (E)  # More?
               until z  # No
            end
            pop E
            do
               call symByteCX_FACX
            while nz
               ld (Z) B  # Store next byte
               inc Z
               test Z 7  # Buffer full?
               if z  # Yes
                  sub S 8  # Extend buffer
                  save (S 8) (Z) (S)
                  sub Z 8  # Reset buffer pointer
               end
            loop
         end
      end
90    ld X (Buf I)  # Restore
   end
   set (Z) 0  # Null byte
   add Z 8  # Round up
   off Z 7
   jmp (Buf)  # Return

# (path 'any) -> sym
(code 'doPath 2)
   push Z
   ld E ((E CDR))  # Get arg
   call evSymE_E  # Evaluate to a symbol
   call pathStringE_SZ  # Write to stack buffer
   ld E S  # Make transient symbol
   call mkStrE_E
   ld S Z  # Drop buffer
   pop Z
   ret

# Add next char to symbol name
(code 'charSymACX_CX 0)
   cmp A (hex "80")  # ASCII??
   jlt byteSymBCX_CX  # Yes: 0xxxxxxx
   cmp A (hex "800")  # Double-byte?
   if lt  # Yes
      push A  # 110xxxxx 10xxxxxx
      shr A 6  # Upper five bits
      and B (hex "1F")
      or B (hex "C0")
      call byteSymBCX_CX  # Add first byte
      pop A
      and B (hex "3F")  # Lower 6 bits
      or B (hex "80")
      jmp byteSymBCX_CX  # Add second byte
   end
   cmp A TOP  # Special "top" character?
   if eq  # Yes
      ld B (hex "FF")
      jmp byteSymBCX_CX
   end
   push A  # 1110xxxx 10xxxxxx 10xxxxxx
   shr A 12  # Hightest four bits
   and B (hex "0F")
   or B (hex "E0")
   call byteSymBCX_CX  # Add first byte
   ld A (S)
   shr A 6  # Middle six bits
   and B (hex "3F")
   or B (hex "80")
   call byteSymBCX_CX  # Add second byte
   pop A
   and B (hex "3F")  # Lowest 6 bits
   or B (hex "80")  # Add third byte

# Add next byte to symbol name
(code 'byteSymBCX_CX 0)
   zxt
   big X  # Long name?
   if z  # No: Direct buffer pointer
      # 0000.xxxxxxx.xxxxxxx.xxxxxxx.xxxxxxx.xxxxxxx.xxxxxxx.xxxxxxx0010
      #   60      52      44      36      28      20      12       4
      cmp C 60  # Short digit full?
      if ne  # No
         shl A C  # Shift byte to character position
         or (X) A  # Combine with name digit
         add C 8  # Increment position
         ret
      end
      ld C (X)  # Get short number
      shr C 4  # De-normalize
      shl A 56  # Combine byte with digit
      or C A
      call boxNum_A  # Box number
      ld (A DIG) C
      ld (X) A
      ld X A
      ld C 4  # Start new digit
      ret
   end
   cmp C 60  # Short digit full?
   if ne  # No
      shl A C  # Shift byte to character position
      or (X BIG) A  # Combine with name digit
      add C 8  # Increment position
      ret
   end
   ld C (X BIG)  # Get short number
   shr C 4  # De-normalize
   shl A 56  # Combine byte with digit
   or C A
   call boxNum_A  # Box number
   ld (A DIG) C
   ld (X BIG) A
   ld X A
   ld C 4  # Start new digit
   ret

(code 'rdOpenEX_S)  # Y, Z
   null (Signal)  # Signal?
   if nz  # Yes
      call sighandlerX
   end
   tos Z  # Get return entry
   cmp E Nil  # Standard input?
   if eq  # Yes
      push (Chr)  # <S III> Save 'next'
      push (Get_A)  # <S II> Save 'get'
      push 0  # <S I> No file
      push (EnvInFrames)  # Link
      ld (EnvInFrames) S  # Close input frame
      ld Y Z  # Move return entry to Y
      ld (InFile) 0  # Set to TTY
   else
      cmp S (StkLimit)  # Stack check
      jlt stkErr
      sym E  # Need symbol
      jz symErrEX
      ld Y (E TAIL)  # Get tail
      sym Y  # External symbol?
      jz extErrEX  # No
      call nameY_Y  # Get name
      call dbFileBlkY_AC  # Get file and block index
      cmp A (DBs)  # Local file?
      jge dbfErrX  # No
      add A DbFiles  # Get DB file
      sub S (A III)  # <S VIII> Buffer [Block size]
      push BLK  # <S VII> 'ix'
      push 8  # <S VI> 'cnt' (dummy for value read)
      push 0  # <S V> Block link
      push C  # <S IV> Block index
      push (Chr)  # <S III> Save 'next'
      push (Get_A)  # <S II> Save 'get'
      push A  # <S I> dbFile
      push (EnvInFrames)  # Link
      ld (EnvInFrames) S  # Close input frame
      ld Y Z  # Move return entry to Y
      shl C (A II)  # Shift block index for current file
      lea Z (S VIII)
      read (A) Z (A III) C  # Read first block
      call getAdrZ_A  # Get link address
      off A BLKTAG
      ld (S V) A  # Store as next block
      ld Z S  # Point Z to frame
      ld (GetBinZ_FB) getBinaryZ_FB  # Set binary read function
      ld (Extn) 0  # Set external symbol offset to zero
      call binReadZ_FE  # Read value (file size)
      jlt cntErrEX  # EOF
      cnt E  # Need short
      jz cntErrEX
      shr E 4  # Normalize
      ld (S VI) E  # Set 'cnt'
      ld (S VII) 16  # and 'ix'
      ld (InFile) S  # Set to input file
   end
   ld (Chr) 0  # Init Chr
   ld (Get_A) getStdin_A  # and set
   jmp (Y)  # Return

(code 'popInFrames)  # C
   ld C (EnvInFrames)  # Get InFrames
   ld (Get_A) (C II)  # Restore 'get'
   ld (Chr) (C III)  # and Chr
   ld C (C)  # Get link
   ld (EnvInFrames) C  # Restore input frame
   ld (InFile) 0  # Preset TTY
   null C  # Any?
   if nz  # Yes
      null (C I)  # New 'dbFile'?
      if nz
         ld (InFile) C  # Yes: Set InFile
      end
   end
   ret

(code 'rdCloseS)  # X
   tos X  # Get return entry
   call popInFrames
   add S I  # Drop link
   pop A  # Old 'dbFile'
   add S II  # Drop get, next
   null A  # TTY?
   jz (X)  # Yes: Return
   add S IV  # Drop blk, link, cnt, ix
   add S (A III)  # Drop buffer
   jmp (X)  # Return

(code 'wrOpenEX_S)  # Y, Z
   null (Signal)  # Signal?
   if nz  # Yes
      call sighandlerX
   end
   tos Z  # Get return entry
   cmp E Nil  # Standard output?
   if eq  # Yes
      push (PutB)  # <S II> Save 'put'
      push 0  # <S I> No file
      push (EnvOutFrames)  # Link
      ld (EnvOutFrames) S  # Close output frame
      ld Y Z  # Move return entry to Y
      ld (OutFile) 0  # Set to TTY
   else
      cmp S (StkLimit)  # Stack check
      jlt stkErr
      sym E  # Need symbol
      jz symErrEX
      ld Y (E TAIL)  # Get tail
      sym Y  # External symbol?
      jz extErrEX  # No
      call nameY_Y  # Get name
      shl Y 2  # Strip status bits
      shr Y 2  # Set "not loaded"
      or Y SYM  # Set 'extern' tag
      ld (E TAIL) Y  # Set status/name
      call dbFileBlkY_AC  # Get file and block index
      cmp A (DBs)  # Local file?
      jge dbfErrX  # No
      add A DbFiles  # Get DB file
      sub S (A III)  # <S VII> Buffer [Block size]
      push 16  # <S VII> 'ix'
      push 0  # <S VI> 'cnt'
      push 0  # <S V> Block link
      push C  # <S IV> Block index
      push C  # <S III> First block
      push (PutB)  # <S II> Save 'put'
      push A  # <S I> dbFile
      push (EnvOutFrames)  # Link
      ld (EnvOutFrames) S  # Close output frame
      ld Y Z  # Move return entry to Y
      shl C (A II)  # Shift block index for current file
      lea Z (S VIII)
      read (A) Z (A III) C  # Read first block
      call getAdrZ_A  # Get link address
      off A BLKTAG
      ld (S V) A  # Store as link
      ld (OutFile) S  # Set to output file
   end
   ld (PutB) putStdoutB  # Set 'put'
   jmp (Y)  # Return

(code 'flushX)  # C
   push Z
   push E
   ld E (X IV)  # Block index
   shl E ((X I) II)  # Shift for current file
   lea Z (X VIII)
   write ((X I)) Z ((X I) III) E  # Write last block
   ld E (X VI)  # Get 'cnt' (file size)
   shl E 4  # Make short number
   or E CNT
   ld (X VI) 0  # Reset 'cnt'
   ld (X VII) 0  # Start of buffer in 'ix'
   ld Z X  # Z on frame
   ld (Extn) 0  # Set external symbol offset to zero
   ld (PutBinBZ) putBinaryZB  # Set binary print function
   call binPrintEZ  # Print value (file size)
   ld B NIX  # No properties
   call putBinaryZB
   ld E (X III)  # Get first block
   shl E ((X I) II)  # Shift for current file
   add E BLK  # Skip link
   lea Z (X VIII)
   write ((X I)) Z (X VI) E  # Rewrite part of first block
   pop E
   pop Z
   ret

(code 'popOutFrames)  # C
   push X
   ld X (EnvOutFrames)  # Get OutFrames
   null (OutFile)  # Output file?
   if nz  # Yes
      call flushX  # Flush it
   end
   ld (PutB) (X II)  # Restore 'put'
   ld X (X)  # Get link
   ld (EnvOutFrames) X  # Restore output frame
   ld (OutFile) 0  # Preset TTY
   null X  # Any?
   if nz  # Yes
      null (X I)  # New 'dbFile'?
      if nz
         ld (OutFile) X  # Yes: Set InFile
      end
   end
   pop X
   ret

(code 'wrCloseS)  # X, Y
   tos X  # Get return entry
   ld Y E  # Save E
   call popOutFrames
   add S I  # Drop link
   pop A  # Old 'dbFile'
   add S I  # Drop put
   null A  # TTY?
   if nz  # No
      add S V  # Drop blk1, blk, link, cnt, ix
      add S (A III)  # Drop buffer
   end
   ld E Y  # Restore E
   jmp (X)  # Return

(code 'getStdin_A 0)
   push Z
   ld Z (InFile)  # Current InFile
   null Z  # Any?
   if nz  # Yes
      call getBinaryZ_FB  # Any byte?
      if ge  # Yes
         zxt  # Extend into A
      else
         ld A -1  # Return EOF
      end
   else
      push C
      push E
      push X
      atom (Led)  # Line editor?
      if nz  # No
         ld C 0  # Standard input
         ld E -1  # No timeout
         ld X 0  # Runtime expression
         call waitCEX_A  # Wait for events
         call stdinByte_A  # Get byte
      else
         ld C (LineC)
         null C  # First call?
         if ns  # No
            ld X (LineX)  # Get line status
         else
            ld E (Led)  # Run line editor
            call runE_E
            cmp E Nil  # NIL
            if eq  # Yes
               ld X ZERO  # Empty
            else
               ld X (E TAIL)
               call nameX_X  # Get name
            end
            ld C 0
         end
         call symByteCX_FACX  # Extract next byte
         if z  # None
            ld A 10  # Default to linefeed
            ld C -1
         end
         ld (LineX) X  # Save line status
         ld (LineC) C
      end
      pop X
      pop E
      pop C
   end
   ld (Chr) A
   pop Z
   ret

(code 'getParse_A 0)
   push C
   push X
   ld X (EnvParseX)  # Get parser status
   ld C (EnvParseC)
   call symByteCX_FACX  # Extract next byte
   if z  # Done
      ld A (EnvParseEOF)  # Get parser trail bytes
      shr A 8  # More bytes?
      ld (EnvParseEOF) A
      if nz  # Yes
         zxt  # Return next byte
      else
         dec A  # Return -1
      end
   end
   ld (Chr) A
   ld (EnvParseX) X  # Save status
   ld (EnvParseC) C
   pop X
   pop C
   ret

# Get full char from input channel
(code 'getChar_A 0)
   ld A (Chr)  # Get look ahead
: getCharA_A
   cmp B (hex "FF")  # Special "top" character?
   if ne  # No
      cmp B 128  # Single byte?
      if ge  # No
         test B (hex "20")  # Two bytes?
         if z  # Yes
            and B (hex "1F")  # First byte 110xxxxx
            shl A 6  # xxxxx000000
            push A
         else  # Three bytes
            and B (hex "F")  # First byte 1110xxxx
            shl A 6  # xxxx000000
            push A
            call (Get_A)  # Get second byte
            and B (hex "3F")  # 10xxxxxx
            or A (S)  # Combine
            shl A 6  # xxxxxxxxxx000000
            ld (S) A
         end
         call (Get_A)  # Get last byte
         and B (hex "3F")  # 10xxxxxx
         or (S) A  # Combine
         pop A  # Get result
      end
      ret
   end
   ld A TOP
   ret

# Skip White Space and Comments
(code 'skipC_A 0)
   ld A (Chr)
   null A  # EOF?
   if ns  # No
      do
         do
            cmp B 32  # White space?
         while le  # Yes
            call (Get_A)  # Get next
            null A  # EOF?
            js 90  # Yes
         loop
         cmp A C  # Comment char?
      while eq  # Yes
         call (Get_A)
         do
            cmp B 10  # Linefeed?
         while ne  #No
            null A  # EOF?
            js 90  # Yes
            call (Get_A)
         loop
      loop
   end
90 ret

(code 'comment_A 0)
   call (Get_A)
   cmp B (char "{")
   if ne  # No
      do
         cmp B 10  # Linefeed?
      while ne  #No
         null A  # EOF?
         js 90  # Yes
         call (Get_A)
      loop
   else  # Block comment
      do
         call (Get_A)
         null A  # EOF?
         js 90  # Yes
         cmp B (char "}")  # End of block comment?
         if eq
            call (Get_A)
            cmp B (char "#")
            break eq  # Yes
         end
      loop
      call (Get_A)
   end
90 ret

(code 'skip_A 0)
   ld A (Chr)
   do
      null A  # EOF?
   while ns  # No
      do
         cmp B 32  # White space?
      while le  # Yes
         call (Get_A)  # Get next
         null A  # EOF?
         js 90  # Yes
      loop
      cmp B (char "#")  # Comment char?
   while eq  # Yes
      call comment_A  # Skip comment
   loop
90 ret

(code 'testEscA_AF 0)  # E
   do
      null A  # EOF?
      if s  # Yes
         eq  # Return NO
         ret
      end
      cmp B (char "\^")  # Caret?
      if eq  # Yes
         call (Get_A)  # Skip '^'
         cmp B (char "@")  # At-mark?
         jeq badInputErr  # Yes
         cmp B (char "?")  # Question-mark?
         if eq  # Yes
            ld B 127  # DEL
         else
            and B 31  # Control-character
         end
         lt  # Return YES
         ret
      end
      cmp B (char "\\")  # Backslash?
      if ne  # No
         call getCharA_A  # Get full char
10       lt  # Return YES
         ret
      end
      call (Get_A)  # Skip '\'
      cmp B 10  # Newline?
      if nz  # No
         cmp B (char "n")  # Newline?
         if eq
            ld B (char "^J")  # Yes
            jmp 10
         end
         cmp B (char "r")  # Return?
         if eq
            ld B (char "^M")  # Yes
            jmp 10
         end
         cmp B (char "t")  # Tab?
         if eq
            ld B (char "^I")  # Yes
            jmp 10
         end
         cmp B (char "0")  # Decimal?
         if ge
            cmp B (char "9")
            if le  # Yes
               sub B (char "0")  # Convert
               ld E A  # Result in E
               push C
               do
                  call (Get_A)  # Next
                  cmp B (char "\\")  # Backslash?
               while ne  # No
                  cmp B (char "0")  # Decimal?
                  jlt badInputErr  # No
                  cmp B (char "9")
                  jgt badInputErr  # No
                  sub B (char "0")  # Convert
                  xchg A E  # Multiply result
                  mul 10  # with 10
                  add A E  # add digit
                  ld E A  # into result
               loop
               pop C
               ld A E  # Get result
            end
            lt
         end
         ret  # Return YES
      end
      do
         call (Get_A)  # Skip white space
         cmp B 32
         continue eq
         cmp B 9
      until ne
   loop

(code 'anonymousX_FE 0)
   ld C 0
   call symByteCX_FACX  # First byte
   cmp B (char "$")  # Starting with '$'?
   jne Ret  # No
   call symByteCX_FACX  # Second byte
   cmp B (char "1")  # >= '1'?
   if ge  # Yes
      cmp B (char "7")  # <= '7'?
      if le  # Yes
         sub B (char "0")  # Digit
         ld E A  # Calculate number
         call symByteCX_FACX  # Third byte
         do
            cmp B (char "0")  # >= '0'?
         while ge  # Yes
            cmp B (char "7")  # <= '7'?
         while le  # Yes
            shl E 3  # Times 8
            sub B (char "0")  # Digit
            add E A  # Add to result
            call symByteCX_FACX  # Next byte?
            if z  # No
               shl E 4  # Make symbol pointer
               or E SYM
               eq
               ret
            end
         loop
      end
   end
   ret

(code 'rdAtomBY_E)  # X
   link
   push (EnvIntern)  # <L II> Current symbol namespace
   push ZERO  # <L I> Result
   ld C 4  # Build name
   ld X S
   link
   call byteSymBCX_CX  # Pack first char
   ld A Y  # Get second
   do
      null A  # EOF?
   while ns  # No
      cmp B (char "~")  # Tilde?
      if eq  # Yes
         ld X (L I)  # Get name so far
         call findSymX_E  # Find or create symbol
         ld X 0  # Clear error context
         atom (E)  # Value must be a pair
         jnz symNsErrEX
         ld (Cell1) E
         ld (EnvIntern) Cell1  # Switch symbol namespace
         ld C 4  # Build new name
         lea X (L I)  # Safe
         ld (X) ZERO
      else
         memb Delim "(DelimEnd-Delim)"  # Delimiter?
         break eq   # Yes
         cmp B (char "\\")  # Backslash?
         if eq  # Yes
            call (Get_A)  # Get next char
         end
         call byteSymBCX_CX  # Pack char
      end
      call (Get_A)  # Get next
   loop
   ld X (L I)  # Get name
   ld A (Scl)  # Scale
   shr A 4  # Normalize
   ld (Sep3) 0  # Thousand separator
   ld (Sep0) (char ".")  # Decimal separator
   call symToNumXA_FE  # Legal number?
   if ge  # No
      ld X (L I)  # Get name
      call anonymousX_FE  # Anonymous symbol?
      if ne  # No
         ld X (L I)  # Get name
         call findSymX_E  # Find or create symbol
      end
   end
   ld (EnvIntern) (L II)  # Restore current symbol namespace
   drop
   ret

(code 'rdList_E)
   cmp S (StkLimit)  # Stack check
   jlt stkErr
   call (Get_A)  # Skip paren
   do
      call skip_A  # and white space
      cmp B (char ")")  # Empty list?
      if eq  # Yes
         call (Get_A)  # Skip paren
         ld E Nil  # Return NIL
         ret
      end
      cmp B (char "]")  # Empty list?
      jz retNil  # Yes
      cmp B (char "~")  # Tilde?
      if ne  # No
         ld A 0
         call readA_E  # Read expression
         call consE_A  # Make a pair
         ld (A) E
         ld (A CDR) Nil
         link
         push A  # <L I> Save it
         link
         ld E A  # Keep last cell in E
         jmp 10  # Exit
      end
      call (Get_A)  # Skip tilde
      ld A 0
      call readA_E  # Read expression
      link
      push E  # <L I> Save it
      link
      eval  # Evaluate
      ld (L I) E  # Save again
      atom E  # Pair?
      if z  # Yes
         do
            atom (E CDR)  # Find last cell
         while z
            ld E (E CDR)
         loop
         jmp 10  # Exit
      end
      drop  # Continue
   loop
10 do
      call skip_A  # Skip white space
      cmp B (char ")")  # Done?
      if eq  # Yes
         call (Get_A)  # Skip paren
         jmp 90  # Done
      end
      cmp B (char "]")  # Done?
      jz 90  # Yes
      cmp B (char ".")  # Dotted pair?
      if eq  # Yes
         call (Get_A)  # Skip dot
         memb Delim "(DelimEnd-Delim)"  # Delimiter?
         if eq  # Yes
            call skip_A  # and white space
            cmp B (char ")")  # Circular list?
            jz 20  # Yes
            cmp B (char "]")
            if eq  # Yes
20             ld (E CDR) (L I)  # Store list in CDR
            else
               push E
               ld A 0
               call readA_E  # Read expression
               ld A E
               pop E
               ld (E CDR) A  # Store in CDR
            end
            call skip_A  # Skip white space
            cmp B (char ")")  # Done?
            if eq  # Yes
               call (Get_A)  # Skip paren
               jmp 90  # Done
            end
            cmp B (char "]")
            jz 90  # Done
            ld E (L I)  # Else bad dottet pair
            jmp badDotErrE
         end
         push X
         push Y
         push E
         ld Y A  # Save first char
         ld B (char ".")  # Restore dot
         call rdAtomBY_E  # Read atom
         call consE_A  # Make a pair
         ld (A) E
         ld (A CDR) Nil
         pop E
         ld (E CDR) A  # Store in last cell
         ld E A
         pop Y
         pop X
      else
         cmp B (char "~")  # Tilde?
         if ne  # No
            push E
            ld A 0
            call readA_E  # Read expression
            call consE_A  # Make a pair
            ld (A) E
            ld (A CDR) Nil
            pop E
            ld (E CDR) A  # Store in last cell
            ld E A
         else
            call (Get_A)  # Skip tilde
            push E
            ld A 0
            call readA_E  # Read expression
            ld A (S)
            ld (A CDR) E  # Save in last cell
            eval  # Evaluate
            pop A
            ld (A CDR) E  # Store in last cell
            ld E A
            do
               atom (E CDR)  # Pair?
            while z  # Yes
               ld E (E CDR)  # Find last cell
            loop
         end
      end
   loop
90 ld E (L I)  # Return list
   drop
   ret

(code 'readC_E)
   null (Chr)  # Empty channel?
   if z  # Yes
      call (Get_A)  # Fill 'Chr'
   end
   cmp C (Chr)  # Terminator?
   if eq  # Yes
      ld E Nil  # Return 'NIL'
      ret
   end
   ld A 1  # Read top level expression

(code 'readA_E)
   push X
   push Y
   push A  # <S> Top flag
   call skip_A
   null A  # EOF?
   if s  # Yes
      null (S)  # Top?
      jz eofErr  # No: Error
      ld E Nil  # Yes: Return NIL
      jmp 99
   end
   cmp B (char "(")  # Opening a list?
   if eq  # Yes
      call rdList_E  # Read it
      null (S)  # Top?
      if nz  # Yes
         cmp (Chr) (char "]")  # And super-parentheses?
         if eq  # Yes
            call (Get_A)  # Skip ']'
         end
      end
      jmp 99  # Return list
   end
   cmp B (char "[")  # Opening super-list?
   if eq  # Yes
      call rdList_E  # Read it
      cmp (Chr) (char "]")  # Matching super-parentheses?
      jnz suparErrE  # Yes: Error
      call (Get_A)  # Else skip ']'
      jmp 99
   end
   cmp B (char "'")  # Quote?
   if eq  # Yes
      call (Get_A)  # Skip "'"
      ld A (S)
      call readA_E  # Read expression
      ld C E
      call consC_E  # Cons with 'quote'
      ld (E) Quote
      ld (E CDR) C
      jmp 99
   end
   cmp B (char ",")  # Comma?
   if eq  # Yes
      call (Get_A)  # Skip ','
      ld A (S)
      call readA_E  # Read expression
      ld X Uni  # Maintain '*Uni' index
      cmp (X) TSym  # Disabled?
      jeq 99  # Yes
      link
      push E  # Else save expression
      link
      ld Y E
      call idxPutXY_E
      atom E  # Pair?
      if z  # Yes
         ld E (E)  # Return index entry
      else
         ld E Y  # 'read' value
      end
      drop
      jmp 99
   end
   cmp B (char "`")  # Backquote?
   if eq  # Yes
      call (Get_A)  # Skip '`'
      ld A (S)
      call readA_E  # Read expression
      link
      push E  # Save it
      link
      eval  # Evaluate
      drop
      jmp 99
   end
   cmp B (char "\"")  # String?
   if eq  # Yes
      call (Get_A)  # Skip '"'
      cmp B (char "\"")  # Empty string?
      if eq  # Yes
         call (Get_A)  # Skip '"'
         ld E Nil  # Return NIL
         jmp 99
      end
      call testEscA_AF
      jge eofErr
      link
      push ZERO  # <L I> Result
      ld C 4  # Build name
      ld X S
      link
      do
         call charSymACX_CX  # Pack char
         call (Get_A)  # Get next
         cmp B (char "\"")  # Done?
      while ne
         call testEscA_AF
         jge eofErr
      loop
      call (Get_A)  # Skip '"'
      ld X (L I)  # Get name
      push Z
      ld E 0  # No symbol yet
      ld Y Transient
      ld Z Nil  # No more namespaces
      call internEXYZ_FE  # Check transient symbol
      pop Z
      drop
      jmp 99
   end
   cmp B (char "{")  # External symbol?
   if eq  # Yes
      call (Get_A)  # Skip '{'
      cmp B (char "}")  # Empty?
      if eq  # Yes
         call (Get_A)  # Skip '}'
         call cons_E  # New symbol
         ld (E) ZERO  # anonymous
         or E SYM
         ld (E) Nil  # Set to NIL
         jmp 99
      end
      ld E 0  # Init file number
      do
         cmp B (char "@")  # File done?
      while ge  # No
         cmp B (char "O")  # In A-O range?
         jgt badInputErr  # Yes
         sub B (char "@")
         shl E 4  # Add to file number
         add E A
         call (Get_A)  # Get next char
      loop
      cmp B (char "0")  # Octal digit?
      jlt badInputErr
      cmp B (char "7")
      jgt badInputErr  # No
      sub B (char "0")
      zxt
      ld C A  # Init object ID
      do
         call (Get_A)  # Get next char
         cmp B (char "}")  # Done?
      while ne  # No
         cmp B (char "0")  # Octal digit?
         jlt badInputErr
         cmp B (char "7")
         jgt badInputErr  # No
         sub B (char "0")
         shl C 3  # Add to object ID
         add C A
      loop
      call (Get_A)  # Skip '}'
      call extNmCE_X  # Build external symbol name
      call externX_E  # New external symbol
      jmp 99
   end
   cmp B (char ")")  # Closing paren?
   jeq badInputErr  # Yes
   cmp B (char "]")
   jeq badInputErr
   cmp B (char "~")  # Tilde?
   jeq badInputErr  # Yes
   cmp B (char "\\")  # Backslash?
   if eq  # Yes
      call (Get_A)  # Get next char
   end
   ld Y A  # Save in Y
   call (Get_A)  # Next char
   xchg A Y  # Get first char
   call rdAtomBY_E  # Read atom
99 pop A
   pop Y
   pop X
   ret

(code 'tokenCE_E)  # X
   null (Chr)  # Look ahead char?
   if z  # No
      call (Get_A)  # Get next
   end
   call skipC_A  # Skip white space and comments
   null A  # EOF?
   js retNull  # Yes
   cmp B (char "\"")  # String?
   if eq  # Yes
      call (Get_A)  # Skip '"'
      cmp B (char "\"")  # Empty string?
      if eq  # Yes
         call (Get_A)  # Skip '"'
         ld E Nil  # Return NIL
         ret
      end
      call testEscA_AF  # Get next character
      jge retNil
      call mkCharA_A  # Make single character
      call consA_X  # Cons it
      ld (X) A
      ld (X CDR) Nil  # with NIL
      link
      push X  # <L I> Result
      link
      do
         call (Get_A)  # Get next
         cmp B (char "\"")  # Done?
         if eq  # Yes
            call (Get_A)  # Skip '"'
            break T
         end
         call testEscA_AF  # Get next character
      while lt
         call mkCharA_A  # Make char
         call consA_C  # Cons it
         ld (C) A
         ld (C CDR) Nil  # with NIL
         ld (X CDR) C  # Append to result
         ld X C
      loop
      ld E (L I)  # Get result
      drop
      ret
   end
   cmp B (char "0")  # Digit?
   if ge
      cmp B (char "9")
      if le  # Yes
         link
         push ZERO  # <L I> Result
         ld C 4  # Build digit string
         ld X S
         link
         do
            call byteSymBCX_CX  # Pack char
            call (Get_A)  # Get next
            cmp B (char ".")  # Dot?
            continue eq  # Yes
            cmp B (char "0")  # Or digit?
         while ge
            cmp B (char "9")
         until gt  # No
         ld X (L I)  # Get name
         ld A (Scl)  # Scale
         shr A 4  # Normalize
         drop
         ld (Sep3) 0  # Thousand separator
         ld (Sep0) (char ".")  # Decimal separator
         jmp symToNumXA_FE  # Convert to number
      end
   end
   push Y
   push Z
   ld Y A  # Keep char in Y
   call bufStringE_SZ  # <S I/IV> Stack buffer
   push A  # <S /III> String length
   slen (S) (S I)
   ld A Y  # Restore char
   cmp B (char "+")  # Sign?
   jeq 90
   cmp B (char "-")
   jeq 90  # Yes
   cmp B (char "a")  # Lower case letter?
   if ge
      cmp B (char "z")
      jle 10  # Yes
   end
   cmp B (char "A")  # Upper case letter?
   if ge
      cmp B (char "Z")
      jle 10  # Yes
   end
   cmp B (char "\\")  # Backslash?
   if eq  # Yes
      call (Get_A)  # Use next char
      jmp 10
   end
   memb (S I) (S)  # Member of character set?
   if eq  # Yes
10    link
      push ZERO  # <L I> Result
      ld C 4  # Build name
      ld X S
      link
      do
         call byteSymBCX_CX  # Pack char
         call (Get_A)  # Get next
         cmp B (char "a")  # Lower case letter?
         if ge
            cmp B (char "z")
            continue le  # Yes
         end
         cmp B (char "A")  # Upper case letter?
         if ge
            cmp B (char "Z")
            continue le  # Yes
         end
         cmp B (char "0")  # Digit?
         if ge
            cmp B (char "9")
            continue le  # Yes
         end
         cmp B (char "\\")  # Backslash?
         if eq  # Yes
            call (Get_A)  # Use next char
            continue T
         end
         memb (S IV) (S III)  # Member of character set?
      until ne  # No
      ld X (L I)  # Get name
      call findSymX_E  # Find or create symbol
      drop
   else
90    call getChar_A
      call mkCharA_A  # Return char
      ld E A
      call (Get_A)  # Skip it
   end
   ld S Z  # Drop buffer
   pop Z
   pop Y
   ret

# (read ['sym1 ['sym2]]) -> any
(code 'doRead 2)
   atom (E CDR)  # Arg?
   if nz  # No
      ld C 0  # No terminator
      call readC_E  # Read item
   else
      push X
      push Y
      ld X E
      ld Y (E CDR)  # Args
      ld E (Y)  # Eval 'sym1'
      eval
      sym E  # Need symbol
      jz symErrEX
      link
      push E  # <L I> Safe
      link
      ld E ((Y CDR))  # Eval 'sym2'
      eval
      sym E  # Need symbol
      jz symErrEX
      call firstCharE_A  # Get first character
      ld C A  # as comment char
      ld E (L I)  # Get Set of characters
      call tokenCE_E  # Read token
      null E  # Any?
      ldz E Nil  # No
      drop
      pop Y
      pop X
   end
   cmp (Chr) 10  # Hit linefeed?
   if eq  # Yes
      null (InFile)  # Stdin?
      if z  # Yes
         ld (Chr) 0  # Clear it
      end
   end
   ret

(code 'waitCEX_A)
   push Y
   push Z
   push (EnvTask)  # <L IV> Save task list
   link
   push (At)  # <L II> '@'
   push ZERO  # <L I> '*Run'
   link
   push C  # <L -I> Interrupt argument
   push E  # <L -II> Milliseconds
   push E  # <L -III> Timeout
   push 0  # <S> Interrupt mask
   cmp S (StkLimit)  # Stack check
   jlt stkErrX
   do
      ld C (L -I)  # Interrupt argument
      null C  # Positive?
      if ns  # Yes
         ld A 1  # Calculate mask bit
         shl A C
         or (S) A
      end
      ld Y (Run)  # Get '*Run'
      ld (L I) Y  # Save it
      ld (EnvTask) Y
      do
         atom Y  # '*Run' elements?
      while z  # Yes
         ld E (Y)  # Next element
         ld A (L IV)  # memq in saved tasklist?
         do
            atom A  # End of tasklist?
         while z  # No
            cmp E (A)  # Member?
            jeq 10  # Yes: Skip
            ld A (A CDR)
         loop
         ld C (E)  # Get fd or timeout value
         shr C 4  # Negative?
         if x  # Yes
            ld A ((E CDR))  # Get CADR
            shr A 4  # Normalize
            cmp A (L -III)  # Less than current timeout?
            if lt  # Yes
               ld (L -III) A  # Set new timeout
            end
         else
            cmp C (L -I)  # Different from argument-fd?
            if ne  # Yes
               ld A 1  # Calculate mask bit
               shl A C
               or (S) A
            end
         end
10       ld Y (Y CDR)
      loop
      ld A (S)  # Get interrupt mask
      ld C (L -III)  # and timeout
      do
         wait  # Wait for interrupts
      while lt  # Signal?
         call sighandlerX  # Yes
      loop
      sub (L -III) C  # Save milliseconds not slept
      ld (S) A  # Save interrupt mask
      ld Y (L I)  # Get '*Run'
      do
         atom Y  # More elements?
      while z  # Yes
         ld E (Y)  # Next element
         ld A (L IV)  # memq in saved tasklist?
         do
            atom A  # End of tasklist?
         while z  # No
            cmp E (A)  # Member?
            jeq 20  # Yes: Skip
            ld A (A CDR)
         loop
         ld C (E)  # Get fd or timeout value
         shr C 4  # Negative?
         if x  # Yes
            ld C (E CDR)  # Get CDR
            ld A (C)  # and CADR
            shr A 4  # Normalize
            sub A (L -III)  # Subtract time difference
            if gt  # Not yet timed out
               shl A 4  # Make short number
               or A CNT
               ld (C) A  # Store in '*Run'
            else  # Timed out
               ld A (E)  # Timeout value
               ld (C) A  # Store in '*Run'
               ld (At) (E)  # Set to CAR
               ld Z (C CDR)  # Run body
               prog Z
            end
         else
            cmp C (L -I)  # Different from argument-fd?
            if ne  # Yes
               ld A (S)  # Get mask bit
               shr A C  # Ready?
               shr A 1
               if x  # Yes
                  ld (At) (E)  # Set to fd
                  ld Z (E CDR)  # Run body
                  prog Z
               end
            end
         end
20       ld Y (Y CDR)
      loop
      null (Signal)  # Signal?
      if nz  # Yes
         call sighandlerX
      end
      ld A (L -II)  # Milliseconds
      null A
      if nsz  # Greater zero
         sub A (L -III)  # Subtract time difference
         if s  # < 0
            xor A A  # Set to zero, 'z'
         end
         ld (L -II) A
      end
   while nz  # Milliseconds non-zero
      ld (L -III) A  # Set timeout
      ld C (L -I)  # Interrupt argument
      null C  # Positive?
   while ns  # Yes
      ld A (S)  # Get mask bit
      shr A C  # Ready?
      shr A 1
   until x  # Yes
   ld (At) (L II)  # Restore '@'
   ld A (L -II)  # Return milliseconds
   drop
   pop (EnvTask)
   pop Z
   pop Y
   ret

# (wait 'cnt|NIL . prg) -> any
(code 'doWait 2)
   push X
   push Y
   push Z
   ld X E
   ld Y (E CDR)  # Y on args
   ld E (Y)  # Eval 'cnt'
   eval
   cmp E Nil  # None?
   if eq  # Yes
      push -1  # Wait infinite
   else
      call xCntEX_FE  # Get 'cnt'
      push E  # <S> Milliseconds
   end
   ld Y (Y CDR)  # Y on 'prg'
   do
      ld Z Y  # Run 'prg'
      prog Z
      cmp E Nil  # NIL?
   while eq  # Yes
      ld C -1  # No file descriptor
      ld E (S)  # Milliseconds
      call waitCEX_A  # Wait for events
      null A  # Timeout?
      if z  # Yes
         prog Y  # Run 'prg'
         break T
      end
      ld (S) A  # New milliseconds
   loop
   add S I  # Drop milliseconds
   pop Z
   pop Y
   pop X
   ret

# (key ['cnt]) -> sym
(code 'doKey 2)
   push X
   ld X E
   ld E ((E CDR))  # E on arg
   eval  # Eval it
   cmp E Nil  # None?
   if eq  # Yes
      ld E -1  # Wait infinite
   else
      call xCntEX_FE  # Get milliseconds
   end
   set (Raw) 1  # Set raw mode
   ld C 0  # Standard input
   call waitCEX_A  # Wait for events
   null A  # Timeout?
   if nz  # No
      call stdinByte_A  # Read first byte
      cmp B (hex "FF")  # Special "top" character?
      if ne  # No
         cmp B 128  # Single byte?
         if ge  # No
            test B (hex "20")  # Two bytes?
            if z  # Yes
               and B (hex "1F")  # First byte 110xxxxx
               shl A 6  # xxxxx000000
               push A
            else  # Three bytes
               and B (hex "F")  # First byte 1110xxxx
               shl A 6  # xxxx000000
               push A
               call stdinByte_A  # Read second byte
               and B (hex "3F")  # 10xxxxxx
               or A (S)  # Combine
               shl A 6  # xxxxxxxxxx000000
               ld (S) A
            end
            call stdinByte_A  # Read last byte
            and B (hex "3F")  # 10xxxxxx
            or (S) A  # Combine
            pop A  # Get result
         end
      else
         ld A TOP
      end
      call mkCharA_A  # Return char
      ld E A
      pop X
      ret
   end
   ld E Nil
   pop X
   ret

# (peek) -> sym
(code 'doPeek 2)
   ld A (Chr)  # Look ahead char?
   null A
   if z  # No
      call (Get_A)  # Get next
   end
   null A  # EOF?
   js retNil  # Yes
   call mkCharA_A  # Return char
   ld E A
   ret

# (char) -> sym
# (char 'cnt) -> sym
# (char T) -> sym
# (char 'sym) -> cnt
(code 'doChar 2)
   push X
   ld X E
   ld E (E CDR)  # Any args?
   atom E
   if nz  # No
      ld A (Chr)  # Look ahead char?
      null A
      if z  # No
         call (Get_A)  # Get next
      end
      null A  # EOF?
      if ns  # No
         call getCharA_A
         call mkCharA_A  # Make char
         ld E A
         call (Get_A)  # Get next
      else
         ld E Nil
      end
      pop X
      ret
   end
   ld E (E)
   eval  # Eval arg
   cnt E  # 'cnt'?
   if nz  # Yes
      ld A E  # Get 'cnt'
      shr A 4  # Normalize
      if nz
         call mkCharA_A  # Make char
         ld E A
      else
         ld E Nil
      end
      pop X
      ret
   end
   sym E  # 'sym'?
   jz atomErrEX  # No
   cmp E TSym  # T?
   if ne
      call firstCharE_A
      shl A 4  # Make short number
      or A CNT
   else
      ld A TOP  # Special "top" character
      call mkCharA_A
   end
   ld E A
   pop X
   ret

# (skip ['any]) -> sym
(code 'doSkip 2)
   ld E ((E CDR))  # Get arg
   call evSymE_E  # Evaluate to a symbol
   call firstCharE_A  # Get first character
   ld C A  # Use as comment char
   call skipC_A  # Skip white space and comments
   null A  # EOF?
   js retNil  # Yes
   ld A (Chr)  # Return 'Chr'
   call mkCharA_A  # Return char
   ld E A
   ret

# (eol) -> flg
(code 'doEol 2)
   cmp (Chr) 10  # Linefeed?
   jeq retT  # Yes
   null (Chr)  # Chr <= 0?
   jsz retT  # Yes
   ld E Nil  # Return NIL
   ret

# (eof ['flg]) -> flg
(code 'doEof 2)
   ld E ((E CDR))  # Get arg
   eval  # Eval it
   cmp E Nil  # NIL?
   if eq  # Yes
      ld A (Chr)  # Look ahead char?
      null A
      if z  # No
         call (Get_A)  # Get next
      end
      null A  # EOF?
      jns RetNil  # No
   else
      ld (Chr) -1  # Set EOF
   end
   ld E TSym  # Return T
   ret

# (from 'any ..) -> sym
(code 'doFrom 2)
   push X
   push Z
   ld X (E CDR)  # X on args
   push 0  # End-of-buffers marker
   do
      call evSymX_E  # Next argument
      call bufStringE_SZ  # <S V> Stack buffer
      push 0  # <S IV> Index
      link
      push E  # <S II> Symbol
      link
      push Z  # <S> Buffer chain
      ld X (X CDR)  # More arguments?
      atom X
   until nz  # No
   ld A (Chr)  # Look ahead char?
   null A
   if z  # No
      call (Get_A)  # Get next
   end
   do
      null A  # EOF?
   while ns  # No
      ld Z S  # Buffer chain
      do
         do
            lea C (Z V)  # Stack buffer
            add C (Z IV)  # Index
            cmp B (C)  # Bytes match?
            if eq  # Yes
               inc (Z IV)  # Increment index
               nul (C 1)  # End of string?
               break nz  # No
               call (Get_A)  # Skip next input byte
               ld E (Z II)  # Return matched symbol
               jmp 90
            end
            null (Z IV)  # Still at beginning of string?
            break z  # Yes
            lea C (Z (+ V 1))  # Offset pointer to second byte
            do
               dec (Z IV)  # Decrement index
            while nz
               cmpn (Z V) (C) (Z IV)  # Compare stack buffer
            while nz
               inc C  # Increment offset
            loop
         loop
         ld Z (Z)  # Next in chain
         null (Z)  # Any?
      until z  # No
      call (Get_A)  # Get next input byte
   loop
   ld E Nil  # Return NIL
90 pop Z  # Clean up buffers
   do
      drop
      ld S Z
      pop Z
      null Z  # End?
   until z  # Yes
   pop Z
   pop X
   ret

# (till 'any ['flg]) -> lst|sym
(code 'doTill 2)
   push X
   push Z
   ld X (E CDR)  # Args
   call evSymX_E  # Evaluate to a symbol
   call bufStringE_SZ  # <S I/IV> Stack buffer
   push A  # <S /III> String length
   slen (S) (S I)
   ld A (Chr)  # Look ahead char?
   null A
   if z  # No
      call (Get_A)  # Get next
   end
   null A  # EOF?
   if ns  # No
      memb (S I) (S)  # Matched first char?
      if ne  # No
         ld E ((X CDR))  # Eval 'flg'
         eval
         cmp E Nil  # NIL?
         if eq  # Yes
            call getChar_A  # Get first character
            call mkCharA_A  # Make char
            call consA_X  # Build first cell
            ld (X) A
            ld (X CDR) Nil
            link
            push X  # <L I> Result list
            link
            do
               call (Get_A)  # Get next
               null A  # EOF?
            while nsz  # No
               memb (S IV) (S III)  # Matched char?
            while ne  # No
               call getChar_A  # Get next character
               call mkCharA_A
               call consA_C  # Build next cell
               ld (C) A
               ld (C CDR) Nil
               ld (X CDR) C  # Append to sublist
               ld X C
            loop
            ld E (L I)  # Get result list
         else
            link
            push ZERO  # <L I> Result
            ld C 4  # Build name
            ld X S
            link
            do
               call getChar_A  # Get next character
               call charSymACX_CX  # Insert
               call (Get_A)  # Get next
               null A  # EOF?
            while nsz  # No
               memb (S IV) (S III)  # Matched char?
            until eq  # Yes
            ld X (L I)  # Get result name
            call consSymX_E
         end
         drop
         ld S Z  # Drop buffer
         pop Z
         pop X
         ret
      end
   end
   ld E Nil  # Return NIL
   ld S Z  # Drop buffer
   pop Z
   pop X
   ret

(code 'eolA_F 0)
   null A  # EOF?
   js retEq  # Yes
   cmp A 10  # Linefeed?
   if ne  # No
      cmp A 13  # Return?
      jne Ret  # No
      call (Get_A)  # Get next
      cmp A 10  # Linefeed?
      jnz retEq
   end
   ld (Chr) 0  # Clear look ahead
   ret  # 'z'

# (line 'flg ['cnt ..]) -> lst|sym
(code 'doLine 2)
   ld A (Chr)  # Look ahead char?
   null A
   if z  # No
      call (Get_A)  # Get next
   end
   call eolA_F  # End of line?
   jeq retNil  # Yes
   push X
   push Y
   push Z
   ld Y (E CDR)  # Y on args
   ld E (Y)  # Eval 'flg'
   eval
   cmp E Nil  # 'flg' was non-NIL?
   if ne  # Yes: Pack
      ld Y (Y CDR)  # More args?
      atom Y
      if nz  # No
         link
         push ZERO  # <L I> Result
         ld C 4  # Build name
         ld X S
         link
         do
            call getChar_A  # Get next character
            call charSymACX_CX  # Insert
            call (Get_A)  # Get next
            call eolA_F  # End of line?
         until eq  # Yes
         ld X (L I)  # Get result name
         call consSymX_E
      else
         call cons_Z  # First cell of top list
         ld (Z) ZERO
         ld (Z CDR) Nil
         link
         push Z  # <L I> Result
         link
         do
            ld C 4  # Build name
            ld X Z
            call getChar_A  # Get next character
            call charSymACX_CX  # Insert first char
            push C
            ld E (Y)
            eval  # Eval next arg
            pop C
            shr E 4  # Normalize
            do
               dec E  # Decrement count
            while nz
               call (Get_A)  # Get next
               call eolA_F  # End of line?
               if eq  # Yes
                  ld X (Z)  # Get last sub-result
                  call consSymX_E
                  ld (Z) E
                  jmp 20
               end
               call getChar_A  # Get next character
               call charSymACX_CX  # Insert
            loop
            ld X (Z)  # Get last sub-result
            call consSymX_E
            ld (Z) E
            ld Y (Y CDR)  # More args?
            atom Y
            jnz 10  # No
            call (Get_A)  # Get next
            call eolA_F  # End of line?
            jeq 20  # Yes
            call cons_A  # New cell to top list
            ld (A) ZERO
            ld (A CDR) Nil
            ld (Z CDR) A
            ld Z A
         loop
      end
   else
      call getChar_A  # Get first character
      call mkCharA_A  # Make char
      call consA_Z  # Build first cell
      ld (Z) A
      ld (Z CDR) Nil
      link
      push Z  # <L I> Result
      link
      ld Y (Y CDR)  # More args?
      atom Y
      if z  # Yes
         ld X Z  # Current sublist
         call cons_Z  # First cell of top list
         ld (Z) X
         ld (Z CDR) Nil
         ld (L I) Z  # New result
         do
            ld E (Y)
            eval  # Eval next arg
            shr E 4  # Normalize
            do
               dec E  # Decrement count
            while nz
               call (Get_A)  # Get next
               call eolA_F  # End of line?
               jeq 20  # Yes
               call getCharA_A  # Get next character
               call mkCharA_A
               call consA_C  # Build next cell
               ld (C) A
               ld (C CDR) Nil
               ld (X CDR) C  # Append to sublist
               ld X C
            loop
            ld Y (Y CDR)  # More args?
            atom Y
         while z  # Yes
            call (Get_A)  # Get next
            call eolA_F  # End of line?
            jeq 20  # Yes
            call getCharA_A  # Get next character
            call mkCharA_A
            call consA_X  # Build new sublist
            ld (X) A
            ld (X CDR) Nil
            call consX_A  # Append to top list
            ld (A) X
            ld (A CDR) Nil
            ld (Z CDR) A
            ld Z A
         loop
      end
10    do
         call (Get_A)  # Get next
         call eolA_F  # End of line?
      while ne  # No
         call getCharA_A  # Get next character
         call mkCharA_A
         call consA_C  # Build next cell
         ld (C) A
         ld (C CDR) Nil
         ld (Z CDR) C  # Append
         ld Z C
      loop
20    ld E (L I)  # Get result
   end
   drop
   pop Z
   pop Y
   pop X
   ret

(code 'parseBCE_E)
   push (EnvParseX)  # Save old parser status
   push (EnvParseC)
   push (EnvParseEOF)
   push (Get_A)  # Save 'get' status
   push (Chr)
   ld E (E TAIL)
   call nameE_E  # Get name
   link
   push E  # Save it
   link
   ld (EnvParseX) E  # Set new parser status
   ld (EnvParseC) 0
   ld E 0
   null C  # Token?
   if z  # No
      ld E (hex "5D0A00")  # linefeed, ']', EOF
   end
   ld (EnvParseEOF) E
   ld (Get_A) getParse_A  # Set 'get' status
   ld (Chr) 0
   nul B  # Skip?
   if nz  # Yes
      call getParse_A  # Skip first char
   end
   null C  # Token?
   if z  # No
      call rdList_E  # Read a list
   else
      push X
      push C  # <S III> Set of characters
      ld E C  # in E
      ld C 0  # No comment char
      call tokenCE_E  # Read token
      null E  # Any?
      ldz E Nil
      if nz  # Yes
         call consE_X  # Build first result cell
         ld (X) E
         ld (X CDR) Nil
         link
         push X  # <L I> Result
         link
         do
            ld C 0  # No comment char
            ld E (S III)  # Get set of characters
            push X
            call tokenCE_E  # Next token?
            pop X
            null E
         while nz  # Yes
            call consE_A  # Build next result cell
            ld (A) E
            ld (A CDR) Nil
            ld (X CDR) A
            ld X A
         loop
         ld E (L I)  # Get result
         drop
      end
      add S I  # Drop set
      pop X
   end
   drop
   pop (Chr)  # Retrieve 'get' status
   pop (Get_A)
   pop (EnvParseEOF)  # Restore old parser status
   pop (EnvParseC)
   pop (EnvParseX)
   ret

# (any 'sym) -> any
(code 'doAny 2)
   push X
   ld X E
   ld E ((E CDR))  # E on arg
   eval  # Eval it
   num E  # Need symbol
   jnz symErrEX
   sym E
   jz symErrEX
   cmp E Nil  # NIL?
   if ne  # No
      push (EnvParseX)  # Save old parser status
      push (EnvParseC)
      push (EnvParseEOF)
      push (Get_A)  # Save 'get' status
      push (Chr)
      ld E (E TAIL)
      call nameE_E  # Get name
      link
      push E  # Save it
      link
      ld (EnvParseX) E  # Set new parser status
      ld (EnvParseC) 0
      ld (EnvParseEOF) (hex "2000")  # Blank, EOF
      ld (Get_A) getParse_A  # Set 'get' status
      ld (Chr) 0
      call getParse_A  # Skip first char
      ld A 1  # Top level
      call readA_E  # Read expression
      drop
      pop (Chr)  # Retrieve 'get' status
      pop (Get_A)
      pop (EnvParseEOF)  # Restore old parser status
      pop (EnvParseC)
      pop (EnvParseX)
   end
   pop X
   ret

# (sym 'any) -> sym
(code 'doSym 2)
   ld E ((E CDR))  # Eval arg
   eval
   link
   push E  # Save
   link
   call begString_S  # Start string
   call printE  # Print to string
   call endStringS_E  # Retrieve result
   drop
   ret

# (str 'sym ['sym1]) -> lst
# (str 'lst) -> sym
(code 'doStr 2)
   push X
   push Y
   ld X E
   ld Y (E CDR)  # Y on args
   ld E (Y)  # Eval first
   eval
   cmp E Nil  # NIL?
   if ne  # No
      num E  # Number?
      jnz argErrEX  # Yes
      sym E  # Symbol?
      if nz  # Yes
         link
         push E  # <L II> 'sym'
         link
         ld X (Y CDR)  # Second arg?
         atom X
         if nz  # No
            ld C 0  # No token
         else
            call evSymX_E  # Eval 'sym1'
            tuck E  # Save
            link
            ld C E  # Get token
            ld E (L II)  # and 'sym'
         end
         ld B 0  # Don't skip
         call parseBCE_E  # Parse
         drop
      else
         link
         push E  # Save 'lst'
         link
         call begString_S  # Start string
         ld X E  # 'lst'
         do
            ld E (X)  # Get CAR
            call printE  # Print to string
            ld X (X CDR)  # More items?
            atom X
         while z  # Yes
            call space
         loop
         call endStringS_E  # Retrieve result
         drop
      end
   end
   pop Y
   pop X
   ret

# Read-Eval-Print loop
(code 'loadBEX_E)
   ld C A  # Save prompt in C
   sym E  # Symbolic argument?
   if nz  # Yes
      ld A (E TAIL)
      call firstByteA_B  # starting with "-"?
      cmp B (char "-")
      if eq  # Yes
         ld C 0  # No token
         call parseBCE_E  # Parse executable list
         link
         push E  # Save expression
         link
         call evListE_E  # Execute it
         drop
         ret
      end
   end
   link
   push (EnvIntern)  # <L III> Keep current namespace
   push ZERO  # <L II>
   push ZERO  # <L I>
   link
   push C  # <L -I> Prompt
   push Y
   push Z
   call rdOpenEX_S  # Open file
   ld E Nil  # Close transient scope
   call doHide
   do
      null (InFile)  # Stdin?
      if nz  # No
         ld C 0  # No terminator
         call readC_E  # Read expression
      else
         null (L -I)  # Prompt?
         if nz  # Yes
            null (Chr)
            if z
               ld E (Prompt)  # Output prompt prefix
               call runE_E  # Execute
               call prinE_E
               ld A (L -I)  # Output prompt
               call (PutB)
               call space
            end
         end
         ld C 10  # Linefeed terminator
         call readC_E  # Read expression
         ld A (Chr)
         do
            null A  # EOF?
         while nsz  # No
            cmp B 10  # Linefeed?
            if eq  # Yes
               ld (Chr) 0  # Clear it
               break T
            end
            cmp B (char "#")  # Comment char?
            if eq  # Yes
               call comment_A  # Skip comment
            else
               cmp B 32  # White space?
               break gt  # No
               call (Get_A)
            end
         loop
      end
      cmp E Nil
   while ne
      ld (L I) E  # Save read expression
      null (InFile)  # Stdin?
      if nz  # No
10       eval  # Evaluate
      else
         null (Chr)  # Line?
         jnz 10  # Yes
         ld A (L -I)
         nul B  # Prompt?
         jz 10  # No
         ld (L II) (At)  # Save '@'
         eval  # Evaluate
         ld (At) E  # Save result
         ld (At3) (At2)
         ld (At2) (L II)  # Retrieve previous '@'
         ld C Arrow
         call outStringC
         call printE_E
         call newline
      end
      ld (L I) E  # Save result
   loop
   ld (EnvIntern) (L III)  # Restore namespace
   call rdCloseS
   pop Z
   pop Y
   ld E Nil  # Close transient scope
   call doHide
   ld E (L I)
   drop
   ret

# (load 'any ..) -> any
(code 'doLoad 2)
   push X
   push Y
   ld X E
   ld Y (E CDR)  # Y on args
   do
      ld E (Y)  # Eval arg
      eval
      ld B (char ">")  # Prompt
      call loadBEX_E
      ld Y (Y CDR)  # More args?
      atom Y
   until nz  # No
   pop Y
   pop X
   ret

# (in 'any . prg) -> any
(code 'doIn 2)
   push X
   push Y
   push Z
   ld X E  # Expression in X
   ld E ((E CDR))  # Eval 'any'
   eval
   call rdOpenEX_S  # Open file
   ld X ((X CDR) CDR)  # Get 'prg'
   prog X
   call rdCloseS
   pop Z
   pop Y
   pop X
   ret

# (out 'any . prg) -> any
(code 'doOut 2)
   push X
   push Y
   push Z
   ld X E  # Expression in X
   ld E ((E CDR))  # Eval 'any'
   eval
   call wrOpenEX_S  # Open file
   ld X ((X CDR) CDR)  # Get 'prg'
   prog X
   call wrCloseS
   pop Z
   pop Y
   pop X
   ret

# (echo ['cnt ['cnt]] | ['sym ..]) -> sym
(code 'doEcho 2)
   push X
   push Y
   ld X E
   ld Y (E CDR)  # Y on args
   ld E (Y)  # Eval first
   eval
   ld Y (Y CDR)  # Next arg
   ld A (Chr)  # Look ahead char?
   null A
   if z  # No
      call (Get_A)  # Get next
   end
   cmp E Nil  # Empty arg?
   if eq  # Yes
      atom Y  # No further args?
      if nz  # Yes
         do
            null A  # EOF?
         while ns  # No
            call (PutB)  # Output byte
            call (Get_A)  # Get next
         loop
         ld E TSym  # Return T
         pop Y
         pop X
         ret
      end
   end
   num E  # Number?
   if nz  # Yes
      call xCntEX_FE  # Get 'cnt'
      atom Y  # Second 'cnt' arg?
      if z  # Yes
         ld Y (Y)  # Get second 'cnt'
         xchg Y E  # First 'cnt' in Y
         call evCntEX_FE  # Evaluate second
         ld A (Chr)  # Get Chr again
         do
            dec Y  # Decrement first 'cnt'
         while ns
            null A  # EOF?
            if s  # Yes
               ld E Nil  # Return NIL
               pop Y
               pop X
               ret
            end
            call (Get_A)  # Get next
         loop
      end
      null E  # 'cnt'?
      if nsz  # Yes
         do
            null A  # EOF?
            if s  # Yes
               ld E Nil  # Return NIL
               pop Y
               pop X
               ret
            end
            call (PutB)  # Output byte
            dec E  # Decrement 'cnt'
         while nz
            call (Get_A)  # Get next
         loop
      end
      ld (Chr) 0  # Clear look ahead
      ld E TSym  # Return T
      pop Y
      pop X
      ret
   end
   sym E  # Need symbol
   jz argErrEX
   push Z
   push 0  # End-of-buffers marker
   do
      call bufStringE_SZ  # <S V> Stack buffer
      push 0  # <S IV> Index
      link
      push E  # <S II> Symbol
      link
      push Z  # <S> Buffer chain
      atom Y  # More arguments?
   while z  # Yes
      call evSymY_E  # Next argument
      ld Y (Y CDR)
   loop
   ld X 0  # Clear current max
   ld A (Chr)  # Look ahead char
   do
      null A  # EOF?
   while ns  # No
      ld Y X  # Output max
      null Y  # Any?
      if nz  # Yes
         ld E (Y IV)  # Set output index
      end
      ld Z S  # Buffer chain
      do
         do
            lea C (Z V)  # Stack buffer
            add C (Z IV)  # Index
            cmp B (C)  # Bytes match?
            if eq  # Yes
               inc (Z IV)  # Increment index
               nul (C 1)  # End of string?
               if nz  # No
                  null X  # Current max?
                  if z  # No
                     ld X Z
                  else
                     cmp (X IV) (Z IV)  # Smaller than index?
                     if lt  # Yes
                        ld X Z
                     end
                  end
                  break T
               end
               null Y  # Output max?
               if nz  # Yes
                  lea C (Y V)  # Buffer of output max
                  sub E (Z IV)  # Diff to current index
                  do  # Done?
                  while ge  # No
                     ld B (C)
                     call (PutB)  # Output bytes
                     inc C
                     sub E 1
                  loop
               end
               ld (Chr) 0  # Clear look ahead
               ld E (Z II)  # Return matched symbol
               jmp 90
            end
            null (Z IV)  # Still at beginning of string?
            break z  # Yes
            lea C (Z (+ V 1))  # Offset pointer to second byte
            do
               dec (Z IV)  # Decrement index
            while nz
               cmpn (Z V) (C) (Z IV)  # Compare stack buffer
            while nz
               inc C  # Increment offset
            loop
            cmp X Z  # On current max?
            if eq  # Yes
               ld X 0  # Clear current max
               ld C S  # Buffer chain
               do
                  null (C IV)  # Index?
                  if nz  # Yes
                     null X  # Current max?
                     if z  # No
                        ld X C
                     else
                        cmp (X IV) (C IV)  # Smaller than index?
                        if lt  # Yes
                           ld X C
                        end
                     end
                  end
                  ld C (C)  # Next in chain
                  null (C)  # Any?
               until z  # No
            end
         loop
         ld Z (Z)  # Next in chain
         null (Z)  # Any?
      until z  # No
      null X  # Current max?
      if z  # No
         null Y  # Output max?
         if nz
            push A  # Save current byte
            push E  # and output index
            lea C (Y V)  # Buffer of output max
            do
               ld B (C)
               call (PutB)  # Output bytes
               inc C
               dec E  # Done?
            until z  # Yes
            pop E
            pop A
         end
         call (PutB)  # Output current byte
      else
         null Y  # Output max?
         if nz
            lea C (Y V)  # Buffer of output max
            sub E (X IV)  # Diff to current max index
            do  # Done?
            while ge  # No
               ld B (C)
               call (PutB)  # Output bytes
               inc C
               sub E 1
            loop
         end
      end
      call (Get_A)  # Get next input byte
   loop
   ld E Nil  # Return NIL
90 pop Z  # Clean up buffers
   do
      drop
      ld S Z
      pop Z
      null Z  # End?
   until z  # Yes
   pop Z
   pop Y
   pop X
   ret

(code 'putBinaryZB 0)
   push C
   push E
   ld C (Z VII)  # 'ix'
   cmp C ((Z I) III)  # At 'size'?
   if eq  # Yes
      push A  # Save byte
      push X
      ld X Z  # X on frame
      lea Z (X VIII)
      null (X V)  # Next block?
      if nz  # Yes
         ld C (X IV)  # Block index
         shl C ((X I) II)  # Shift for current file
         write ((X I)) Z ((X I) III) C  # Write current block
         ld C (X V)  # Next block
         ld (X IV) C  # Set block index
         shl C ((X I) II)  # Shift for current file
         read ((X I)) Z ((X I) III) C  # Read next block
         call getAdrZ_A  # Get link address
         off A BLKTAG
         ld (X V) A  # Store as next block
      else
         ld (DbFile) (X I)  # Set DB file
         push X
         call newBlock_X  # Allocate new block
         ld E X  # in E
         pop X
         ld B (Z)  # Get block count (link is zero)
         zxt
         push A  # Save count
         or A E  # Combine with new link
         call setAdrAZ  # Store in current block
         xchg E (X IV)  # Block index
         shl E ((X I) II)  # Shift for current file
         write ((X I)) Z ((X I) III) E  # Write current block
         pop A  # Retrieve count
         cmp A BLKTAG  # Max reached?
         if ne  # No
            inc A  # Increment count
         end
         call setAdrAZ  # Store in new current block
      end
      ld C BLK  # New 'ix'
      ld (X VII) C  # Save it
      pop X
      pop A  # Retrieve byte
   end
   lea E (Z VIII)  # Get 'buf'
   add E C  # Index
   ld (E) B  # Store byte
   inc C  # Increment 'ix'
   ld (Z VII) C
   inc (Z VI)  # Increment 'cnt'
   pop E
   pop C
   ret

(code 'putStdoutB 0)
   push Z
   ld Z (OutFile)  # Output frame?
   null Z  # Any?
   if nz  # No
      call putBinaryZB
   else
      call ttyOutB
   end
   pop Z
   ret

(code 'newline)
   ld B 10
   jmp (PutB)

(code 'space)
   ld B 32
   jmp (PutB)

# Output decimal number
(code 'outNumE)
   shr E 4  # Normalize
   if x  # Sign
      ld B (char "-")  # Output sign
      call (PutB)
   end
   ld A E
(code 'outWordA)
   cmp A 9  # Single digit?
   if gt  # No
      ld C 0  # Divide by 10
      div 10
      push C  # Save remainder
      call outWordA  # Recurse
      pop A
   end
   add B (char "0")  # Make ASCII digit
   jmp (PutB)

(code 'prExtNmX)
   call fileObjX_AC  # Get file and object ID
   null A  # File?
   if nz  # Yes
      call outAoA  # Output file number
   end
   ld A C  # Get object ID
# Output octal number
(code 'outOctA 0)
   cmp A 7  # Single digit?
   if gt  # No
      push A  # Save
      shr A 3  # Divide by 8
      call outOctA  # Recurse
      pop A
      and B 7  # Get remainder
   end
   add B (char "0")  # Make ASCII digit
   jmp (PutB)

# Output A-O encoding
(code 'outAoA 0)
   cmp A 15  # Single digit?
   if gt  # No
      push A  # Save
      shr A 4  # Divide by 16
      call outAoA  # Recurse
      pop A
      and B 15  # Get remainder
   end
   add B (char "@")  # Make ASCII letter
   jmp (PutB)

(code 'outStringC)
   do
      ld B (C)  # Next char
      inc C
      nul B  # Null?
   while nz  # No
      call (PutB)
   loop
   ret

(code 'outNameE)
   push X
   ld X (E TAIL)
   call nameX_X  # Get name
   call prNameX  # Print it
   pop X
   ret

(code 'prNameX)
   ld C 0
   do
      call symByteCX_FACX  # Next byte
   while nz
      call (PutB)  # Output byte
   loop
   ret

# Print one expression
(code 'printE_E)
   link
   push E  # <L I> Save expression
   link
   call printE  # Print it
   ld E (L I)  # Restore
   drop
   ret

(code 'printE 0)
   cmp S (StkLimit)  # Stack check
   jlt stkErr
   null (Signal)  # Signal?
   if nz  # Yes
      call sighandler0
   end
   cnt E  # Short number?
   jnz outNumE  # Yes
   big E  # Bignum?
   if nz  # Yes
      ld A -1  # Scale
      jmp fmtNum0AE_E  # Print it
   end
   push X
   sym E  # Symbol?
   if nz  # Yes
      ld X (E TAIL)
      call nameX_X  # Get name
      cmp X ZERO  # Any?
      if eq  # No
         ld B (char "$")  # $xxxxxx
         call (PutB)
         shr E 4  # Normalize symbol pointer
         ld A E
         call outOctA
         pop X
         ret
      end
      sym (E TAIL)  # External symbol?
      if nz  # Yes
         ld B (char "{")  # {AB123}
         call (PutB)
         call prExtNmX  # Print it
         ld B (char "}")
         call (PutB)
         pop X
         ret
      end
      push Y
      call isEnvInternEX_FCE  # Internal symbol?
      if eq  # Yes
         null C  # Found in other namespace?
         if nz  # Yes
            ld E C  # Print it
            call outNameE
            ld B (char "~")
            call (PutB)
         end
         cmp X (hex "2E2")  # Dot?
         if eq  # Yes
            ld B (char "\\")  # Print backslash
            call (PutB)
            ld B (char ".")  # Print dot
            call (PutB)
         else
            ld C 0
            call symByteCX_FACX  # Get first byte
            cmp B (char "#")  # Hash?
            if eq
               ld B (char "\\")  # Print backslash
               call (PutB)
               ld B (char "#")  # Restore Hash
            end
            do
               cmp B (char "\\")  # Backslash?
               jeq 10  # Yes
               memb Delim "(DelimEnd-Delim)"  # Delimiter?
               if eq  # Yes
10                push A  # Save char
                  ld B (char "\\")  # Print backslash
                  call (PutB)
                  pop A
               end
               call (PutB)  # Put byte
               call symByteCX_FACX  # Next byte
            until z  # Done
         end
      else  # Else transient symbol
         ld Y 0  # 'tsm' flag in Y
         atom (Tsm)  # Transient symbol markup?
         if z  # Yes
            null (OutFile)  # TTY?
            if z  # Yes
               inc Y  # Yes -> Y
            end
         end
         null Y  # Transient symbol markup?
         if z  # No
            ld B (char "\"")
            call (PutB)
         else
            ld E ((Tsm))  # Get CAR
            call outNameE  # Write transient symbol markup
         end
         ld C 0
         call symByteCX_FACX  # Get first byte
         do
            cmp B (char "\\")  # Backslash?
            jeq 20
            cmp B (char "\^")  # Caret?
            jeq 20
            null Y  # Transient symbol markup?
            jnz 30  # Yes
            cmp B (char "\"")  # Double quote?
            if eq  # Yes
20             push A  # Save char
               ld B (char "\\")  # Escape with backslash
               call (PutB)
               pop A
            else
30             cmp B 127  # DEL?
               if eq  # Yes
                  ld B (char "\^")  # Print ^?
                  call (PutB)
                  ld B (char "?")
               else
                  cmp B 32  # White space?
                  if lt  # Yes
                     push A  # Save char
                     ld B (char "\^")  # Escape with caret
                     call (PutB)
                     pop A
                     or A 64  # Make printable
                  end
               end
            end
            call (PutB)  # Put byte
            call symByteCX_FACX  # Next byte
         until z  # Done
         null Y  # Transient symbol markup?
         if z  # No
            ld B (char "\"")  # Final double quote
            call (PutB)
         else
            ld E ((Tsm) CDR)  # Get CDR
            call outNameE  # Write transient symbol markup
         end
      end
      pop Y
      pop X
      ret
   end
   # Print list
   cmp (E) Quote  # CAR 'quote'?
   if eq  # Yes
      cmp E (E CDR)  # Circular?
      if ne  # No
         ld B (char "'")  # Print single quote
         call (PutB)
         ld E (E CDR)  # And CDR
         call printE
         pop X
         ret
      end
   end
   push Y
   ld B (char "(")  # Open paren
   call (PutB)
   ld X E  # Keep list in X
   call circE_EF  # Circular?
   if nz  # No
      do
         ld E (X)  # Print CAR
         call printE
         ld X (X CDR)  # NIL-terminated?
         cmp X Nil
      while ne  # No
         atom X  # Atomic tail?
         if nz  # Yes
            call space  # Print " . "
            ld B (char ".")
            call (PutB)
            call space
            ld E X  # and the atom
            call printE
            break T
         end
         call space  # Print space
      loop
   else
      ld Y E  # Non-circular part
      cmp X E  # Fully circular?
      if eq  # Yes
         do
            ld E (X)  # Print CAR
            call printE
            call space  # and space
            ld X (X CDR)  # Done?
            cmp X Y
         until eq  # Yes
         ld B (char ".")  # Print "."
         call (PutB)
      else
         do  # Non-circular part
            ld E (X)  # Print CAR
            call printE
            call space  # and space
            ld X (X CDR)  # Done?
            cmp X Y
         until eq  # Yes
         ld B (char ".")  # Print ". ("
         call (PutB)
         call space
         ld B (char "(")
         call (PutB)
         do  # Circular part
            ld E (X)  # Print CAR
            call printE
            call space  # and space
            ld X (X CDR)  # Done?
            cmp X Y
         until eq  # Yes
         ld B (char ".")  # Print ".)"
         call (PutB)
         ld B (char ")")
         call (PutB)
      end
   end
   ld B (char ")")  # Closing paren
   call (PutB)
   pop Y
   pop X
   ret

# Print string representation
(code 'prinE_E 0)
   link
   push E  # <L I> Save expression
   link
   call prinE  # Print it
   ld E (L I)  # Restore
   drop
   ret

(code 'prinE 0)
   cmp S (StkLimit)  # Stack check
   jlt stkErr
   null (Signal)  # Signal?
   if nz  # Yes
      call sighandler0
   end
   cmp E Nil  # NIL?
   if ne  # No
      cnt E  # Short number?
      jnz outNumE  # Yes
      big E  # Bignum?
      if nz  # Yes
         ld A -1  # Scale
         jmp fmtNum0AE_E  # Print it
      end
      push X
      sym E  # Symbol?
      if nz  # Yes
         ld X (E TAIL)
         call nameX_X  # Get name
         cmp X ZERO  # Any?
         if ne  # Yes
            sym (E TAIL)  # External symbol?
            if z  # No
               call prNameX
            else
               ld B (char "{")  # {AB123}
               call (PutB)
               call prExtNmX  # Print it
               ld B (char "}")
               call (PutB)
            end
         end
      else
         ld X E  # Get list in X
         do
            ld E (X)  # Prin CAR
            call prinE
            ld X (X CDR)  # Next
            cmp X Nil  # NIL-terminated?
         while ne  # No
            atom X  # Done?
            if nz  # Yes
               ld E X  # Print atomic rest
               call prinE
               break T
            end
         loop
      end
      pop X
   end
   ret

# (prin 'any ..) -> any
(code 'doPrin 2)
   push X
   ld X (E CDR)  # Get arguments
   do
      ld E (X)
      eval  # Eval next arg
      call prinE_E  # Print string representation
      ld X (X CDR)  # More arguments?
      atom X
   until nz  # No
   pop X
   ret

# (prinl 'any ..) -> any
(code 'doPrinl 2)
   call doPrin  # Print arguments
   jmp newline

(code 'doSpace 2)
   push X
   ld X E
   ld E ((E CDR))  # Eval 'cnt'
   eval
   cmp E Nil  # NIL?
   if eq  # Yes
      call space  # Output single space
      ld E ONE  # Return 1
   else
      ld C E  # Keep in E
      call xCntCX_FC  # Get cnt
      do
         dec C  # 'cnt' times
      while ns
         call space  # Output spaces
      loop
   end
   pop X
   ret

# (print 'any ..) -> any
(code 'doPrint 2)
   push X
   ld X (E CDR)  # Get arguments
   do
      ld E (X)
      eval  # Eval next arg
      call printE_E  # Print it
      ld X (X CDR)  # More arguments?
      atom X
   while z  # Yes
      call space  # Print space
   loop
   pop X
   ret

# (printsp 'any ..) -> any
(code 'doPrintsp 2)
   push X
   ld X (E CDR)  # Get arguments
   do
      ld E (X)
      eval  # Eval next arg
      call printE_E  # Print it
      call space  # Print space
      ld X (X CDR)  # More arguments?
      atom X
   until nz  # No
   pop X
   ret

# (println 'any ..) -> any
(code 'doPrintln 2)
   call doPrint  # Print arguments
   jmp newline

# (ext 'cnt . prg) -> any
(code 'doExt 2)
   push X
   push Y
   ld X E
   ld Y (E CDR)  # Y on args
   call evCntXY_FE  # Eval 'cnt'
   push (ExtN)  # Save external symbol offset
   ld (ExtN) E  # Set new
   ld X (Y CDR)  # Run 'prg'
   prog X
   pop (ExtN)  # Restore external symbol offset
   pop Y
   pop X
   ret

# (rd ['sym]) -> any
# (rd 'cnt) -> num | NIL
(code 'doRd 2)
   push X
   push Z
   link
   push ZERO  # <L I> Result
   link
   ld E ((E CDR))  # Get arg
   eval  # Eval it
   ld Z (InFile)  # Current InFile?
   null Z
   if nz  # Yes
      cnt E  # Read raw bytes?
      if z  # No
         ld (L I) E  # EOF
         ld (GetBinZ_FB) getBinaryZ_FB  # Set binary read function
         ld (Extn) (ExtN)  # Set external symbol offset
         call binReadZ_FE  # Read item?
         if lt  # No: Return EOF
            ld E (L I)
         end
      else
         shr E 4  # Normalize
         jz 90  # Zero
         if x  # Little endian
            lea X (L I)  # X on result
            ld C 3  # Build signed number
            do
               call getBinaryZ_FB  # Enough bytes?
               jlt 90  # No
               call byteNumBCX_CX  # Add next byte to number
               dec E  # Done?
            until z  # Yes
            ld A (L I)  # Get result
            cnt A  # Short number?
            if nz  # Yes
               call twiceA_A  # Double it
            end
         else
            ld X E  # Count in X
            do
               call getBinaryZ_FB  # Enough bytes?
               jlt 90  # No
               zxt
               push A  # Save byte
               ld A (L I)  # Multiply number by 256
               ld E (hex "1002")
               call muluAE_A
               ld (L I) A  # Save digit
               pop E  # Get digit
               shl E 4  # Make short number
               or E CNT
               call adduAE_A  # Add to number
               ld (L I) A  # Save again
               dec X  # Done?
            until z  # Yes
         end
         big A  # Bignum?
         if nz  # Yes
            call zapZeroA_A  # Remove leading zeroes
         end
         ld E A  # Get result
      end
   else
90    ld E Nil  # Return NIL
   end
   drop
   pop Z
   pop X
   ret

# (pr 'any ..) -> any
(code 'doPr 2)
   push X
   ld X (E CDR)  # Get arguments
   do
      ld E (X)
      eval  # Eval next arg
      push E  # Keep
      ld (Extn) (ExtN)  # Set external symbol offset
      call prE  # Print binary
      pop E
      ld X (X CDR)  # More arguments?
      atom X
   until nz  # No
   pop X
   ret

# (wr 'cnt ..) -> cnt
(code 'doWr 2)
   push X
   ld X (E CDR)  # Args
   do
      ld E (X)  # Eval next
      eval
      ld A E  # Get byte
      shr A 4  # Normalize
      call putStdoutB  # Output
      ld X (X CDR)  # X on rest
      atom X  # Done?
   until nz  # Yes
   pop X
   ret

# vi:et:ts=3:sw=3

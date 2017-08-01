# 27may16abu
# (c) Software Lab. Alexander Burger

# 6 bytes in little endian format
# Get block address from buffer
(code 'getAdrZ_A 0)
   ld B (Z 5)  # Highest byte
   zxt
   shl A 8
   ld B (Z 4)
   shl A 8
   ld B (Z 3)
   shl A 8
   ld B (Z 2)
   shl A 8
   ld B (Z 1)
   shl A 8
   ld B (Z)  # Lowest byte
   ret

# Set block address in buffer
(code 'setAdrAZ 0)
   ld (Z) B  # Lowest byte
   shr A 8
   ld (Z 1) B
   shr A 8
   ld (Z 2) B
   shr A 8
   ld (Z 3) B
   shr A 8
   ld (Z 4) B
   shr A 8
   ld (Z 5) B  # Highest byte
   ret

# Build external symbol name
(code 'extNmCE_X 0)
   ld X C  # Get object ID into X
   and X (hex "FFFFF")  # Lowest 20 bits
   shr C 20  # Middle part of object ID
   ld A C
   and A (hex "FFF")  # Lowest 12 bits
   shl A 28
   or X A  # into X
   shr C 12  # Rest of object ID
   shl C 48
   or X C  # into X
   ld A E  # Get file number
   and A (hex "FF")  # Lowest 8 bits
   shl A 20  # Insert
   or X A  # into X
   shr E 8  # Rest of file number
   shl E 40
   or X E  # into X
   shl X 4  # Make short name
   or X CNT
   ret

# Pack external symbol name
(code 'packExtNmX_E)
   link
   push ZERO  # <L I> Name
   link
   call fileObjX_AC  # Get file and object ID
   push C  # Save object ID
   ld C 4  # Build name
   lea X (L I)
   null A  # Any?
   if nz  # Yes
      call packAoACX_CX  # Pack file number
   end
   pop A  # Get object ID
   call packOctACX_CX  # Pack it
   call cons_E  # Cons symbol
   ld (E) (L I)  # Set name
   or E SYM  # Make symbol
   ld (E) E  # Set value to itself
   drop
   ret

(code 'packAoACX_CX 0)
   cmp A 15  # Single digit?
   if gt  # No
      push A  # Save
      shr A 4  # Divide by 16
      call packAoACX_CX  # Recurse
      pop A
      and B 15  # Get remainder
   end
   add B (char "@")  # Make ASCII letter
   jmp byteSymBCX_CX  # Pack byte

(code 'packOctACX_CX 0)
   cmp A 7  # Single digit?
   if gt  # No
      push A  # Save
      shr A 3  # Divide by 8
      call packOctACX_CX  # Recurse
      pop A
      and B 7  # Get remainder
   end
   add B (char "0")  # Make ASCII digit
   jmp byteSymBCX_CX  # Pack byte

# Chop external symbol name
(code 'chopExtNmX_E)
   call fileObjX_AC  # Get file and object ID
   ld X A  # Keep file in X
   call oct3C_CA  # Get lowest octal digits
   call consA_E  # Final cell
   ld (E) A
   ld (E CDR) Nil
   link
   push E  # <L I> Result
   link
   do
      shr C 3  # Higher octal digits?
   while nz  # Yes
      call oct3C_CA  # Get next three digits
      call consA_E  # Cons into result
      ld (E) A
      ld (E CDR) (L I)
      ld (L I) E
   loop
   null X  # File number?
   if nz  # Yes
      ld E 0  # Build A-O encoding
      ld A 0
      do
         ld B X  # Next hax digit
         and B 15  # Lowest four bits
         add B (char "@")  # Make ASCII letter
         or E B
         shr X 4  # More hax digits?
      while nz  # Yes
         shl E 8  # Shift result
      loop
      shl E 4  # Make short name
      or E CNT
      call cons_A  # Make transient symbol
      ld (A) E  # Set name
      or A SYM  # Make symbol
      ld (A) A  # Set value to itself
      call consA_E  # Cons into result
      ld (E) A
      ld (E CDR) (L I)
      ld (L I) E
   end
   ld E (L I)  # Get result
   drop
   ret

(code 'oct3C_CA 0)
   ld A 0
   ld B C  # Lowest octal digit
   and B 7
   add B (char "0")  # Make ASCII digit
   ld E A
   shr C 3  # Next digit?
   if nz  # Yes
      ld B C  # Second octal digit
      and B 7
      add B (char "0")  # Make ASCII digit
      shl E 8
      or E B
      shr C 3  # Next digit?
      if nz  # Yes
         ld B C  # Hightest octal digit
         and B 7
         add B (char "0")  # Make ASCII digit
         shl E 8
         or E B
      end
   end
   shl E 4  # Make short name
   or E CNT
   call cons_A  # Make transient symbol
   ld (A) E  # Set name
   or A SYM  # Make symbol
   ld (A) A  # Set value to itself
   ret

# Get file and object ID from external symbol name
(code 'fileObjX_AC 0)
   shl X 2  # Strip status bits
   shr X 6  # Normalize
   ld C X  # Get object ID
   and C (hex "FFFFF")  # Lowest 20 bits
   shr X 20  # Get file number
   ld A X
   and A (hex "FF")  # Lowest 8 bits
   shr X 8  # More?
   if nz  # Yes
      ld E X  # Rest in E
      and E (hex "FFF")  # Middle 12 bits of object ID
      shl E 20
      or C E  # into C
      shr X 12  # High 8 bits of file number
      ld E X  # into E
      and E (hex "FF")  # Lowest 8 bits
      shl E 8
      or A E  # into A
      shr X 8  # Rest of object ID
      shl X 32
      or C X  # into C
   end
   ret

# Get file and object ID from external symbol
(code 'fileObjE_AC 0)
   push X
   ld X (E TAIL)
   call nameX_X  # Get name
   call fileObjX_AC
   pop X
   ret

# Get dbFile index and block index from external symbol
(code 'dbFileBlkY_AC 0)
   push X
   ld X Y  # Name in X
   call fileObjX_AC
   shl A 6  # 'dbFile' index
   shl C 6  # Block index
   pop X
   ret

(code 'setBlockAC_Z 0)
   add A DbFiles  # Get DB file
: setBlkAC_Z
   ld (DbFile) A  # Set current
   ld (BlkIndex) C  # Set block index
   ld A (A III)  # Block size
   ld Z DbBlock  # Get block buffer in Z
   add A Z  # Caclulate data end
   ld (BufEnd) A
   ret

(code 'rdBlockLinkZ_Z)
   ld A (BlkLink)  # Next block
(code 'rdBlockIndexAZ_Z)
   ld (BlkIndex) A  # Set block index
   ld Z DbBlock  # Block buffer in Z
(code 'rdBlockZ_Z)
   ld A (DbFile)  # Get current file
   ld C (A III)  # Block size
   ld E (BlkIndex)  # Get block index in E
   shl E (A II)  # Shift for current file
   call blkPeekCEZ  # Read block
   call getAdrZ_A  # Get link address
   off A BLKTAG
   ld (BlkLink) A  # Store as next block
   add Z BLK  # Point to block data
   ret

(code 'blkPeekCEZ)
   read ((DbFile)) Z C E  # Read C bytes from pos E into buffer Z
   cmp A C  # OK?
   jne dbRdErr  # No
   ret

(code 'wrBlockZ)
   ld A (DbFile)  # Get current file
   ld C (A III)  # Block size
   ld E (BlkIndex)  # Get block index in E
   shl E (A II)  # Shift for current file
(code 'blkPokeCEZ)
   write ((DbFile)) Z C E  # Write C bytes from buffer Z to pos E
   cmp A C  # OK?
   jne dbWrErr  # No
   ret

(code 'newBlock_X)
   push Z
   ld C (* 2 BLK)  # Read 'free' and 'next'
   ld E 0  # from block zero
   ld Z Buf  # into 'Buf'
   call blkPeekCEZ
   call getAdrZ_A  # 'free'?
   null A
   jz 10  # No
   null ((DbFile) VII)  # 'fluse'?
   if nz  # Yes
      ld X A  # Keep 'free' in X
      ld C (DbFile)
      shl A (C II)  # Shift 'free'
      dec (C VII)  # Decrement 'fluse'
      ld E A  # Read 'free' link
      ld C BLK
      call blkPeekCEZ  # into 'Buf'
      ld E 0  # Restore block zero in E
      ld C (* 2 BLK)  # and poke size in C
   else
10    add Z BLK  # Get 'next'
      call getAdrZ_A
      cmp A (hex "FFFFFFFFFFC0")  # Max object ID
      jeq dbSizErr  # DB Oversize
      ld X A  # Keep in X
      add A BLKSIZE  # Increment 'next'
      call setAdrAZ
      sub Z BLK  # Restore 'Buf' in Z
   end
   call blkPokeCEZ  # Write 'Buf' back
   ld C ((DbFile) III)  # Current file's block size
   sub S C  # <S> Buffer
   ld B 0  # Clear buffer
   mset (S) C  # with block size
   ld E X  # Get new block address
   shl E ((DbFile) II)  # Shift it
   ld Z S  # Write initblock
   call blkPokeCEZ
   add S ((DbFile) III)  # Drop buffer
   pop Z
   ret

(code 'newIdEX_X)
   dec E  # Zero-based
   shl E 6  # 'dbFile' index
   cmp E (DBs)  # In Range?
   jge dbfErrX  # No
   add E DbFiles  # Get DB file
   ld (DbFile) E  # Set current
   inc (EnvProtect)  # Protect the operation
   call newBlock_X  # Allocate new block
   dec (EnvProtect)  # Unprotect
   ld C X  # Object ID
   shr C 6  # Normalize
   ld E ((DbFile) I)  # Get file number
   jmp extNmCE_X  # Build external symbol name

(code 'isLifeE_F)
   push E  # Save symbol
   call fileObjE_AC  # Get file and ID
   pop E  # Restore symbol
   shl C 6  # Block index?
   jz retGt  # No
   shl A 6  # 'dbFile' index
   cmp A (DBs)  # Local file?
   if lt  # Yes
      add A DbFiles  # Get DB file
      ld (DbFile) A  # Set current
      ld A (E TAIL)  # Get tail
      call nameA_A  # Get name
      add A A  # Dirty?
      jc retEq  # Yes
      add A A  # Loaded?
      jc RetEq  # Yes
      push E
      push Z
      push C  # Save block index
      ld C BLK  # Read 'next'
      ld E BLK
      ld Z Buf  # into 'Buf'
      call blkPeekCEZ
      call getAdrZ_A  # Get 'next'
      pop C  # Get block index
      cmp C A  # Less than 'next'?
      if ge  # No
         gt  # 'nz'
         jmp 90
      end
      ld E C  # Block index
      shl E ((DbFile) II)  # Shift
      ld C BLK  # Read link field
      call blkPeekCEZ  # into 'Buf'
      ld B (Z)  # Get tag byte
      and B BLKTAG  # Block tag
      cmp B 1  # One?
90    pop Z
      pop E
   else
      atom (Ext)  # Extended databases?
   end
   ret  # 'z' if OK

(code 'cleanUpY)
   ld C BLK  # Read 'free'
   ld E 0  # from block zero
   ld Z Buf  # into 'Buf'
   call blkPeekCEZ
   call getAdrZ_A  # Get 'free'
   push A  # Save 'free'
   ld A Y  # Deleted block
   call setAdrAZ  # Store in buffer
   call blkPokeCEZ  # Set new 'free'
   ld E Y  # Deleted block
   do
      shl E ((DbFile) II)  # Shift it
      call blkPeekCEZ  # Get block link
      off (Z) BLKTAG  # Clear tag
      call getAdrZ_A  # Get link
      null A  # Any?
   while nz  # Yes
      ld Y A  # Keep link in Y
      call blkPokeCEZ  # Write link
      ld E Y  # Get link
   loop
   pop A  # Retrieve 'free'
   call setAdrAZ  # Store in buffer
   jmp blkPokeCEZ  # Append old 'free' list

(code 'getBlockZ_FB 0)
   cmp Z (BufEnd)  # End of block data?
   if eq  # Yes
      ld A (BlkLink)  # Next block?
      null A
      jz ret  # No: Return 'z'
      push C
      push E
      call rdBlockIndexAZ_Z  # Read block
      pop E
      pop C
   end
   ld B (Z)  # Next byte
   add Z 1  # 'nz'
   ret

(code 'putBlockBZ 0)
   cmp Z (BufEnd)  # End of block data?
   if eq  # Yes
      push A  # Save byte
      push C
      push E
      ld Z DbBlock  # Block buffer
      null (BlkLink)  # Next block?
      if nz  # Yes
         call wrBlockZ  # Write current block
         call rdBlockLinkZ_Z  # Read next block
      else
         push X
         call newBlock_X  # Allocate new block
         ld B (Z)  # Get block count (link is zero)
         zxt
         push A  # Save count
         or A X  # Combine with new link
         call setAdrAZ  # Store in current block
         call wrBlockZ  # Write current block
         ld (BlkIndex) X  # Set new block index
         pop A  # Retrieve count
         cmp A BLKTAG  # Max reached?
         if ne  # No
            inc A  # Increment count
         end
         call setAdrAZ  # Store in new current block
         add Z BLK  # Point to block data
         pop X
      end
      pop E
      pop C
      pop A  # Retrieve byte
   end
   ld (Z) B  # Store byte
   inc Z  # Increment pointer
   ret

# Append A-O encoding to string
(code 'bufAoAC_C 0)
   cmp A 15  # Single digit?
   if gt  # No
      push A  # Save
      shr A 4  # Divide by 16
      call bufAoAC_C  # Recurse
      pop A
      and B 15  # Get remainder
   end
   add B (char "@")  # Make ASCII letter
   ld (C) B  # Store in buffer
   inc C
   ret

# (id 'num ['num]) -> sym
# (id 'sym [NIL]) -> num
# (id 'sym T) -> (num . num)
(code 'doId 2)
   push X
   push Y
   ld X E
   ld Y (E CDR)  # Y on args
   ld E (Y)  # Eval first
   eval
   num E  # File number?
   if nz  # Yes
      shr E 4  # Normalize
      push E  # <S> Scaled file number or object ID
      ld Y (Y CDR)  # Next arg
      ld E (Y)
      eval  # Eval object ID
      cmp E Nil  # Given?
      if eq  # No
         pop C  # Get object ID
         ld E 0  # File defaults to zero
      else
         call xCntEX_FE  # Eval object ID
         ld C E  # into C
         pop E  # Get file number
         dec E  # Zero-based
      end
      call extNmCE_X  # Build external symbol name
      call externX_E  # New external symbol
      pop Y
      pop X
      ret
   end
   sym E  # Need symbol
   jz symErrEX
   sym (E TAIL)  # External symbol?
   jz extErrEX  # No
   xchg E Y  # Keep symbol in Y
   ld E ((E CDR))  # Eval second arg
   eval  # Eval flag
   xchg E Y  # Keep flag in Y, get symbol in E
   call fileObjE_AC  # Get file and ID
   shl C 4  # Make short object ID
   or C CNT
   cmp Y Nil  # Return only object ID?
   ldz E C  # Yes
   if ne  # No
      inc A  # File is zero-based
      shl A 4  # Make short file number
      or A CNT
      call cons_E  # Return (file . id)
      ld (E) A
      ld (E CDR) C
   end
   pop Y
   pop X
   ret

# (seq 'cnt|sym1) -> sym | NIL
(code 'doSeq 2)
   push X
   push Y
   push Z
   ld X E
   ld E ((E CDR))  # Eval arg
   eval
   num E  # File number?
   if nz  # Yes
      off E 15  # Normalize + 'dbFile' index
      sub E (hex "10")  # Zero-based
      shl E 2
      push E  # <S> Scaled file number
      cmp E (DBs)  # Local file?
      jge dbfErrX  # No
      add E DbFiles  # Get DB file
      ld (DbFile) E  # Set current
      ld X 0  # Block index zero
   else
      sym E  # Need symbol
      jz symErrEX
      sym (E TAIL)  # External symbol?
      jz extErrEX  # No
      call fileObjE_AC  # Get file and ID
      shl A 6  # 'dbFile' index
      push A  # <S> Scaled file number
      cmp A (DBs)  # Local file?
      jge dbfErrX  # No
      add A DbFiles  # Get DB file
      ld (DbFile) A  # Set current
      shl C 6  # Block index from object ID
      ld X C  # Block index in X
   end
   ld C BLK  # Read 'next'
   ld E BLK
   ld Z Buf  # into 'Buf'
   call blkPeekCEZ
   call getAdrZ_A  # Get 'next'
   ld Y A  # into Y
   do
      add X BLKSIZE  # Increment block index
      cmp X Y  # Less than 'next'?
      if ge  # No
         add S I  # Drop file number
         ld E Nil  # Return NIL
         break T
      end
      ld E X  # Block index
      shl E ((DbFile) II)  # Shift
      ld C BLK  # Read link field
      call blkPeekCEZ  # into 'Buf'
      ld B (Z)  # Get tag byte
      and B BLKTAG  # Block tag
      cmp B 1  # One?
      if eq  # Yes
         pop E  # Get scaled file number
         shr E 6  # Normalize
         ld C X  # Object ID
         shr C 6  # Normalize
         call extNmCE_X  # Build external symbol name
         call externX_E  # New external symbol
         break T
      end
   loop
   pop Z
   pop Y
   pop X
   ret

# (lieu 'any) -> sym | NIL
(code 'doLieu 2)
   ld E ((E CDR))  # Get arg
   eval  # Eval it
   num E  # Number?
   jnz retNil  # Yes
   sym E  # Symbol?
   jz retNil  # No
   ld A (E TAIL)  # Get tail
   sym A  # External symbol?
   jz retNil  # No
   off A SYM  # Clear 'extern' tag
   do
      num A  # Found name?
      if nz  # Yes
         add A A  # Dirty?
         if nc  # No
            add A A  # Loaded?
            if nc  # No
               ld E Nil  # No
            end
            ret
         end
         add A A  # Deleted?
         if c  # Yes
            ld E Nil
         end
         ret
      end
      ld A (A CDR)  # Skip property
   loop

(code 'dbFetchEX 0)
   ld A (E TAIL)  # Get tail
   num A  # Any properties?
   jz Ret  # Yes
   rxl A 1  # Dirty?
   jx ret  # Yes
   rxl A 1  # Loaded?
   jx ret  # Yes
   setx  # Set "loaded"
   rxr A 1
   shr A 1
(code 'dbAEX 0)
   push Y
   push Z
   push C
   link
   push E  # <L I> Symbol
   link
   ld Y A  # Status/name in Y
   call dbFileBlkY_AC  # Get file and block index
   cmp A (DBs)  # Local file?
   if lt  # Yes
      call setBlockAC_Z  # Set up block env
      call rdBlockZ_Z  # Read first block
      ld B (Z (- BLK))  # Get tag byte
      and B BLKTAG  # Block tag
      cmp B 1  # One?
      jne idErrXL  # Bad ID
      ld (GetBinZ_FB) getBlockZ_FB  # Set binary read function
      ld (Extn) 0  # Set external symbol offset to zero
      call binReadZ_FE  # Read first item
      ld A (L I)  # Get symbol
      ld (A) E  # Set value
      ld (A TAIL) Y  # and status/name
      call binReadZ_FE  # Read first property key
      cmp E Nil  # Any?
      if ne  # Yes
         call consE_A  # Build first property cell
         ld (A) E  # Cons key
         ld (A CDR) Y  # With status/name
         ld Y A  # Keep cell in Y
         or A SYM  # Set 'extern' tag
         ld ((L I) TAIL) A  # Set symbol's tail
         call binReadZ_FE  # Read property value
         cmp E TSym  # T?
         if ne  # No
            call consE_A  # Cons property value
            ld (A) E
            ld (A CDR) (Y)  # With key
            ld (Y) A  # Save in first property cell
         end
         do
            call binReadZ_FE  # Read next property key
            cmp E Nil  # Any?
         while ne  # Yes
            call consE_A  # Build next property cell
            ld (A) E  # Cons key
            ld (A CDR) (Y CDR)  # With name
            ld (Y CDR) A  # Insert
            ld Y A  # Point Y to new cell
            call binReadZ_FE  # Read property value
            cmp E TSym  # T?
            if ne  # No
               call consE_A  # Cons property value
               ld (A) E
               ld (A CDR) (Y)  # With key
               ld (Y) A  # Save in property cell
            end
         loop
      end
   else
      shr A 6  # Revert to file number
      ld Z (Ext)  # Extended databases?
      atom Z
      jnz dbfErrX  # No
      inc A  # File is zero-based
      ld C ((Z))  # First offset
      shr C 4  # Normalize
      cmp A C  # First offset too big?
      jlt dbfErrX  # Yes
      do
         ld E (Z CDR)  # More?
         atom E
      while z  # Yes
         ld C ((E))  # Next offset
         shr C 4  # Normalize
         cmp A C  # Matching entry?
      while ge  # No
         ld Z E  # Try next DB extension
      loop
      push Y  # Save name
      push ((Z) CDR)  # fun ((Obj) ..)
      ld Y S  # Pointer to fun in Y
      push (L I)  # Symbol
      ld Z S  # Z on (last) argument
      call applyXYZ_E  # Apply
      pop Z  # Get symbol
      add S I  # Drop 'fun'
      pop Y  # Get name
      ld (Z) (E)  # Set symbol's value
      ld E (E CDR)  # Properties?
      atom E
      if z  # Yes
         ld A E  # Set 'extern' tag
         or A SYM
         ld (Z TAIL) A  # Set property list
         do
            atom (E CDR)  # Find end
         while z
            ld E (E CDR)
         loop
         ld (E CDR) Y  # Set name
      else
         or Y SYM  # Set 'extern' tag
         ld (Z TAIL) Y  # Set name
      end
   end
   ld E (L I)  # Restore symbol
   drop
   pop C
   pop Z
   pop Y
   ret

(code 'dbTouchEX 0)
   push C
   lea C (E TAIL)  # Get tail
   ld A (C)
   num A  # Any properties?
   if z  # Yes
      off A SYM  # Clear 'extern' tag
      do
         lea C (A CDR)  # Skip property
         ld A (C)
         num A  # Find name
      until nz
   end
   rxl A 1  # Already dirty?
   if nx  # No
      rxl A 1  # Loaded?
      if x  # Yes
         shr A 1
         setx  # Set "dirty"
         rxr A 1
         ld (C) A  # in status/name
         pop C
         ret
      end
      shr A 1
      setx  # Set "dirty"
      rxr A 1
      pop C
      jmp dbAEX
   end
   pop C
   ret

(code 'dbZapE 0)
   ld A (E TAIL)  # Get tail
   num A  # Any properties?
   if z  # Yes
      off A SYM  # Clear 'extern' tag
      do
         ld A (A CDR)  # Skip property
         num A  # Find name
      until nz
      or A SYM  # Set 'extern' tag
   end
   shl A 2  # Set "deleted"
   setx
   rxr A 1
   setx
   rxr A 1
   ld (E TAIL) A  # Set empty tail
   ld (E) Nil  # Clear value
   ret

# (commit) -> T
(code 'doCommit 2)
   push X
   push Y
   push Z
   inc (EnvProtect)  # Protect the operation
   ld X (Extern)  # Iterate external symbol tree
   ld Y 0  # Clear TOS
   do
      do
         ld A (X CDR)  # Get subtrees
         atom (A)  # Left subtree?
      while z  # Yes
         ld C X  # Go left
         ld X (A)  # Invert tree
         ld (A) Y  # TOS
         ld Y C
      loop
      do
         lea C ((X) TAIL)  # Get external symbol's tail
         ld A (C)
         num A  # Any properties?
         if z  # Yes
            off A SYM  # Clear 'extern' tag
            do
               lea C (A CDR)  # Skip property
               ld A (C)
               num A  # Find name
            until nz
         end
         rxl A 1  # Dirty?
         if x  # Yes
            push Y
            rxl A 1  # Deleted?
            if nx  # No
               setx  # Set "loaded"
               rxr A 1
               shr A 1
               ld (C) A  # in status/name
               ld Y A  # Name in Y
               call dbFileBlkY_AC  # Get file and block index
               cmp A (DBs)  # Local file?
               if lt  # Yes
                  call setBlockAC_Z  # Set up block env
                  call rdBlockZ_Z  # Read first block
                  ld B 1  # First block in object (might be a new object)
                  or (Z (- BLK)) B  # Set in tag byte
                  ld (PutBinBZ) putBlockBZ  # Set binary print function
                  ld Y (X)  # Get external symbol
                  ld E (Y)  # Print value
                  ld (Extn) 0  # Set external symbol offset to zero
                  call binPrintEZ
                  ld Y (Y TAIL)  # Get tail
                  off Y SYM  # Clear 'extern' tag
                  do
                     num Y  # Properties?
                  while z  # Yes
                     atom (Y)  # Flag?
                     if z  # No
                        ld E ((Y) CDR)  # Get key
                        cmp E Nil  # Volatile property?
                        if ne  # No
                           call binPrintEZ  # Print key
                           ld E ((Y))  # Print value
                           call binPrintEZ
                        end
                     else
                        ld E (Y)  # Get key
                        cmp E Nil  # Volatile property?
                        if ne  # No
                           call binPrintEZ  # Print key
                           ld E TSym  # Print 'T'
                           call binPrintEZ
                        end
                     end
                     ld Y (Y CDR)
                  loop
                  ld B NIX
                  call putBlockBZ  # Output NIX
                  ld Z DbBlock  # Block buffer in Z again
                  ld B (Z)  # Lowest byte of link field
                  and B BLKTAG  # Clear link
                  zxt
                  call setAdrAZ  # Store in last block
                  call wrBlockZ  # Write block
                  ld Y (BlkLink)  # More blocks?
                  null Y
                  if nz  # Yes
                     call cleanUpY  # Clean up
                  end
               end
            else  # Deleted
               shr A 2  # Set "not loaded"
               ld (C) A  # in status/name
               ld Y A  # Name in Y
               call dbFileBlkY_AC  # Get file and block index
               cmp A (DBs)  # Local file?
               if lt  # Yes
                  add A DbFiles  # Get DB file
                  ld (DbFile) A  # Set current
                  ld Y C
                  call cleanUpY  # Clean up
               end
            end
            pop Y
         end
         ld A (X CDR)  # Right subtree?
         atom (A CDR)
         if z  # Yes
            ld C X  # Go right
            ld X (A CDR)  # Invert tree
            ld (A CDR) Y  # TOS
            or C SYM  # First visit
            ld Y C
            break T
         end
         do
            ld A Y  # TOS
            null A  # Empty?
            jeq 40  # Done
            sym A  # Second visit?
            if z  # Yes
               ld C (A CDR)  # Nodes
               ld Y (C)  # TOS on up link
               ld (C) X
               ld X A
               break T
            end
            off A SYM  # Set second visit
            ld C (A CDR)  # Nodes
            ld Y (C CDR)
            ld (C CDR) X
            ld X A
         loop
      loop
   loop
40 dec (EnvProtect)  # Unprotect
   ld E DbFiles  # Iterate DB files
   ld C (DBs)  # Count
   do
      ld (E VII) -1  # Init 'fluse'
      add E VIII  # Increment by sizeof(dbFile)
      sub C VIII  # Done?
   until z  # Yes
   pop Z
   pop Y
   pop X
   ld E TSym  # Return T
   ret

# (rollback) -> flg
(code 'doRollback 2)
   null (DBs)  # DB open?
   if z  # No
      atom (Ext)  # or extended?
      jnz retNil  # No
   end
   push X
   push Y
   ld X (Extern)  # Iterate external symbol tree
   ld Y 0  # Clear TOS
   do
      do
         ld A (X CDR)  # Get subtrees
         atom (A CDR)  # Right subtree?
      while z  # Yes
         ld C X  # Go right
         ld X (A CDR)  # Invert tree
         ld (A CDR) Y  # TOS
         ld Y C
      loop
      do
         ld E (X)  # Get external symbol
         ld A (E TAIL)
         num A  # Any properties?
         if z  # Yes
            off A SYM  # Clear 'extern' tag
            do
               ld A (A CDR)  # Skip property
               num A  # Find name
            until nz
            or A SYM  # Set 'extern' tag
         end
         shl A 2  # Strip status bits
         shr A 2
         ld (E TAIL) A  # Set status/name
         ld (E) Nil  # Clear value
         ld A (X CDR)  # Left subtree?
         atom (A)
         if z  # Yes
            ld C X  # Go left
            ld X (A)  # Invert tree
            ld (A) Y  # TOS
            or C SYM  # First visit
            ld Y C
            break T
         end
         do
            ld A Y  # TOS
            null A  # Empty?
            jeq 90  # Done
            sym A  # Second visit?
            if z  # Yes
               ld C (A CDR)  # Nodes
               ld Y (C CDR)  # TOS on up link
               ld (C CDR) X
               ld X A
               break T
            end
            off A SYM  # Set second visit
            ld C (A CDR)  # Nodes
            ld Y (C)
            ld (C) X
            ld X A
         loop
      loop
   loop
90 pop Y
   pop X
   ld E TSym  # Return T
   ret

# vi:et:ts=3:sw=3

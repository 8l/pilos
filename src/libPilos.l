# 17jun15abu
# (c) Software Lab. Alexander Burger

(data 'PilosData)
   initData

: ExtIn     word 0  # External symbol input
: ExtOut    word 0  # External symbol output

(code 'PilosCode)
   initCode

### PilOS File I/O ###
(code 'putExtB)
   push C
   push E
   push X
   ld X (ExtOut)  # Output frame
   ld C (X V)  # 'ix'
   cmp C ((X I) III)  # At 'size'?
   if eq  # Yes
      push A  # Save byte
      push Z
      lea Z (X VI)
      null (X III)  # Next block?
      if nz  # Yes
         ld C (X II)  # Block index
         shl C ((X I) II)  # Shift for current file
         cc pwrite(((X I)) Z ((X I) III) C)  # Write current block
         ld C (X III)  # Next block
         ld (X II) C  # Set block index
         shl C ((X I) II)  # Shift for current file
         cc pread(((X I)) Z ((X I) III) C)  # Read next block
         call getAdrZ_A  # Get link address
         off A BLKTAG
         ld (X III) A  # Store as next block
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
         xchg E (X II)  # Block index
         shl E ((X I) II)  # Shift for current file
         cc pwrite(((X I)) Z ((X I) III) E)  # Write current block
         pop A  # Retrieve count
         cmp A BLKTAG  # Max reached?
         if ne  # No
            inc A  # Increment count
         end
         call setAdrAZ  # Store in new current block
      end
      ld C BLK  # New 'ix'
      ld (X V) C  # Save it
      pop Z
      pop A  # Retrieve byte
   end
   lea E (X VI)  # Get 'buf'
   add E C  # Index
   ld (E) B  # Store byte
   inc C  # Increment 'ix'
   ld (X V) C
   inc (X IV)  # Increment 'cnt'
   pop X
   pop E
   pop C
   ret

(code 'getExt_A)
   push C
   push E
   push X
   ld X (ExtIn)  # Input frame
   null (X IV)  # EOF?
   if nz  # No
      ld C (X V)  # 'ix'
      cmp C ((X I) III)  # At 'size'?
      if eq  # Yes
         ld C (X III)  # Next block
         ld (X II) C  # Set block index
         shl C ((X I) II)  # Shift for current file
         push Z
         ld A (X I)  # dbFile
         lea Z (X VI)  # Z on 'buf'
         cc pread((A) Z (A III) C)  # Read next block
         call getAdrZ_A  # Get link address
         pop Z
         off A BLKTAG
         ld (X III) A  # Store as next block
         ld C BLK  # New 'ix'
      end
      lea E (X VI)  # Get 'buf'
      add E C  # Index
      inc C  # Increment 'ix'
      ld (X V) C
      ld B (E)  # Fetch byte
      zxt  # Extend into A
      dec (X IV)  # Decrement 'cnt'
   else
      ld A -1  # Return EOF
   end
   ld (Chr) A
   pop X
   pop E
   pop C
   ret

# (lib/pilos:In 'sym . prg) -> any
(code 'In 2)
   push X
   push Y
   push Z
   ld X E
   ld E ((E CDR))  # Eval 'sym'
   eval
   sym E  # Need symbol
   jz symErrEX
   ld Y (E TAIL)  # Get tail
   sym Y  # External symbol?
   jz extErrEX  # No
   call nameY_Y  # Get name
   call dbFileBlkY_AC  # Get file and block index
   cmp A (DBs)  # Local file?
   jge dbfErrX  # No
   cmp S (StkLimit)  # Stack check
   jlt stkErr
   push (Chr)  # Save Chr
   push (Get_A)  # Save 'get'
   ld (Get_A) getExt_A  # Set 'get'
   add A (DbFiles)  # Get DB file  !! PilOS -> DbFiles
   sub S (A III)  # <S VI> Buffer [Block size]
   push BLK  # <S V> 'ix'
   push 8  # <S IV> 'cnt' (dummy for value read)
   push 0  # <S III> Block link
   push C  # <S II> Block index
   push A  # <S I> dbFile
   push (ExtIn)  # Link
   ld (ExtIn) S  # Close input frame
   shl C (A II)  # Shift block index for current file
   lea Z (S VI)
   cc pread((A) Z (A III) C)  # Read first block
   call getAdrZ_A  # Get link address
   off A BLKTAG
   ld (S III) A  # Store as next block
   ld (GetBinZ_FB) getExt_A  # Set binary read function
   ## !! ld (Extn) 0  # Set external symbol offset to zero
   call binReadZ_FE  # Read value (file size)
   cnt E  # Need short
   jz cntErrEX
   shr E 4  # Normalize
   ld (S IV) E  # Set 'cnt'
   ld (S V) 16  # and 'ix'
   ld (Chr) 0  # Init Chr
   ld X ((X CDR) CDR)  # Get 'prg'
   prog X
   ld X E  # Return value in X
   pop (ExtIn)  # Drop input frame
   pop A  # dbFile
   add S IV  # Drop blk, link, cnt, ix
   add S (A III)  # Drop buffer
   pop (Get_A)  # Restore 'get'
   pop (Chr)  # Restore Chr
   ld E X  # Get return value
   pop Z
   pop Y
   pop X
   ret

# (lib/pilos:Out 'sym . prg) -> any
(code 'Out 2)
   push X
   push Y
   push Z
   ld X E
   ld E ((E CDR))  # Eval 'sym'
   eval
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
   cmp S (StkLimit)  # Stack check
   jlt stkErr
   push (PutB)  # Save 'put'
   ld (PutB) putExtB  # Set 'put'
   add A (DbFiles)  # Get DB file  !! PilOS -> DbFiles
   sub S (A III)  # <S VI> Buffer [Block size]
   push 16  # <S V> 'ix'
   push 0  # <S IV> 'cnt'
   push 0  # <S III> Block link
   push C  # <S II> Block index
   push A  # <S I> dbFile
   push (ExtOut)  # Link
   ld (ExtOut) S  # Close output frame
   shl C (A II)  # Shift block index for current file
   lea Z (S VI)
   cc pread((A) Z (A III) C)  # Read first block
   call getAdrZ_A  # Get link address
   off A BLKTAG
   ld (S III) A  # Store as next block
   ld X ((X CDR) CDR)  # Get 'prg'
   prog X
   ld X E  # Return value in X
   ld E (S II)  # Block index
   shl E ((S I) II)  # Shift for current file
   cc pwrite(((S I)) &(S VI) ((S I) III) E)  # Write last block
   ld E (S IV)  # Get 'cnt' (file size)
   shl E 4  # Make short number
   or E CNT
   ld (S IV) 0  # Reset 'cnt'
   ld (S V) 0  # Start of buffer
   ## !! ld (Extn) 0  # Set external symbol offset to zero
   ld (PutBinBZ) putExtB  # Set binary print function
   call binPrintEZ  # Print value (file size)
   ld B NIX  # No properties
   call putExtB
   call dbFileBlkY_AC  # Get  block index again
   shl C ((S I) II)  # Shift for current file
   add C BLK  # Skip link
   cc pwrite(((S I)) &(S VI) (S IV) C)  # Rewrite part of first block
   pop (ExtOut)  # Drop output frame
   pop A  # dbFile
   add S IV  # Drop blk, link, cnt, ix
   add S (A III)  # Drop buffer
   pop (PutB)  # Restore 'put'
   ld E X  # Get return value
   pop Z
   pop Y
   pop X
   ret

# vi:et:ts=3:sw=3

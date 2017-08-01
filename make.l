# 16mar17abu
# (c) Software Lab. Alexander Burger

(setq *Architecture (opt))

(setq
   *SrcFile (pack *Architecture ".s")
   *ObjFile (pack *Architecture ".o")
   *BinFile (pack *Architecture ".bin")
   *ImgFile (pack *Architecture ".img") )

(load "@src64/lib/asm.l"
   "@src64/lib/fmt.s.l" "fmt.l"
   (pack "@src64/arch/" *Architecture ".l")
   "x86-64/arch.l" )

# Build
(build *SrcFile NIL
   (load
      "x86-64/beg.l" "src/defs.l" "src/version.l"
      "src/main.l" "src/gc.l" "src/apply.l" "src/flow.l"
      "src/sym.l" "src/subr.l" "src/big.l" "src/io.l" "src/db.l"
      "src/err.l" "src/sys.l" "src/glob.l" "src/end.l" ) )

# Assemble and link
(unless
   (and
      (call "as" "-o" *ObjFile *SrcFile)
      (call "ld" "-o" *BinFile "--oformat=binary" "-Ttext=0x7C00" *ObjFile) )
   (bye 1) )

(out *ImgFile
   (in *BinFile
      (echo) )
   (do (- (* 512 1024) (car (info *BinFile)))
      (wr 0) )
   (in "db.bin"
      (echo) )
   (do (* 512 64)  # 64 scratch sectors (32 KiB)
      (wr 0) ) )

(bye)

# vi:et:ts=3:sw=3

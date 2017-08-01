# 18jun15abu
# (c) Software Lab. Alexander Burger

(setq
   *Architecture (opt)
   *System (opt)
   *FPic T )

(load "@src64/lib/asm.l" "@src64/lib/fmt.s.l"
   (pack "@src64/arch/" *Architecture ".l") )

# Build
(build "src/libPilos.s" NIL
   (load
      (pack "@src64/sys/" *Architecture *System ".defs.l")
      "@src64/defs.l"
      "src/libPilos.l" ) )

# Assemble and link
(unless
   (and
      (call "as" "-o" "src/libPilos.o" "src/libPilos.s")
	   (call "gcc" "-o" "lib/pilos" "src/libPilos.o" "-shared" "-export-dynamic") )
   (bye 1) )

(bye)

# vi:et:ts=3:sw=3

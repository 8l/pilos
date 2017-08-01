# 02jul15abu
# (c) Software Lab. Alexander Burger

.SILENT:

PIL = pil

srcFiles = x86-64/beg.l src/defs.l src/version.l \
	src/main.l src/gc.l src/apply.l src/flow.l \
	src/sym.l src/subr.l src/big.l src/io.l src/db.l \
	src/err.l src/sys.l src/glob.l src/end.l

initFiles = lib/init.l init/lib.l init/lib/misc.l \
	init/lib/btree.l init/lib/db.l init/lib/pilog.l \
	init/lib/dbg.l init/lib/sq.l \
	init/misc/bench.l init/misc/fibo.l \
	init/.pil/history

all: x86-64.img

### PilOS Image ###
x86-64.img: fmt.l x86-64/arch.l $(srcFiles) db.bin
	$(PIL) make.l x86-64 +

## Initial DB ###
db.bin: lib/pilos $(initFiles)
	$(PIL) lib/init.l -bye

### PicoLisp shared Library ###
lib/pilos: fmt.l x86-64/arch.l src/libPilos.l
	$(PIL) mkLibPilos.l x86-64 .linux +

### Clean up ###
clean:
	rm -f x86-64.bin x86-64.o x86-64.s
	rm -f ssd? db.bin
	rm -f lib/pilos src/libPilos.o src/libPilos.s

# vi:noet:ts=4:sw=4

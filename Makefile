os=osx
OS=$(os)


DEBUG:=$(debug)

nasm?=nasm

debug?=0

ws?=64
WS:=$(ws)

asm?=as
ASM:=$(asm)


TARGET=$(OS)_$(WS)

trc?=0
ifeq	($(trc),1)
TRC=trc
endif

basebol=./bin/sbl_osx_64
BASEBOL=$(basebol)

cc?=gcc
CC:=$(cc)

ifeq	($(DEBUG),1)
GFLAG=-g
endif

ARCH=-D$(TARGET)  -m$(WS)

CCOPTS:= $(GFLAG) 
LDOPTS:= $(GFLAG)
LMOPT:=-lm

ifeq ($(OS),unix)
ELF:=elf$(WS)
else
EL:F=macho$(WS)
endif


OSINT=./osint

vpath %.c $(OSINT)

# Assembler info -- Intel 64-bit syntax
ifeq	($(DEBUG),0)
ASMOPTS =  -D$(TARGET) 
else
ASMOPTS = -g  -D$(TARGET) 
endif

OSXOPTS = -f macho64 -Dosx_64 
# tools for processing Minimal source file.

# implicit rule for building objects from C files.
./%.o: %.c
#.c.o:
	$(CC)  $(CCOPTS) -c  -o$@ $(OSINT)/$*.c

osx:	
# build using gas translator for osx 64 bits
	rm -fr bld
	mkdir bld
	$(CC) -Dosx_64 -m64 $(CCOPTS) -c osint/*.c
	mv *.o bld
	./bin/sbl_osx_64 -u osx_64_gas	-1=sbl.asm	-2=bld/sbl.lex	-3=bld/sbl.equ lex.sbl
	./bin/sbl_osx_64 -u osx_64_gas:$(TRC) 	-1=bld/sbl.lex 	-2=bld/sbl.tmp 	-3=bld/sbl.err 	-4=bld/sbl.equ gas/asm.sbl
	./bin/sbl_osx_64 -u osx_64_gas	-1=bld/sbl.err	-2=bld/err.s err.sbl
	cat 	gas/osx.asm gas/sys.asm 	bld/err.s 	bld/sbl.tmp 	>bld/sbl.s
	as	-o bld/sbl.o	bld/sbl.s
	$(CC) bld/*.o -osbl 

unix:
# build using gas translator for unix 64 bits
	rm -fr bld
	mkdir bld
	$(CC) -Dunix_64	-m64 $(CCOPTS)	-c osint/*.c
	mv *.o bld
	./bin/sbl_unix_64 -u unix_64_gas		-1=sbl.asm 	-2=bld/sbl.lex	-3=bld/sbl.equ lex.sbl
	./bin/sbl_unix_64 -u unix_64_gas:$(TRC)	-1=bld/sbl.lex	-2=bld/sbl.tmp	-3=bld/sbl.err -4=bld/sbl.equ gas/asm.sbl
	./bin/sbl_unix_64 -u unix_64_gas		-1=bld/sbl.err	-2=bld/err.s err.sbl
	cat	gas/unix.asm gas/sys.asm	bld/err.s	bld/sbl.tmp	>bld/sbl.s
	as 	-o bld/sbl.o	bld/sbl.s
	$(CC) -lm -Dunix_64 -m64 -static $(LDOPTS)  bld/*.o -lm  -osbl 

unix_nasm:
	rm -fr bld
	mkdir bld
	$(CC) -Dunix_64 -m64 $(CCOPTS) -c osint/*.c
	mv *.o bld
	./bin/sbl_unix_64 -u unix_64_nasm -1=sbl.asm -2=bld/sbl.lex -3=bld/sbl.equ lex.sbl
	./bin/sbl_unix_64 -r -u unix_64:$(TRC) -1=bld/sbl.lex -2=bld/sbl.tmp -3=bld/sbl.err -4=bld/sbl.equ nasm/asm.sbl
	./bin/sbl_unix_64 -u unix_64_nasm -1=bld/sbl.err -2=bld/err.s err.sbl
	cat nasm/sys.asm bld/err.s bld/sbl.tmp >bld/sbl.s
	nasm -f elf64 -Dunix_64 -o bld/sbl.o bld/sbl.s
	$(CC) -lm -Dunix_64 -m64 $(LDOPTS) -static  bld/*.o -lm  -osbl 

# link spitbol with dynamic linking
spitbol-dynamic: $(OBJS) $(NOBJS)
	$(CC) $(LDOPTS) $(OBJS) $(NOBJS) $(LMOPT)  -osbl 

# bootbol is for bootstrapping just link with what's at hand
#bootbol: $(OBJS)
# no dependencies so can link for osx bootstrap
bootbol: 
	$(CC) $(LDOPTS)  $(OBJS) $(LMOPT) -obootbol

osx-export: 
	
	cp bld/sbl.s  osx/sbl.s

osx-import: 
	gcc -arch i386 -c osint/*.c
	cp osx/*.o .
	gcc -arch i386  -o sbl *.o

# install binaries from ./bin as the system spitbol compilers
install:
	sudo cp ./bin/sbl /usr/local/bin
.PHONY:	clean
clean:
	rm -f bld/*  ./sbl  sbl_unix_64 tb*

z:
	nm -n s.o >s.nm
	sbl map-$(WS).sbl <s.nm >s.dic
	sbl z.sbl <ad >ae

# build system using nasm
nasm_64:
	$(CC) -Dunix_64 -m64 $(CCOPTS) -c osint/*.c
	./bin/sbl_unix_64 -u unix_64 nasm/lex.sbl
	./bin/sbl_unix_64 -r -u unix_64:$(ITOPT) -1=sbl.lex -2=sbl.tmp -3=sbl.err nasm/asm.sbl
	./bin/sbl_unix_64 -u unix_64 -1=sbl.err -2=err.s nasm/err.sbl
	cat sys.asm err.s sbl.tmp >sbl.s
	nasm -f elf64 -Dunix_64 -o sbl.o sbl.s
	$(CC) -lm -Dunix_64 -m64 $(LDOPTS)  *.o -lm  -osbl 

nasm_32:
	$(CC) -Dunix_32 -m32 $(CCOPTS) -c osint/*.c
	$(BASEBOL)  -u unix_32 nasm/lex.sbl
	$(BASEBOL)  -r -u unix_32:$(ITOPT) -1=sbl.lex -2=sbl.tmp -3=sbl.err nasm/asm.sbl
	$(BASEBOL)  -u unix_32 -1=sbl.err -2=err.s nams/err.sbl
	cat sys.asm err.s sbl.tmp >sbl.s
	nasm -f elf32 -Dunix_32 -o sbl.o sbl.s
	$(CC) -lm -Dunix_32 -m32 $(LDOPTS)  *.o -lm  -osbl 

sclean:
# clean up after sanity-check
	make clean
	rm tbol*

test_osx:
# Do a sanity test on spitbol to  verify that spitbol is able to compile itself.
# This is done by building the system three times, and comparing the generated assembly (.s)
# filesbl. Normally, all three assembly files wil be equal. However, if a new optimization is
# being introduced, the first two may differ, but the second and third should always agree.
#
	rm -f tb*
	rm -f bld/*
	echo "start 64-bit sanity test"
	cp	./bin/sbl_osx_64 tbol
	gcc -Dosx_64 -m64 -c osint/*.c
	mv *.o bld
	./tbol -u osx_64_gas -1=sbl.asm -2=bld/sbl.lex -3=bld/sbl.equ lex.sbl
	./tbol -r -u osx_64_gas: -1=bld/sbl.lex -2=bld/sbl.tmp -3=bld/sbl.err -4=bld/sbl.equ gas/asm.sbl
	./tbol -u osx_64_gas -1=bld/sbl.err -2=bld/err.s err.sbl
	cat gas/osx.asm gas/sys.asm bld/err.s bld/sbl.tmp >bld/sbl.s
	as -o bld/sbl.o bld/sbl.s
	gcc -lm -Dosx_64 -m64 bld/*.o -lm  -osbl
	mv bld/sbl.lex	tbol.lex.0
	mv bld/sbl.s	tbol.s.0
	mv bld/err.s	tbol.err.s
	rm bld/sbl.*
	ls -l sbl tbol
	mv sbl tbol
	./tbol -u osx_64_gas -1=sbl.asm -2=bld/sbl.lex -3=bld/sbl.equ lex.sbl
	./tbol -r -u osx_64_gas: -1=bld/sbl.lex -2=bld/sbl.tmp -3=bld/sbl.err -4=bld/sbl.equ gas/asm.sbl
	./tbol -u osx_64_gas -1=bld/sbl.err -2=bld/err.s err.sbl
	cat gas/osx.asm gas/sys.asm bld/err.s bld/sbl.tmp >bld/sbl.s
	as -o bld/sbl.o bld/sbl.s
	gcc -lm -Dosx_64 -m64 bld/*.o -lm  -osbl
	mv bld/sbl.lex	tbol.lex.1
	mv bld/sbl.s	tbol.s.1
	mv bld/err.s	tbol.err.1
	ls -l sbl tbol
	mv sbl tbol
	rm bld/sbl.*
	./tbol -u osx_64_gas -1=sbl.asm -2=bld/sbl.lex -3=bld/sbl.equ lex.sbl
	./tbol -r -u osx_64_gas: -1=bld/sbl.lex -2=bld/sbl.tmp -3=bld/sbl.err -4=bld/sbl.equ gas/asm.sbl
	./tbol -u osx_64_gas -1=bld/sbl.err -2=bld/err.s err.sbl
	cat gas/osx.asm gas/sys.asm bld/err.s bld/sbl.tmp >bld/sbl.s
	./tbol 	<bld/sbl.s 	>bld/sbl.osx	gas/osx.sbl
	as -o bld/sbl.o bld/sbl.osx
	gcc -lm -Dosx_64 -m64 bld/*.o -lm  -osbl
	ls -l sbl tbol
	mv bld/sbl.lex	tbol.lex.2
	mv bld/sbl.s	tbol.s.2
	mv bld/err.s	tbol.err.2
	echo "comparing generated .s files"
	diff tbol.s.1 tbol.s.2
	echo "end sanity test"
test_nasm:
# Do a sanity test on spitbol to  verify that spitbol is able to compile itself.
# This is done by building the system three times, and comparing the generated assembly (.s)
# filesbl. Normally, all three assembly files wil be equal. However, if a new optimization is
# being introduced, the first two may differ, but the second and third should always agree.
#
	rm -f tb*
	rm -f bld/*
	echo "start 64-bit sanity test"
	cp	./bin/sbl_unix_64 tbol
	gcc -Dunix_64 -m64 -c osint/*.c
	mv *.o bld
	./tbol -u unix_64_nasm -1=sbl.asm -2=bld/sbl.lex -3=bld/sbl.equ lex.sbl
	./tbol -r -u unix_64: -1=bld/sbl.lex -2=bld/sbl.tmp -3=bld/sbl.err -4=bld/sbl.equ nasm/asm.sbl
	./tbol -u unix_64_nasm -1=bld/sbl.err -2=bld/err.s err.sbl
	cat nasm/sys.asm bld/err.s bld/sbl.tmp >bld/sbl.s
	nasm -f elf64 -Dunix_64 -o bld/sbl.o bld/sbl.s
	$(CC) -lm -Dunix_64 -m64 $(LDOPTS)  bld/*.o -lm  -osbl 
	mv bld/sbl.lex	tbol.lex.0
	mv bld/sbl.s	tbol.s.0
	mv bld/err.s	tbol.err.s
	rm bld/sbl.*
	ls -l sbl tbol
	mv sbl tbol
	./tbol -u unix_64_nasm -1=sbl.asm -2=bld/sbl.lex -3=bld/sbl.equ lex.sbl
	./tbol -r -u unix_64: -1=bld/sbl.lex -2=bld/sbl.tmp -3=bld/sbl.err -4=bld/sbl.equ nasm/asm.sbl
	./tbol -u unix_64_nasm -1=bld/sbl.err -2=bld/err.s err.sbl
	cat nasm/sys.asm bld/err.s bld/sbl.tmp >bld/sbl.s
	nasm -f elf64 -Dunix_64 -o bld/sbl.o bld/sbl.s
	$(CC) -lm -Dunix_64 -m64 $(LDOPTS)  bld/*.o -lm  -osbl 
	mv bld/sbl.lex	tbol.lex.1
	mv bld/sbl.s	tbol.s.1
	mv bld/err.s	tbol.err.1
	ls -l sbl tbol
	mv sbl tbol
	rm bld/sbl.*
	./tbol -u unix_64_nasm -1=sbl.asm -2=bld/sbl.lex -3=bld/sbl.equ lex.sbl
	./tbol -r -u unix_64: -1=bld/sbl.lex -2=bld/sbl.tmp -3=bld/sbl.err -4=bld/sbl.equ nasm/asm.sbl
	./tbol -u unix_64_nasm -1=bld/sbl.err -2=bld/err.s err.sbl
	cat nasm/sys.asm bld/err.s bld/sbl.tmp >bld/sbl.s
	nasm -f elf64 -Dunix_64 -o bld/sbl.o bld/sbl.s
	$(CC) -lm -Dunix_64 -m64 $(LDOPTS)  bld/*.o -lm  -osbl 
	ls -l sbl tbol
	mv bld/sbl.lex	tbol.lex.2
	mv bld/sbl.s	tbol.s.2
	mv bld/err.s	tbol.err.2
	echo "comparing generated .s files"
	diff tbol.s.1 tbol.s.2
	echo "end sanity test"
test_unix:
# Do a sanity test on spitbol to  verify that spitbol is able to compile itself.
# This is done by building the system three times, and comparing the generated assembly (.s)
# filesbl. Normally, all three assembly files wil be equal. However, if a new optimization is
# being introduced, the first two may differ, but the second and third should always agree.
#
	rm -f tb*
	rm -f bld/*
	echo "start 64-bit sanity test"
	cp	./bin/sbl_unix_64 tbol
	gcc -Dunix_64 -m64 -c osint/*.c
	mv *.o bld
	./tbol -u unix_64_gas -1=sbl.asm -2=bld/sbl.lex -3=bld/sbl.equ lex.sbl
	./tbol -r -u unix_64_gas: -1=bld/sbl.lex -2=bld/sbl.tmp -3=bld/sbl.err -4=bld/sbl.equ gas/asm.sbl
	./tbol -u unix_64_gas -1=bld/sbl.err -2=bld/err.s err.sbl
	cat gas/unix.asm gas/sys.asm bld/err.s bld/sbl.tmp >bld/sbl.s
	as -o bld/sbl.o bld/sbl.s
	gcc -lm -Dunix_64 -m64 bld/*.o -lm  -osbl
	mv bld/sbl.lex	tbol.lex.0
	mv bld/sbl.s	tbol.s.0
	mv bld/err.s	tbol.err.s
	rm bld/sbl.*
	ls -l sbl tbol
	mv sbl tbol
	./tbol -u unix_64_gas -1=sbl.asm -2=bld/sbl.lex -3=bld/sbl.equ lex.sbl
	./tbol -r -u unix_64_gas: -1=bld/sbl.lex -2=bld/sbl.tmp -3=bld/sbl.err -4=bld/sbl.equ gas/asm.sbl
	./tbol -u unix_64_gas -1=bld/sbl.err -2=bld/err.s err.sbl
	cat gas/unix.asm gas/sys.asm bld/err.s bld/sbl.tmp >bld/sbl.s
	as -o bld/sbl.o bld/sbl.s
	gcc -lm -Dunix_64 -m64 bld/*.o -lm  -osbl
	mv bld/sbl.lex	tbol.lex.1
	mv bld/sbl.s	tbol.s.1
	mv bld/err.s	tbol.err.1
	ls -l sbl tbol
	mv sbl tbol
	rm bld/sbl.*
	./tbol -u unix_64_gas -1=sbl.asm -2=bld/sbl.lex -3=bld/sbl.equ lex.sbl
	./tbol -r -u unix_64_gas: -1=bld/sbl.lex -2=bld/sbl.tmp -3=bld/sbl.err -4=bld/sbl.equ gas/asm.sbl
	./tbol -u unix_64_gas -1=bld/sbl.err -2=bld/err.s err.sbl
	cat gas/unix.asm gas/sys.asm bld/err.s bld/sbl.tmp >bld/sbl.s
	as -o bld/sbl.o bld/sbl.s
	gcc -lm -Dunix_64 -m64 bld/*.o -lm  -osbl
	ls -l sbl tbol
	mv bld/sbl.lex	tbol.lex.2
	mv bld/sbl.s	tbol.s.2
	mv bld/err.s	tbol.err.2
	echo "comparing generated .s files"
	diff tbol.s.1 tbol.s.2
	echo "end sanity test"

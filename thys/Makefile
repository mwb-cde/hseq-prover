
###
# Variables
###

# SUBDIRS: The sub-directories to build (in order)
SUBDIRS =

# BUILDSCRIPT: The name of the build script
BUILDSCRIPT = buildall.ml

# HSEQ: The name of the theorem prover executable
HSEQ=hseq

# HSEQLIB: The include directory for ${HSEQ} (before installation and 
# relative to the src directory).
HSEQLIB=lib

####
# Don't modify anything below this line
####

##
# Constants
##

# CONFIGDIR: The configuration directory
CONFIGDIR ?= ../config

# CONFIGFILE: Configuration data file 
CONFIGFILE = ${CONFIGDIR}/data.make

# SUBCONFIGDIR: The configuration directory for sub-directories
# (relative to a subdirectory)
SUBCONFIGDIR ?= ../config

# SRCDIR: The source directory
SRCDIR ?= ../src

# LIBDIR: The location of the compiled files
LIBDIR ?= ${SRCDIR}/lib

###
# Configuration variables
# Set by data.make
###

# Read from ${CONFIGFILE}
ifdef CONFIGFILE
include $(CONFIGFILE)
endif

# Variables which are set in ${CONFIGFILE}
Bin ?= 
Prefix ?= 
BinDir ?= 
BaseDir ?= 
IncludeDir ?= 
LibDir ?= 
ThyDir ?= 

# IPREFIX: The installation prefix
IPREFIX = $(strip ${Prefix})

# IBASEDIR: Installation directory
IBASEDIR = $(BaseDir)

# ITHYDIR: Theories installation directory
ITHYDIR = $(ThyDir)

# IDOCDIR: The documentation installation directory
IDOCDIR ?= $(IBASEDIR)/doc

# HTMLDIR: HTML Documentation directory
HTMLDIR ?= $(IDOCDIR)/html

# INFODIR: Info Documentation directory
INFODIR ?= $(IDOCDIR)/info

##
# Build commands
##

# BAREMAKE: The make with not options
BAREMAKE = $(MAKE)

# DMAKE: The make to build sub-directories with.
DMAKE = $(MAKE) SUBCONFIGDIR='${CONFIGDIR}'

# MAKECLEAN: The make to clean up with
MAKECLEAN = $(MAKE) NODEPEND=true SUBCONFIGDIR='${CONFIGDIR}'

###
# Compiler definitions
###

##
# Variables
##

# INCLUDE: The include directives
INCLUDE = -I $(LIBDIR) -I $(SRCDIR)

# OPTIONS: Compiler options
OPTIONS = $(INCLUDE)

# HSEQC: The hseq compiler
HSEQC = $(SRCDIR)/$(HSEQ) $(INCLUDE)

###
# Required build targets
###

# all: Build everything
all: thys

#doc: Buld documentation
doc:

#install: Install everything
install: install-thys

###
# Clean up
###

.PHONY: clean
clean: 
	rm -f *~
	$(foreach subdir, $(SUBDIRS), $(MAKECLEAN) -C $(subdir) clean; )

.PHONY: reallyclean
reallyclean: clean
	rm -f *.tho *.cmo *.cmi
	$(foreach subdir, $(SUBDIRS), $(MAKECLEAN) -C $(subdir) reallyclean; )

###
# Specialized targets
###

.PHONY: thys
thys:
#	$(HSEQC) $(BUILDSCRIPT) 
	echo "#use \"$(BUILDSCRIPT)\";;" | $(HSEQC)

.PHONY: install-thys
install-thys: thys
	-mkdir $(ITHYDIR)
	-cp -Rf *.tho *Script.ml *.cmi *.cmo $(ITHYDIR)
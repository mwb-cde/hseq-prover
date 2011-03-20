########################################################## --*- Makefile -*--
# Makefile.module - Makefile to build modules
# Copyright 11 March, 2011, Matthew Wahab <mwb.cde@gmail.com>
#
# Released under the Lesser GPLv3 license:
# ========================================
# This file is part of HSeq.
#
# HSeq is free software; you can redistribute it and/or modify it
# under the terms of the Lesser GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.
#
# HSeq is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the Lesser GNU General Public
# License for more details.
#
# You should have received a copy of the Lesser GNU General Public
# License along with HSeq.  If not see <http://www.gnu.org/licenses/>.
######################################################################

#####
# Definitions and rules for building modules.
#
# REQUIREMENTS
# ------------
#
# Must set PROJ_ROOT.
# PROJ_ROOT: Variable containing relative path to top of the source tree.
#
# Must end with 
#    include $(PROJ_ROOT)/Makefile.common
#
#
# Variables:
# ----------
#
# Module settings:
# 
# SUBDIRS: List of sub-directories to recurse into.
# LIBRARIES: List of libraries to build.
# PROGRAMS: List of programs to build.
#
# MODULE_INST_PATH: PATH to append to the relative installation path.
# MODULE_USE_OBJDIR [yes/no]: Whether to use the staging directory.
# MODULE_OCAMLC_FLAGS: Flags to pass to the compiler for [object].
# MODULE_OCAMLPP_FLAGS: Flags to pass to the preprocessor for [object].
# MODULE_LINK_FLAGS: Flags to pass to the linker for [object].
# MODULE_OBJ_PATH: PATH to append to the staging directory path.
# MODULE_INST_PATH: PATH to append to the relative installation path.
#
# For each program or library [object] listed in LIBRARIES or PROGRAMS:
#
# object_SOURCES: List of source file names, without suffixes.
# object_INCLUDE: Directories to include when compiling [object].
# object_LIBS: Libraries to include when linking [object].
# object_BYTELIBS: Libraries to include when byte-code linking [object].
# object_NATLIBS: Libraries to include when native-code linking [object].
# object_OCAMLC_FLAGS: Flags to pass to the compiler for [object].
# object_LINK_FLAGS: Flags to pass to the linker for [object].
# object_INST_PATH: PATH to append to the relative installation path.
#
# Inherited variables:
#
# GLOBAL_OCAMLC_FLAGS: Flags to pass to the compiler for [object].
# GLOBAL_OCAMLPP_FLAGS: Flags to pass to the preprocessor for [object].
# GLOBAL_LINK_FLAGS: Flags to pass to the linker for [object].
# GLOBAL_OBJ_PATH: PATH staging directory path.
# GLOBAL_INST_PATH: PATH installation path.
#
# Other variales
# LOCAL_OCAMLC_FLAGS: Actual flags to pass to the compiler for [object].
# LOCAL_OCAMLPP_FLAGS: flags to pass to the preprocessor for [object].
# LOCAL_LINK_FLAGS: Flags to pass to the linker for [object].
#
# Notes:
#
# The flags for each tool X are formed as 
#    (LOCAL_X_FLAGS) (object_X_FLAGS)
#
# If LOCAL_X_FLAGS is not defined, it defaults to
#    LOCAL_X_FLAGS = (GLOBAL_X_FLAGS) (MODULE_X_FLAGS) 
#
# The global flags for X passed to each sub-directory is
#     (LOCAL_X_FLAGS)
#
# An object will be installed into the directory formed by 
#      $(INST_PATH)/$(MODULE_INST_PATH)/$(OBJECT_INST_PATH)
#
#####

#####
# Required definitions
#  

# PROJ_ROOT: Relative path to HSeq root.
PROJ_ROOT=../..

#####
# Module building settings
#

# SUBDIRS: List of sub-directories to build.
#SUBDIRS=

# LIBRARIES: List of libraries to build.
#LIBRARIES=

# PROGRAMS: List of programs to build.
PROGRAMS=hseq

##
# Building packed libraries (with option -pack) is complicated by the
# ocaml compiler requiring that all objects making up the packed
# library, together with their interfaces, must be in the same
# directory. The native-code compilers also require that a objects
# that is to be combined into a pack must be compiled with the
# -for-pack option. 
#
# To support packing, the build system allows a 'packed' library L to
# be constructed from 'packing' objects O, with 'pack name' P. The
# packing objects are built as 'groups', with each group G built in
# sub-directory G, and marshalled into a packing directory named
# P_PACK_DIR where the packed object P.cmo and its interface P.cmi are
# built and linked to construt packed library L.

# PACKED: List of packed libraries to build
#PACKED=

# PACKING: List of packing groups to build
#PACKING=

#####
# Sub-directory building options

# SUBDIR_MAKE_OPTIONS: Options to pass to the sub-directory make.
#SUBDIR_MAKE_OPTIONS=

#####
# Object building settings
#

# Rule for building hseq toplevel is:
#    ocamlmktop -custom -I ./obj/lib -I +camlp4 nums.cma unix.cma dynlink.cma camlp4o.cma -o hseq hseq.cma tpquote.cma hseqtop.cma

# object_SOURCES: List of source file names, without suffixes.
#object_SOURCES=

# object_HEADERS: List of headers, without suffixes. Default is object_SOURCES
#object_HEADERS=$(object_SOURCES)

# object_INCLUDE: Directories to include when compiling [object].
#object_INCLUDE=
hseq_INCLUDE=+camlp4

# object_LIBS: Libraries to include when linking [object].
#object_LIBS=
hseq_LIBS=nums.cma unix.cma dynlink.cma camlp4o.cma hseq.cma tpquote.cma hseqtop.cma

# object_PACK_NAME: Name of pack to build
#object_PACK_NAME=

# object_PACK_DIR: Directory to use for packing.
#object_PACK_DIR=

# object_GROUPS: List of packing groups to use for packed library [object]
#object_GROUPS=

# object_OCAMLC_FLAGS: Flags to pass to the compiler for [object].
#object_OCAMLC_FLAGS=

# object_OCAMLPP_FLAGS: Flags to pass to the preprocessor for [object].
#object_OCAMLPP_FLAGS=

# object_LINK_FLAGS: Flags to pass to the linker for [object].
#object_LINK_FLAGS=

# object_INST_PATH: PATH to append to the relative installation path.
#object_INST_PATH=

#####
# Module build tool settings

# MODULE_OBJ_PATH: PATH to append to the staging directory path for
# this module and all its sub-directories.
#MODULE_OBJ_PATH=

# MODULE_USE_OBJDIR [yes/no]: Whether to use the staging directory.
#MODULE_USE_OBJDIR=no

# MODULE_OCAMLC_FLAGS: Flags to pass to the compiler for [object].
#MODULE_OCAMLC_FLAGS=

# MODULE_OCAMLPP_FLAGS: Flags to pass to the pre-processor for [object].
#MODULE_OCAMLPP_FLAGS=

# MODULE_OCAMLCPP_FLAGS: Flags to pass to the macro-expander.
#MODULE_OCAMLCPP_FLAGS=

# MODULE_LINK_FLAGS: Flags to pass to the linker for [object].
#MODULE_LINK_FLAGS=

###
# Installation options
# (Defaults if undefined are as given.)

# INSTALL_LIBRARIES: Libraries to install
#INSTALL_LIBRARIES=<all built libraries>

# INSTALL_PROGRAMS: Programs to install
#INSTALL_PROGRAMS=<all built programs>

# INSTALL_HEADERS: Headers to install
#INSTALL_HEADERS=<all .mli files and all built .cmi files>

# INSTALL_EXTRA_LIBRARIES: Additional files to install with the
# libraries. Extra headers belong in this list.
#INSTALL_EXTRA_LIBRARIES=

# INSTALL_EXTRA_PROGRAMS: Additional files to install with the programs.
#INSTALL_EXTRA_PROGRAMS=

# INSTALL_EXTRA_DATA: Additional files to install with the built data.
#INSTALL_EXTRA_DATA=

###
# Makefile commands

# EXTRA_CLEAN: Command to add to the clean target.
EXTRA_CLEAN=$(RM) hseq

# EXTRA_LIBCLEAN: Command to add to the clean target.
#EXTRA_LIBCLEAN=

# EXTRA_DISTCLEAN: Command to add to the clean target.
#EXTRA_DISTCLEAN=

# Use a custom build target
# CUSTOM_TARGET_build: If defined, use a custom build target.
#CUSTOM_TARGET_build=yes

hseq_CUSTOM_BUILD=yes
hseq:
	ocamlmktop -custom -I $(OBJ_ROOT)/lib -I +camlp4 \
		nums.cma unix.cma dynlink.cma camlp4o.cma \
		-o hseq \
		hseq.cma tpquote.cma hseqtop.cma





######################################################################
# DO NOT CHANGE ANYTHING BELOW THIS LINE
######################################################################

###
# Include common definitions

# Test for PROJ_ROOT being defined.
ifndef PROJ_ROOT
$(error "PROJ_ROOT Must be set to relative path to HSeq root")
endif

include $(PROJ_ROOT)/Makefile.rules


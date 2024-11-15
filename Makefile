########################################################## --*- Makefile -*--
# Copyright (c) 2011-2021 Matthew Wahab <mwb.cde@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
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
PROJ_ROOT=.

#####
# Module building settings
#

# SUBDIRS: List of sub-directories to build.
SUBDIRS=hseq hsequser tools thys doc

# LIBRARIES: List of libraries to build.
#LIBRARIES=

# PROGRAMS: List of programs to build.
#PROGRAMS=

#####
# Object building settings
#

# object_SOURCES: List of source file names, without suffixes.
#object_SOURCES=

# object_INCLUDE: Directories to include when compiling [object].
#object_INCLUDE=

# object_LIBS: Libraries to include when linking [object].
#object_LIBS=

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

# MODULE_OCAMLC_FLAGS: Flags to pass to the compiler for [object].
#MODULE_OCAMLC_FLAGS=

# MODULE_OCAMLPP_FLAGS: Flags to pass to the pre-processor for [object].
#MODULE_OCAMLPP_FLAGS=

# MODULE_LINK_FLAGS: Flags to pass to the linker for [object].
#MODULE_LINK_FLAGS=

#####
# Default settings

# LOCAL_OCAMLC_FLAGS: Flags to pass to the compiler for [object].
#LOCAL_OCAMLC_FLAGS=$(GLOBAL_OCAMLC_FLAGS) $(MODULE_OCAMLC_FLAGS)

# LOCAL_OCAMLPP_FLAGS: Flags to pass to the pre-processor for [object].
#LOCAL_OCAMLPP_FLAGS=$(GLOBAL_OCAMLPP_FLAGS) $(MODULE_OCAMLPP_FLAGS)

# LOCAL_LINK_FLAGS: Flags to pass to the linker for [object].
#LOCAL_LINK_FLAGS=$(GLOBAL_LINK_FLAGS) $(MODULE_LINK_FLAGS)

#####
# Extra settings

#GLOBAL_OCAMLC_FLAGS=-g

###
# Installation options
# (Defaults if undefined are as given.)

# INSTALL_LIBRARIES: Libraries to install
#INSTALL_LIBRARIES=<all built libraries>

# INSTALL_PROGRAMS: Programs to install
#INSTALL_PROGRAMS=<all built programs>

# INSTALL_HEADERS: Headers to install
#INSTALL_HEADERS=<all .mli files and all built .cmi files>

###
# Makefile commands

# EXTRA_CLEAN: Command to add to the clean target.
#EXTRA_CLEAN=$(RM) -rf $(PROJ_ROOT)/$(OBJ_DIR)

# EXTRA_LIBCLEAN: Command to add to the clean target.
#EXTRA_LIBCLEAN=

# EXTRA_DISTCLEAN: Command to add to the clean target.
EXTRA_DISTCLEAN=$(RM) config.make config.mli config.ml

#####
# Sub-directory building options

# SUBDIR_MAKE_OPTIONS: Options to pass to the sub-directory make.
SUBDIR_MAKE_OPTIONS=

####
# Installation targets

# Default target
.PHONY: toplevel_target
toplevel_target: all

# CUSTOM_TARGET_install: If defined, use a custom install target.
CUSTOM_TARGET_install=

all: build


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

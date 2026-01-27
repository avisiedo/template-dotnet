##
# Small file which only assign the path of the project by
# reading the absolute path for the main Makefile.
##
# SPDX-License-Identifier: APACHE-2
# From: https://github.com/podengo-project
PROJECT_DIR := $(shell dirname $(abspath $(firstword $(MAKEFILE_LIST))))

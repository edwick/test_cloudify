#!/usr/bin/env bash

# Utility script for testing, to clean up resources.

TEMP_DIR=${HOME}/tempdir

cd ${TEMP_DIR}

/bin/rm -f ${TEMP_DIR}/*

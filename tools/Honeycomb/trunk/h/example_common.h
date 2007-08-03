/*
 * $Id: example_common.h 8089 2006-04-26 22:27:42Z sp198635 $
 *
 * Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

/* Common definitions for the StorageTek 5800 C API examples */

#ifndef _EXAMPLE_COMMON
#define _EXAMPLE_COMMON

#include <stdio.h>

/* StorageTek 5800 header files */
#include "hc.h"
#include "hcclient.h"

/* Application constants */
#define ERRSTR_LEN 4096
#define MAX_LINESIZE 5000

#ifdef O_BINARY
#define FLAG_BINARY O_BINARY
#else
#define FLAG_BINARY 0
#endif

#ifdef    O_LARGEFILE
#define    FLAG_LARGEFILE  O_LARGEFILE
#else
#define FLAG_LARGEFILE 0
#endif

static const int STORAGETEK_PORT = 8080;

static const int RETURN_SUCCESS = 0;
static const int RETURN_COMMANDLINE_ERROR = 1;
static const int RETURN_MAPERROR = 2;
static const int RETURN_IOERROR = 3;
static const int RETURN_MAPINITERROR = 4;
static const int RETURN_STORAGETEK_ERROR = 5;

static const int DEFAULT_MAX_RESULTS = 1000;

void HandleError(hc_session_t *session, hcerr_t res);

#endif

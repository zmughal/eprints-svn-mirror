/*
 * $Id: example_commandline.h 8089 2006-04-26 22:27:42Z sp198635 $
 *
 * Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

/* parseCommandline handles commandline parsing for the StorageTek 5800 C */
/* API examples. */

#ifndef _EXAMPLE_COMMANDLINE
#define _EXAMPLE_COMMANDLINE

#include "example_common.h"
#include "example_metadata.h"

static const int USES_SERVERADDRESS = 1;
static const int USES_METADATA_FILENAME = 2;
static const int USES_QUERY = 4;
static const int USES_LOCAL_FILENAME = 8;
static const int USES_OID = 16;
static const int USES_VERBOSE = 32;
static const int USES_MAXRESULTS = 64;
static const int USES_SELECT_METADATA = 128;
static const int USES_CMDLINE_METADATA = 256;

/* Contains the information extracted from the command line */
struct Commandline
{
        char *storagetekServerAddress;
        char *metadataFilename;
        char *query;
        char *localFilename;
        char oid[57];
        int verbose;
        int maxResults;
        int outputMetadata;
        int help;
	int debug_flags;
        struct MetadataMap cmdlineMetadata;
};      /* struct Commandline */

struct Commandline cmdLine;

extern int parseCommandline(	int argc,
       		                char* argv[],
				int acceptedParameters);

#endif

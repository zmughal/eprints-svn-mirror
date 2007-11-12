/*
 * $Id: example_commandline.h 10856 2007-05-19 02:58:52Z bberndt $
 *
 * Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

/* parseCommandline handles commandline parsing for the 5800 system C */
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
	int  storagetekPort;
        char *metadataFilename;
        char *query;
        char *localFilename;
        char oid[61];
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

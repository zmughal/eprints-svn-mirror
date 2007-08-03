/*
 * $Id: example_commandline.c 8046 2006-04-25 00:36:28Z sp198635 $
 *
 * Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "example_commandline.h"

/* Commandline switch character */
const char *SWITCH_CHARACTER_LIST = "-\0";
static char METADATA_SEPERATOR_CHARACTERS[] = "=";

/* Commandline switches */
static const char *PARAMETERLESS_SWITCHES = "hv";
static const char *PARAMETER_SWITCHES = "fmrsd";

int verifyCommandline(int acceptedParameters);
int parseCommandlineParameter(	int onSwitch,
				char* currentSwitch,
				char* currentArgument,
				int acceptedParameters);

/* parseCommandline handles all commandline parsing for the examples. */
/* The results are stored in an instance of the cmdLine structure. */
int parseCommandline(	int argc, 
			char* argv[],
			int acceptedParameters)
{
	int onSwitch = 0;
	char *currentSwitch = 0;
	char *currentArgument = 0;

	/* Loop through all commandline arguments */
	int currentArgumentNumber = 1;
	for (currentArgumentNumber = 1; currentArgumentNumber <= argc; ++currentArgumentNumber)
	{
		currentArgument = argv[currentArgumentNumber];
		if (currentArgument == NULL)
		{
			break;
		}	/* if no current argument */

		/* If we are on a switch */
		if (strrchr(SWITCH_CHARACTER_LIST, *currentArgument) != NULL)
		{
			/* If we are already on a switch, process that switch with an empty argument */
			++currentArgument;
			if (strrchr(PARAMETERLESS_SWITCHES, *currentArgument))
			{
				int result = parseCommandlineParameter(1, currentArgument, 0, acceptedParameters);
				if (result != 1)
				{
					printf("Invalid commandline argument: %s\n", currentArgument);
					return result;
				}	/* if parse failed */
			}	/* if on switch */
			else if (strrchr(PARAMETER_SWITCHES, *currentArgument))
			{
				/* Make this switch the current switch */
				currentSwitch = currentArgument;
				onSwitch = 1;
			}   /* else not on switch */
			else
			{
				return 0;
			}   /* else invalid parameter */
		}	/* if this is a switch */
		else
		{
			/* Process current switch with the current command line argument */
			int result = parseCommandlineParameter(onSwitch, currentSwitch, currentArgument, acceptedParameters);
			if (result != 1)
			{
				printf("Invalid commandline arguments:");
				if (currentSwitch != NULL)
				{
					printf(" %s", currentSwitch);
				}
				if (currentArgument != NULL)
				{
					printf(" %s", currentArgument);
				}
				printf("\n");
				return result;
			}	/* if parse failed */
			onSwitch = 0;
		}	/* else this is not a switch */
	}	/* loop through command line argument list */

	return verifyCommandline(acceptedParameters);
}	/* parseCommandline */

int verifyCommandline(int acceptedParameters)
{
	if (cmdLine.help == 1)
	{
		return 1;
	}
	if ((acceptedParameters & USES_OID) && (*cmdLine.oid == 0))
	{
		return 0;
	}
        if ((acceptedParameters & USES_LOCAL_FILENAME) && (cmdLine.localFilename == NULL))
        {
                return 0;
        }
        if ((acceptedParameters & USES_SERVERADDRESS) && (cmdLine.storagetekServerAddress == NULL))
        {
                return 0;
        }
        if ((acceptedParameters & USES_QUERY) && (cmdLine.query == NULL))
        {
                return 0;
        }

	return 1;
}	/* verifyCommandline */

int parseCommandlineParameter(  int onSwitch,
                                char* currentSwitch,
                                char* currentArgument,
				int acceptedParameters)
{
        if (onSwitch == 1)
        {
                switch(*currentSwitch)
                {
                        /* m switch is for adding metadata from the commandline */
                        case 'm':
				if ((acceptedParameters & USES_CMDLINE_METADATA) == 0)
				{
					return 0;
				}

                                if (currentArgument != NULL)
                                {
                                        /* Extract the name-value metadata pair from the current */
                                        /* commandline argument. */
                                        char *name = strtok(currentArgument, METADATA_SEPERATOR_CHARACTERS);
                                        if (name != NULL)
                                        {
                                                char *value = strtok(NULL, METADATA_SEPERATOR_CHARACTERS);
                                                if (value != NULL)
                                                {
                                                        addToMetadataMap(&cmdLine.cmdlineMetadata, name, value);
                                                }       /* if value not null */
                                                else
                                                {
                                                        return 0;
                                                }       /* else value null */
                                        }       /* if name not null */
                                        else
                                        {
                                                return 0;
                                        }       /* if name null */

                                        break;
                                }       /* if currentArgument not NULL */
                                else
                                {
                                        return 0;
                                }       /* else currentArgument NULL */

                       	/* s switch is to define the select clause for query plus */
                       	case 's':
				if ((acceptedParameters & USES_SELECT_METADATA) == 0)
				{
					return 0;
				}

                                if (currentArgument != NULL)
                                {
					addToMetadataMap(&cmdLine.cmdlineMetadata, currentArgument, currentArgument);
				}
                                else
                                {
                                	return 0;
                                }       /* else currentArgument NULL */
                                break;

                        /* r specifies the max results */
                        case 'r':
				if ((acceptedParameters & USES_MAXRESULTS) == 0)
				{
					return 0;
				}

                                if (currentArgument != NULL)
                                {
                                        char **nextChar = NULL;
                                        int maxNumberOfResults = strtol(currentArgument, nextChar, 10);

                                        /* nextChar should be the null terminator unless strtol encountered */
                                        /* a character it could not convert. */
                                        if ((nextChar != NULL) && (*nextChar != 0))
                                        {
                                                return 0;
                                        }       /* if next character is not null */

                                        cmdLine.maxResults = maxNumberOfResults;
                                }
                                break;
		 	
			/* Verbose */
            		case 'v':
				if ((acceptedParameters & USES_VERBOSE) == 0)
				{	
					return 0;
				}

                		cmdLine.verbose = 1;
                		break;
                       
			 /* h or anything else for help */
                        case 'h':
                                cmdLine.help = 1;
                                break;
                       	
			/* d switch is for "internal debug flags */
			case 'd':
				if (currentArgument != NULL)
				{
					cmdLine.debug_flags = atoi(currentArgument);
				}
				else
				{
					return 0;
				}
				break;

		 	default:
                                cmdLine.help = 1;
                                return 0;
                }       /* switch currentSwitch */
        }       /* if on a switch */
        else
        {
		if (currentArgument != NULL)
		{
			if ((acceptedParameters & USES_SERVERADDRESS) && (cmdLine.storagetekServerAddress == NULL))
			{
				cmdLine.storagetekServerAddress = currentArgument;	
			}
			else if ((acceptedParameters & USES_OID) && (*cmdLine.oid == 0))
			{
				strcpy(cmdLine.oid, currentArgument);
			}
			else if ((acceptedParameters & USES_LOCAL_FILENAME) && (cmdLine.localFilename == NULL))
			{
				cmdLine.localFilename = currentArgument;
			}
			else if ((acceptedParameters & USES_QUERY) && (cmdLine.query == NULL))
			{
				cmdLine.query = currentArgument;
			}
			else
			{
				return 0;
			}
		}  	/* if currentArgument not null */
		else
		{
			return 0;
		}  	/* else currentArgument null */
	}	/* else not on switch */

	return 1;
}	/* parseCommandlineParameter */

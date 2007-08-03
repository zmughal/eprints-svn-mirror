/*
 * $Id: example_metadata.h 8089 2006-04-26 22:27:42Z sp198635 $
 *
 * Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

/* example_metadata contains a group of helper functions for the */
/* StorageTek 5800 C API examples.  These functions work with a */
/* metadata memory map that dynamically allocates memory for the */
/* name/value pairs of metadata.  They also keep pointer arrays	*/
/* that point to all the metadata names and metadata values.  These */
/* pointer arrays are passed in to the StorageTek 5800 API calls that */
/* take metadata. */

#ifndef _EXAMPLE_METADATA
#define _EXAMPLE_METADATA

/* Metadata map constants */
static const int INITIAL_METADATA_NAME_SIZE = 10000;
static const int INITIAL_METADATA_VALUE_SIZE = 20000;
static const int METADATA_NAME_GROW_SIZE = 10000;
static const int METADATA_VALUE_GROW_SIZE = 20000;

static const int INITIAL_METADATA_MAP_CAPACITY = 20;
static const int METADATA_MAP_GROW_SIZE = 20;

/* structure describing the dynamically allocated metadata map */
struct MetadataMap
{
	char *mappedName;			/* pointer to the memory allocated for metadata names */
	char *mappedValue;			/* pointer to the memory allocated for metadata valuse */
	int nameSize;				/* number of character the name memory blob currently holds */
	int nameCapacity;			/* the maximum number of character the name memory blob can hold */
	int valueSize;				/* number of character the value memory blob currently holds */
	int valueCapacity;			/* the maximum number of character the value memory blob can hold */
	int mapSize;				/* number of name/value pairs the map currently holds */
	int mapCapacity;
	
	char **namePointerArray;		/* an array of pointers that point to all the names in the map */
	char **valuePointerArray;		/* an array of pointers that point to all the values in the map */
};

/* Metadata map external functions */
extern int initMetadataMap(struct MetadataMap *mdm);
extern int destroyMetadataMap(struct MetadataMap *mdm);
extern int addToMetadataMap(struct MetadataMap *mdm, const char* name, const char* value);
extern int getFromMetadataMap(struct MetadataMap *mdm, int position, char* name, char* value);

/* General metadata external functions */
extern int printMetadataRecord(char **names, char **values, int numberOfRecords);

#endif

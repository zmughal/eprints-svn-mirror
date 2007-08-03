/**
 * $Id$
 *
 * Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 *
 *
 * Honeycomb EZ API		
 *
 * The API contained in this header file provides syncronous access to
 * Honeycomb.  You must call hc_init() and hc_session_create_ez()
 * prior to making any other API calls.  The API calls include
 * operations for storing, retreiving, deleting, and querying of data
 * and metadata records. 
 *
 *
 * hc_init (see hc.h) - global initialize (once per process)
 *
 * hc_session_create_ez (once per thread)
 *      Initialize Honeycomb API and downloads the schema and
 *	multicell info for a particular host/port.   Must be called
 *	before other operations. 
 *
 * hc_session_free
 *      Cleanup handles and memory for one connection.
 * 
 * hc_store_both_ez
 *	    Add Metadata Record and associated data.  Returns a system_record.
 *
 * hc_store_metadata_ez
 *	    Add Metadata Record for specified OID. Return a system_record.
 *
 * hc_retrieve_metadata_ez
 *	    Retrieve Metadata Record for specified OID.
 *
 * hc_retrieve_ez
 *	    Retrieve data given an OID.
 *
 * hc_query_ez
 *	    Retrieve OIDs for Metadata Records matching a query.
 *
 * hc_query_plus_ez
 *	    Retrieve specified values for Metadata Records matching a query. 
 *
 * hc_delete_ez
 *	    Delete the metadata record given by an OID.  The
 *	    underlying data object is implicitly deleted when all metadata
 *	    records that link to it have been deleted. 
 */

#ifndef __HCCLIENT__
#define __HCCLIENT__

#include "hc.h"

#ifdef __cplusplus
extern "C" {
#endif 

/* hc nvoa typedefs */

typedef enum hc_types_{
  HC_UNKNOWN_TYPE = -1,
  HC_BOGUS_TYPE = 0,
  HC_STRING_TYPE = 1,
  HC_LONG_TYPE = 2, 
  HC_DOUBLE_TYPE = 3,
  HC_BYTE_TYPE = 4
} hc_type_t;

typedef struct hc_value_ {
  hc_type_t	hcv_type;
  union {
    hc_long_t	hcv_long;
    hc_string_t	hcv_string;
    hc_double_t	hcv_double;
    hc_byte_t	hcv_byte;
  } hcv;
} hc_value_t;
#define	HC_EMPTY_VALUE_INIT {0,{0}}

/* schema -- describes the data map.   Downloaded from the server
   periodically. */
typedef void hc_schema_t;

/* Session */
/* Structure describing the connection from one thread to one
   Honeycomb silo. */ 
 typedef void hc_session_t; 


/* Name-Value Record. */
/* structure describing the dynamically allocated metadata map */
typedef void hc_nvr_t;

/* Query ResultSet */
/* structure to fetch results from an OID Query */
typedef void hc_query_result_set_t;

/* QueryPlus ResultSet */
/* structure to fetch results from a Metadata QueryPlus */
typedef void hc_query_plus_result_set_t;

/* UniqueValues ResultSet */
/* structure to fetch results from a UniqueValues query */
typedef void hc_unique_values_result_set_t;

/*****************************************/
/* SESSION */

HONEYCOMB_EXTERN hcerr_t hc_session_create_ez (char* host, int port, hc_session_t **sessionp);
HONEYCOMB_EXTERN hcerr_t hc_session_free (hc_session_t *session);
HONEYCOMB_EXTERN hcerr_t hc_session_get_schema (hc_session_t *session, hc_schema_t **schemap);
HONEYCOMB_EXTERN hcerr_t hc_session_get_status (hc_session_t *session, int32_t *responsep,char **errstrp);
HONEYCOMB_EXTERN hcerr_t hc_session_get_host (hc_session_t *session, char **hostp, int *portp);
HONEYCOMB_EXTERN hcerr_t hc_session_get_archive (hc_session_t *session, hc_archive_t **archivep);
HONEYCOMB_EXTERN hcerr_t hc_session_get_platform_result(hc_session_t *session, int32_t *connect_errnop, int32_t *platform_resultp);

/*****************************************/
/* STORE */

HONEYCOMB_EXTERN hcerr_t hc_store_both_ez(hc_session_t *session,
					  read_from_data_source data_source_reader, void *cookie,
					  hc_nvr_t *nvr,
					  hc_system_record_t *system_record);

HONEYCOMB_EXTERN hcerr_t hc_store_metadata_ez(hc_session_t *session,
					      hc_oid *oid,
					      hc_nvr_t *nvr,
					      hc_system_record_t *system_record);

/*****************************************/
/* RETRIEVE */

HONEYCOMB_EXTERN hcerr_t hc_retrieve_metadata_ez (hc_session_t *session,
						  hc_oid *oid, 
						  hc_nvr_t **nvrpp);

HONEYCOMB_EXTERN hcerr_t hc_retrieve_ez(hc_session_t *session,
                                        write_to_data_destination data_writer, void *cookie,
                                        hc_oid* oid);

HONEYCOMB_EXTERN hcerr_t hc_range_retrieve_ez(hc_session_t *session,
					      write_to_data_destination data_writer, void *cookie,
					      hc_oid* oid,
					      hc_long_t firstbyte, hc_long_t lastbyte);

/*****************************************/
/* QUERY - Return OID */

HONEYCOMB_EXTERN hcerr_t hc_query_ez(hc_session_t *session,
				     char* query_string,
				     hc_query_result_set_t **rsetp);

HONEYCOMB_EXTERN hcerr_t hc_qrs_next_ez(hc_query_result_set_t *rset, hc_oid *oid, int *finishedp);
HONEYCOMB_EXTERN hcerr_t hc_qrs_free(hc_query_result_set_t *rsetp);

/*****************************************/
/* QUERY PLUS - return OID plus selected Metadata */

HONEYCOMB_EXTERN hcerr_t hc_query_plus_ez (hc_session_t *session,
					   char* query_string,
					   char* selects[],
					   int n_selects,
					   hc_query_plus_result_set_t **rsetp);
HONEYCOMB_EXTERN hcerr_t hc_qprs_next_ez(hc_query_plus_result_set_t *rset, hc_nvr_t **nvrp, int *finished);
HONEYCOMB_EXTERN hcerr_t hc_qprs_free(hc_query_plus_result_set_t *rsetp);

/*****************************************/

/* UNIQUE VALUES - return unique values of Metadata */
HONEYCOMB_EXTERN hcerr_t hc_unique_values_ez(hc_session_t *session,
					     char* query_string, char* key,
					     hc_unique_values_result_set_t **rsetp);
HONEYCOMB_EXTERN hcerr_t hc_uvrs_next_ez(hc_unique_values_result_set_t *rset, hc_value_t *valuep, int *finishedp);
HONEYCOMB_EXTERN hcerr_t hc_uvrs_free(hc_unique_values_result_set_t *rset);


/*****************************************/
/* DELETE */
 
HONEYCOMB_EXTERN hcerr_t hc_delete_ez(hc_session_t *session,
				      hc_oid* oid);

/*****************************************/
/* SCHEMA */

HONEYCOMB_EXTERN hcerr_t hc_schema_get_type(hc_schema_t *schema, char *name, hc_type_t* rettype);
HONEYCOMB_EXTERN hcerr_t hc_schema_get_count(hc_schema_t *hsp, hc_long_t *countp);
HONEYCOMB_EXTERN hcerr_t hc_schema_get_type_at_index(hc_schema_t *hsp, hc_long_t index, char **namep, hc_type_t *typep);

/*****************************************/
/* NAME-VALUE RECORD */

HONEYCOMB_EXTERN hcerr_t hc_nvr_create(hc_session_t *session, hc_long_t initsize, hc_nvr_t** retnvr);
HONEYCOMB_EXTERN hcerr_t hc_nvr_free(hc_nvr_t* nvr);
/* Building a name-value record */
HONEYCOMB_EXTERN hcerr_t hc_nvr_add_value(hc_nvr_t* nvr, char *name, hc_value_t value);
HONEYCOMB_EXTERN hcerr_t hc_nvr_add_string(hc_nvr_t* nvr, char *name, hc_string_t value);
HONEYCOMB_EXTERN hcerr_t hc_nvr_add_long(hc_nvr_t* nvr, char *name, hc_long_t value);
HONEYCOMB_EXTERN hcerr_t hc_nvr_add_double(hc_nvr_t* nvr, char *name, hc_double_t value);
/* Iterating through a name-value record */
HONEYCOMB_EXTERN hcerr_t hc_nvr_get_count(hc_nvr_t *nvr, hc_long_t* retcount);
HONEYCOMB_EXTERN hcerr_t hc_nvr_get_value_at_index(hc_nvr_t *nvr, hc_long_t index, char **namep, hc_value_t *valuep);
/* Examining a name-value record, by name */
HONEYCOMB_EXTERN hcerr_t hc_nvr_get_string(hc_nvr_t* nvr, char *name, hc_string_t *valuep);
HONEYCOMB_EXTERN hcerr_t hc_nvr_get_long(hc_nvr_t* nvr, char *name, hc_long_t *valuep);
HONEYCOMB_EXTERN hcerr_t hc_nvr_get_double(hc_nvr_t* nvr, char *name, hc_double_t *valuep);
/* Convenience methods for dealing with string arrays instead of name-value structures */
HONEYCOMB_EXTERN hcerr_t hc_nvr_add_from_string(hc_nvr_t* nvr, char *name, char *value);
HONEYCOMB_EXTERN hcerr_t hc_nvr_create_from_string_arrays(hc_session_t *session, hc_nvr_t** nvrp, 
							  char **names, char **values, hc_long_t nitems);
HONEYCOMB_EXTERN hcerr_t hc_nvr_convert_to_string_arrays(hc_nvr_t* nvr, 
							 char ***namesp, char ***valuesp, int *nitemsp);

#ifdef __cplusplus
}	/* End #extern "C" scope */
#endif

#endif	/* __HCCLIENT__ */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <hcclient.h>

#include "const-c.inc"

typedef struct hc_session_t * Net_HoneyComb;

typedef struct {
	SV * callback;
	SV * context;
} net_honeycomb_cookie;

long net_honeycomb_reader( void *c, char *buffer, long n )
{
	net_honeycomb_cookie * cookie = c;
	long nbytes; // Actual number of bytes read
	SV *inbuff;

	dSP;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	XPUSHs(cookie->context);
	XPUSHs(sv_2mortal(newSViv(n)));
	PUTBACK;

	call_sv( cookie->callback, G_SCALAR );

	SPAGAIN;

	inbuff = POPs;
	nbytes = SvCUR(inbuff);

	if( nbytes > n )
	{
		warn("Callback returned more data than could be stored");
		nbytes = 0;
	}

	memcpy(buffer, SvPV_nolen(inbuff), nbytes);

	PUTBACK;
	FREETMPS;
	LEAVE;

	return nbytes;
}

long net_honeycomb_writer( void *c, char *buffer, long n )
{
	net_honeycomb_cookie * cookie = c;

	dSP;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	XPUSHs(cookie->context);
	XPUSHs(sv_2mortal(newSVpv(buffer, n)));
	PUTBACK;

	call_sv( cookie->callback, G_DISCARD );

	FREETMPS;
	LEAVE;

	return n;
}

/*
 * Store the contents of a Perl hash in an NVR
 */
void
net_honeycomb_nvr_from_hash(hc_nvr_t * nvr, HV * metadata)
{
	hcerr_t rc;
	HE * md_pair;
	char * value;
	char * key;
	SV * value_sv;
	I32 len;

	hv_iterinit( metadata );
	while( (md_pair = hv_iternext( metadata )) )	
	{
		key = hv_iterkey( md_pair, &len );
		value_sv = hv_iterval( metadata, md_pair );
		value = SvPV_nolen(value_sv);
		rc = hc_nvr_add_from_string( nvr, key, value );
		if( rc != HCERR_OK )
		{
			hc_nvr_free( nvr );
			croak("Error %d occurred while building hc_nvr_t", rc);
		}
	}
}

void
net_honeycomb_hash_from_nvr(HV * metadata, hc_nvr_t * nvr)
{
	char **names = NULL;
	char **values = NULL;
	int count = 0;
	int i;

	hcerr_t rc = hc_nvr_convert_to_string_arrays(
			nvr,
			&names,
			&values,
			&count
		);
	if (rc != HCERR_OK)
		croak("Error %d occurred while converting nvr to hash", rc);
	for(i = 0; i < count; ++i)
	{
		hv_store(
				metadata,
				names[i],
				strlen(names[i]),
				newSVpv(values[i], strlen(values[i])),
				0
			);
	}
}

void
net_honeycomb_error( hc_session_t * session, hcerr_t err )
{
	int32_t response_code = -1;
	char * errstr = "";

	if( session == NULL )
		croak("The client library returned error code %d = %s\n", err, hc_decode_hcerr(err));

	hcerr_t rc = hc_session_get_status( session, &response_code, &errstr );
	if( rc == HCERR_OK )
		croak("Client library error code: %d = %s\nHTTP Response Code: %d %s\n", err, hc_decode_hcerr(err), response_code, errstr);
}

MODULE = Net::HoneyComb		PACKAGE = Net::HoneyComb		

INCLUDE: const-xs.inc

void
init()
	PREINIT:
		hcerr_t rc;
	CODE:
		rc = hc_init(malloc,free,realloc);
		if( rc != HCERR_OK )
			croak("Error %d occurred while initializing HoneyComb", rc);

Net_HoneyComb
new( class, host, port )
	char *class;
	char *host;
	int port;
	PREINIT:
		hcerr_t rc;
		hc_session_t *session = NULL;
	CODE:
		rc = hc_session_create_ez( host, port, &session );
		if( rc != HCERR_OK )
			croak("Error %d while connecting to %s:%d", rc, host, port);
		else
			RETVAL = session;
	OUTPUT:
		RETVAL

void
DESTROY(session)
	Net_HoneyComb session
	CODE:
		hc_session_free( session );

char *
store_both(session, callback, context, metadata)
	Net_HoneyComb session;
	SV *callback;
	SV *context;
	HV *metadata;
	PREINIT:
		hcerr_t rc;
		net_honeycomb_cookie cookie;
		hc_nvr_t *nvr = NULL;
		hc_system_record_t system_record;
	CODE:
		cookie.callback = callback;
		cookie.context = context;
		rc = hc_nvr_create( session, 1, &nvr );
		if( rc != HCERR_OK )
			croak("Error %d occurred while initializing hc_nvr_t", rc);
		net_honeycomb_nvr_from_hash( nvr, metadata );
		rc = hc_store_both_ez(
				session,
				&net_honeycomb_reader,
				&cookie,
				nvr,
				&system_record
			);
		hc_nvr_free( nvr );
		if (rc != HCERR_OK)
			croak("Error %d occurred while storing object", rc);
		RETVAL = system_record.oid;
	OUTPUT:
		RETVAL

char *
store_metadata(session, oid, metadata)
	Net_HoneyComb session;
	char * oid;
	HV * metadata;
	PREINIT:
		hcerr_t rc;
		hc_nvr_t *nvr = NULL;
		hc_system_record_t system_record;
	CODE:
		rc = hc_nvr_create( session, 1, &nvr );
		if( rc != HCERR_OK )
			croak("Error %d occurred while initializing hc_nvr_t", rc);
		net_honeycomb_nvr_from_hash( nvr, metadata );
		rc = hc_store_metadata_ez(
				session,
				(hc_oid *) oid,
				nvr,
				&system_record
			);
		hc_nvr_free(nvr);
		if( rc != HCERR_OK )
			croak("Error %d occurred while storing metadata", rc);
		RETVAL = system_record.oid;
	OUTPUT:
		RETVAL

void
retrieve_metadata(session, oid)
	Net_HoneyComb session;
	char * oid;
	PREINIT:
		hcerr_t rc;
		hc_nvr_t *nvr = NULL;
		char **names = NULL;
		char **values = NULL;
		int count = 0;
		int i = 0;
	PPCODE:
		rc = hc_retrieve_metadata_ez(
				session,
				(hc_oid *) oid,
				&nvr
			);
		if (rc != HCERR_OK)
			croak("Error %d occurred while retrieving metadata", rc);
		rc = hc_nvr_convert_to_string_arrays(
				nvr,
				&names,
				&values,
				&count
			);
		if (rc != HCERR_OK)
			croak("Error %d occurred while extracting metadata from nvr", rc);
		for(i = 0; i < count; ++i)
		{
			PUSHs(sv_2mortal(newSVpv( names[i], strlen(names[i]) )));
			PUSHs(sv_2mortal(newSVpv( values[i], strlen(values[i]) )));
		}

void
retrieve(session, oid, callback, context)
	Net_HoneyComb session;
	char *oid;
	SV *callback;
	SV *context;
	PREINIT:
		hcerr_t rc;
		net_honeycomb_cookie cookie;
	CODE:
		cookie.callback = callback;
		cookie.context = context;
		rc = hc_retrieve_ez(
				session,
				&net_honeycomb_writer,
				&cookie,
				(hc_oid *)oid
			);
		if (rc != HCERR_OK)
			croak("Error %d occurred while retrieving object", rc);

void
query(session, query, max_records, ...)
	Net_HoneyComb session;
	char * query;
	int max_records;
	PREINIT:
		hcerr_t rc;
		hc_query_result_set_t *rset;
		char **selects = NULL;
		int i;
		int n = 0;
		hc_nvr_t *nvr = NULL;
		int finished = 0;
		hc_oid oid;
		HV * metadata = NULL;
	PPCODE:
		n = items - 3;
		if( n > 0 )
		{
			Newx(selects, n, char *);
			for(i = 0; i < n; ++i)
				selects[i] = (char *) SvPV_nolen(ST(i+3));
		}
		rc = hc_query_ez(
				session,
				query,
				selects,
				n,
				max_records,
				&rset
			);
		if( selects != NULL )
			Safefree(selects);
		if (rc != HCERR_OK)
			croak("Error %d occurred while performing query", rc);
		for(i = 0; i < max_records; ++i)
		{
			rc = hc_qrs_next_ez(rset, &oid, &nvr, &finished);
			if (rc != HCERR_OK)
				croak("Error %d occurred while retrieving query", rc);
			if( finished )
				break;
			metadata = newHV();
			// nvr will be non-NULL if selects were specified
			if( nvr != NULL )
				net_honeycomb_hash_from_nvr( metadata, nvr );
			PUSHs(sv_2mortal(newSVpv((char *) oid, strlen((char *) oid))));
			PUSHs(sv_2mortal(newRV_noinc((SV *) metadata)));
		}

void
delete(session, oid)
	Net_HoneyComb session;
	char * oid;
	PREINIT:
		hcerr_t rc;
	CODE:
		rc = hc_delete_ez( session, (hc_oid *) oid );
		if (rc != HCERR_OK)
			net_honeycomb_error(session, rc);


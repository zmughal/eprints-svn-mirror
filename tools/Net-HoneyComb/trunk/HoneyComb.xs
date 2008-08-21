#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <hcclient.h>

#include "const-c.inc"

typedef struct hc_session_t * Net_HoneyComb;
typedef struct hc_query_result_set_t * Net_HoneyComb_ResultSet;

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

bool
net_honeycomb_ok( hcerr_t err )
{
	return err == HCERR_OK;
}

void
net_honeycomb_error( hcerr_t err )
{
	croak("The client library returned error code %d = %s\n", err, hc_decode_hcerr(err));
}

MODULE = Net::HoneyComb		PACKAGE = Net::HoneyComb

INCLUDE: const-xs.inc

PROTOTYPES: ENABLE

BOOT:
	hc_init(malloc,free,realloc);

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
			net_honeycomb_error( rc );
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
			net_honeycomb_error( rc );
		net_honeycomb_nvr_from_hash( nvr, metadata );
		rc = hc_store_both_ez(
				session,
				&net_honeycomb_reader,
				&cookie,
				nvr,
				&system_record
			);
		hc_nvr_free( nvr );
		if( rc == HCERR_OK )
			RETVAL = system_record.oid;
		else
			RETVAL = NULL;
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
			net_honeycomb_error( rc );
		net_honeycomb_nvr_from_hash( nvr, metadata );
		rc = hc_store_metadata_ez(
				session,
				(hc_oid *) oid,
				nvr,
				&system_record
			);
		hc_nvr_free(nvr);
		if( rc == HCERR_OK )
			RETVAL = system_record.oid;
		else
			RETVAL = NULL;
	OUTPUT:
		RETVAL

SV *
retrieve_metadata(session, oid)
	Net_HoneyComb session;
	char * oid;
	PREINIT:
		hcerr_t rc;
		hc_nvr_t *nvr = NULL;
		HV * metadata = NULL;
	CODE:
		rc = hc_retrieve_metadata_ez(
				session,
				(hc_oid *) oid,
				&nvr
			);
		if (rc != HCERR_OK)
			net_honeycomb_error( rc );
		metadata = newHV();
		net_honeycomb_hash_from_nvr( metadata, nvr );
		RETVAL = newRV_noinc((SV *) metadata);
	OUTPUT:
		RETVAL

SV *
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
		RETVAL = net_honeycomb_ok( rc ) ? &PL_sv_yes : &PL_sv_no;
	OUTPUT:
		RETVAL

Net_HoneyComb_ResultSet
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
	CODE:
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
			net_honeycomb_error( rc );
		RETVAL = rset;
	OUTPUT:
		RETVAL

SV *
delete(session, oid)
	Net_HoneyComb session;
	char * oid;
	PREINIT:
		hcerr_t rc;
	CODE:
		rc = hc_delete_ez( session, (hc_oid *) oid );
		RETVAL = net_honeycomb_ok( rc ) ? &PL_sv_yes : &PL_sv_no;
	OUTPUT:
		RETVAL

void
get_status(session)
	Net_HoneyComb session;
	PREINIT:
		int32_t response_code = -1;
		char * errstr = "";
		hcerr_t rc;
	PPCODE:
		rc = hc_session_get_status( session, &response_code, &errstr );
		if( rc != HCERR_OK )
			net_honeycomb_error( rc );
		PUSHs(sv_2mortal(newSViv(response_code)));
		PUSHs(sv_2mortal(newSVpv(errstr, strlen(errstr))));

MODULE = Net::HoneyComb		PACKAGE = Net::HoneyComb::ResultSet

void
DESTROY(rset)
	Net_HoneyComb_ResultSet rset;
	CODE:
		hc_qrs_free(rset);

void
next(rset)
	Net_HoneyComb_ResultSet rset;
	PREINIT:
		hcerr_t rc;
		hc_oid oid;
		hc_nvr_t *nvr = NULL;
		int finished = 0;
		HV * metadata;
	PPCODE:
		rc = hc_qrs_next_ez(rset, &oid, &nvr, &finished);
		if (rc != HCERR_OK)
			net_honeycomb_error( rc );
		if( finished )
			XSRETURN_EMPTY;
		PUSHs(newSVpv((char *) oid, strlen((char *) oid)));
		if( nvr != NULL )
		{
			metadata = newHV();
			net_honeycomb_hash_from_nvr( metadata, nvr );
			//hc_nvr_free(nvr);
			PUSHs(newRV_noinc((SV *) metadata));
		}

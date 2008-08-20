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
	STRLEN len;

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
		if( rc != HCERR_OK )
			croak("Error %d occurred while storing metadata", rc);
		RETVAL = system_record.oid;
	OUTPUT:
		RETVAL

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
delete(session, oid)
	Net_HoneyComb session;
	char * oid;
	PREINIT:
		hcerr_t rc;
	CODE:
		rc = hc_delete_ez( session, (hc_oid *) oid );
		if (rc != HCERR_OK)
			croak("Error %d occurred while deleting object", rc);


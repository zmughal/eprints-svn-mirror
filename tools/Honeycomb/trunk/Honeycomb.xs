#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include "hcclient.h"
#include "example_metadata.h"

#include <fcntl.h>
#include <stdlib.h>


#ifdef O_BINARY
#define FLAG_BINARY O_BINARY
#else
#define FLAG_BINARY 0
#endif

#ifdef O_LARGEFILE
#define FLAG_LARGEFILE  O_LARGEFILE
#else
#define FLAG_LARGEFILE 0
#endif


#define store_honey_errcode( this, errcode ) hv_store( (HV*)SvRV(this), "ERRCODE", 7, newSViv( errcode ), 0 )
#define this_session(this) (hc_session_t*) SvIV(*(hv_fetch( (HV*)SvRV(this), "SESSION", 7, 0 )));
typedef int foo;

long read_from_perl_fh( void* perlfh, char* buff, long n )
{	
	int count;
	SV *read_wrapper;
	SV *buffer;
	char* outbuffer;
	int i;
	long nbytes;
	STRLEN nbytes_sl;
	dSP;

	ENTER;
	SAVETMPS;

	read_wrapper = eval_pv( "sub { my( $fh ) = @_; my $buffer; my $c = read( $fh, $buffer, 17 ); return( $buffer, $c ); }" , TRUE );

	PUSHMARK(SP);
	XPUSHs(perlfh);
	PUTBACK;

	count = call_sv( read_wrapper, G_ARRAY );

	SPAGAIN;

	if( count != 2 ) 
	{
		croak( "WTF?\n" );
	}

	nbytes = POPi;
	buffer = POPs;
	nbytes_sl = (STRLEN)nbytes;
	outbuffer = SvPV( buffer, nbytes_sl );
	for( i = 0; i<nbytes; ++i )
	{
		buff[i] = outbuffer[i];
	}	

	PUTBACK;
	FREETMPS;
	LEAVE;

	return nbytes;
}

long handle_chunk( void* fnSV, char* buff, long n )
{	
	dSP;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	XPUSHs(sv_2mortal(newSVpv(buff,n)));
	PUTBACK;

	call_sv( fnSV, G_DISCARD );

	FREETMPS;
	LEAVE;

	return n;
}

long read_from_file(void* stream, char* buff, long n)
{
	long nbytes;

	nbytes = read((int) stream, buff, n);
	return nbytes;
}	/* read_from_file */


void honey_init()
{
	hcerr_t rc;
	rc = hc_init(malloc,free,realloc);
	if( rc != HCERR_OK )
	{
		fprintf(stderr,"Error %d occurred while initializing StorageTek 5800.\n", rc);
	}
}




MODULE = Honeycomb		PACKAGE = Honeycomb		


void 
init()
	CODE:
		honey_init();


void 
cleanup()
	CODE:
		hc_cleanup();


	
SV *
new( class, host, port )
	char* class;
	char* host;
	int port;			
	PREINIT:
		HV* stash;
		HV* session_obj;
		hcerr_t err;
		hc_session_t *session = NULL;
	CODE:
		session_obj = newHV();
		RETVAL = newRV_inc( (SV*)session_obj );
		err = hc_session_create_ez( host, port, &session );
		if( err ) { XSRETURN_UNDEF; }
		hv_store( session_obj, "ERRCODE", 7, newSViv( err ), 0 );
		hv_store( session_obj, "SESSION", 7, newSViv( (int)session ), 0 );
		stash = gv_stashpv( class, FALSE );
		sv_bless( RETVAL, stash );
	OUTPUT:
		RETVAL

void
free( this )
	SV *this;
	PREINIT:
		hc_session_t *session = NULL;
	CODE:
		session = this_session(this);
		store_honey_errcode( this, hc_session_free(session) );

void
get_oid( this, oid, callback )
	SV *this;
	char *oid;
	SV *callback;
	PREINIT:
		hc_session_t *session = NULL;
	CODE:
		session = this_session(this);
		store_honey_errcode( 
			this,
			hc_retrieve_ez(
				session,
				&handle_chunk,
				callback,
				(hc_oid *)oid ) );





char* 
store( this, fh, metadata )
	SV *this;
	SV *fh;
	HV *metadata;
	PREINIT:
		hc_session_t *session;
		hc_nvr_t *nvr = NULL;
		hcerr_t	res;
		hc_system_record_t system_record;
		HE* md_pair;
		char* value;
		char* key;
		SV* value_sv;
		I32 retlen;
	CODE:
		session = this_session(this);
		res = hc_nvr_create( session, 1, &nvr );
		store_honey_errcode( this, res );
		if( res ) { XSRETURN_UNDEF; }
		hv_iterinit( metadata );
		while( (md_pair = hv_iternext( metadata )) )	
		{
			value_sv = hv_iterval( metadata, md_pair );
			value = SvPV_nolen(value_sv);
			key = hv_iterkey( md_pair, &retlen );
			res = hc_nvr_add_from_string( nvr, key, value );
			store_honey_errcode( this, res );
			if( res ) { hc_nvr_free( nvr ); XSRETURN_UNDEF; }
		}
		res = hc_store_both_ez (session, 
					&read_from_perl_fh, 
					(void *)fh, 
					nvr,
					&system_record);
		store_honey_errcode( this, res );
		hc_nvr_free( nvr );
		if (res != HCERR_OK)
		{
			XSRETURN_UNDEF; 
		}
		RETVAL = system_record.oid;
	OUTPUT:
		RETVAL



int
error( this )
	SV *this;
	PREINIT:
		hc_session_t *session = NULL;
	CODE:
		session = this_session(this);
		RETVAL = SvIV( *(hv_fetch( (HV*)SvRV(this), "ERRCODE", 7, 0 ) ));
	OUTPUT:
		RETVAL


SV*
error_string( this )
	SV *this;
	PREINIT:
		hc_session_t *session = NULL;
		hcerr_t res;
		int32_t response_code = -1;
		char* errstr = "";
		hcerr_t err = -1;
		char buffer[1023];
	CODE:
		RETVAL = newSVpv( "", 0 );
		session = this_session(this);
		res = SvIV( *(hv_fetch( (HV*)SvRV(this), "ERRCODE", 7, 0 ) ));
		sprintf(buffer,"\nThe server returned error code %d = %s\n", res, hc_decode_hcerr(res));
		sv_catpv( RETVAL, buffer );
		err = hc_session_get_status(session, &response_code, &errstr);
		if (err == HCERR_OK) 
		{
			sprintf(buffer,"HTTP Response_code: %d\n",response_code);
			sv_catpv( RETVAL, buffer );
			if (errstr[0] != 0) {
				sprintf(buffer,"Server Error String: %s\n", errstr);
				sv_catpv( RETVAL, buffer );
			}
		}
	OUTPUT:
		RETVAL


SV *
get_metadata( this, oid )
	SV *this;
	char* oid;
	PREINIT:
		hc_session_t *session = NULL;
		hc_nvr_t *nvr;
		hcerr_t res;
		int i = 0;
		char **names;
		char **values;
		int count;
		HV* metahash;
	CODE:
		session = this_session(this);
		res = hc_retrieve_metadata_ez (session,(hc_oid*)oid,&nvr );
		store_honey_errcode( this, res );
		if( res ) { XSRETURN_UNDEF; }
		res = hc_nvr_convert_to_string_arrays(nvr, &names, &values, &count);
		store_honey_errcode( this, res );
		if( res ) { XSRETURN_UNDEF; }

		metahash = newHV();
		RETVAL = newRV_inc( (SV*)metahash );
		for (i = 0; i < count; i++)
		{
			hv_store( metahash, names[i], strlen( names[i]) , newSVpv( values[i], 0 ), 0 );
		}
	OUTPUT:
		RETVAL



char* 
set_metadata( this, oid, metadata )
	SV *this;
	char* oid;
	HV* metadata;
	PREINIT:
		hc_session_t *session = NULL;
		hc_nvr_t *nvr=NULL;
		hcerr_t res;
		hc_system_record_t system_record;
		char* key;
		char* value;
		SV* value_sv;
		HE* md_pair;
		I32 retlen;
	CODE:
		session = this_session(this);
		res = hc_nvr_create( session, 2, &nvr );
		store_honey_errcode( this, res );
		if( res ) { XSRETURN_UNDEF; }
		hv_iterinit( metadata );
		while( (md_pair = hv_iternext( metadata )) )	
		{
			value_sv = hv_iterval( metadata, md_pair );
			value = SvPV_nolen(value_sv);
			key = hv_iterkey( md_pair, &retlen );
			res = hc_nvr_add_from_string( nvr, key, value );
			store_honey_errcode( this, res );
			if( res ) { hc_nvr_free( nvr ); XSRETURN_UNDEF; }
		}
		res = hc_store_metadata_ez( session, (hc_oid*)oid, nvr, &system_record );
		store_honey_errcode( this, res );
		res = hc_nvr_free( nvr );
		store_honey_errcode( this, res );
		RETVAL = system_record.oid;
	OUTPUT:
		RETVAL
		

AV* 
query( this, qstr )
	SV *this;
	char* qstr;
	PREINIT:
		hc_session_t *session = NULL;
		hc_oid returnedOid;
		hc_long_t count = 0;
		int finished = 0;
		hc_query_result_set_t *rset = NULL;
		hcerr_t	res;
	CODE:
		session = this_session(this);
		res = hc_query_ez(session,qstr,&rset);
		store_honey_errcode( this, res );
		if( res ) { XSRETURN_UNDEF; }
		RETVAL = newAV();
		sv_2mortal((SV*)RETVAL);
		/* Loop up until the maximum result size */
		for (count = 0; count < 99999; count++) 
		{
			res = hc_qrs_next_ez(rset, &returnedOid, &finished);
			store_honey_errcode( this, res );
			if( res ) { XSRETURN_UNDEF; }
			if (finished) break;
			av_push( RETVAL, newSVpv( returnedOid, 0 ) );
		}	/* loop through results */
		hc_qrs_free(rset);
		store_honey_errcode( this, res );
	OUTPUT:
		RETVAL



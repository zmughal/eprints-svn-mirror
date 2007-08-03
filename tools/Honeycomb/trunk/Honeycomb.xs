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

#ifdef    O_LARGEFILE
#define    FLAG_LARGEFILE  O_LARGEFILE
#else
#define FLAG_LARGEFILE 0
#endif


#define store_honey_errcode( this, errcode ) hv_store( (HV*)SvRV(this), "ERRCODE", 7, newSViv( errcode ), 0 )
#define this_session(this) (hc_session_t*) SvIV(*(hv_fetch( (HV*)SvRV(this), "SESSION", 7, 0 )));
typedef int foo;

long append_to_string( void* string, char* buff, long n )
{
	sv_catpvn( string, buff, n );
	return n;
}

long print_stuff(void* stream, char* buff, long n)
{
		return fwrite(buff, 1, n, stdout );
}
long write_to_file(void* stream, char* buff, long n)
{
	int pos = 0;
	while (pos < n)
	{
		int i = write ((int) stream, buff + pos, n - pos);
		if (i < 0) return i;
		if (i == 0) break;
		pos += i;
	}

	return pos;
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
	printf("Honeycomb AOK\n" );
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

SV *
string_oid( this, oid )
	SV *this;
	char *oid;
	PREINIT:
		hc_session_t *session = NULL;
	CODE:
		session = this_session(this);
		RETVAL = newSVpv( "", 0 );
		store_honey_errcode( 
			this,
			hc_retrieve_ez(
				session,
				&append_to_string,
				(void *)RETVAL,
				(hc_oid *)oid ) );
	OUTPUT:
		RETVAL

void
print_oid( this, oid )
	SV *this;
	char *oid;
	PREINIT:
		hc_session_t *session = NULL;
	CODE:
		session = this_session(this);
		store_honey_errcode( 
			this,
			hc_retrieve_ez(
				session,
				&print_stuff,
				(void *)stdout,
				(hc_oid *)oid ) );





char* 
store_file( this, filename )
	SV *this;
	char *filename;
	PREINIT:
		hc_session_t *session;
		hc_nvr_t *nvr = NULL;
		hcerr_t	res;
		hc_system_record_t system_record;
		int fileToStore = -1;
	CODE:
		session = this_session(this);
		res = hc_nvr_create( session, 1, &nvr );
		store_honey_errcode( this, res );
		if( res ) { XSRETURN_UNDEF; }
		if(!(fileToStore = open(filename, O_RDONLY | FLAG_BINARY | FLAG_LARGEFILE)) == -1)
		{
			hc_nvr_free( nvr );
			store_honey_errcode( this, -1 );
			XSRETURN_UNDEF; 
		}
		res = hc_store_both_ez (session, 
					&read_from_file, 
					(void *)fileToStore, 
					nvr,
					&system_record);
		store_honey_errcode( this, res );
		close(fileToStore);
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


void
print_error( this )
	SV *this;
	PREINIT:
		hc_session_t *session = NULL;
		hcerr_t res;
		int32_t response_code = -1;
		char* errstr = "";
		hcerr_t err = -1;
	CODE:
		session = this_session(this);
		res = SvIV( *(hv_fetch( (HV*)SvRV(this), "ERRCODE", 7, 0 ) ));
		fprintf(stderr,"\nThe server returned error code %d = %s\n", res, hc_decode_hcerr(res));
		err = hc_session_get_status(session, &response_code, &errstr);
		if (err == HCERR_OK) 
		{
			fprintf(stderr,"HTTP Response_code: %d\n",response_code);
			if (errstr[0] != 0) {
				fprintf(stderr,"Server Error String: %s\n", errstr);
			}
		}

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
set_metadata( this, oid, key, value )
	SV *this;
	char* oid;
	char* key;
	char* value;
	PREINIT:
		hc_session_t *session = NULL;
		hc_nvr_t *nvr=NULL;
		hcerr_t res;
		hc_system_record_t system_record;
	CODE:
		session = this_session(this);
		res = hc_nvr_create( session, 2, &nvr );
		store_honey_errcode( this, res );
		if( res ) { XSRETURN_UNDEF; }
		res = hc_nvr_add_from_string( nvr, key, value );
		store_honey_errcode( this, res );
		if( res ) { hc_nvr_free( nvr ); XSRETURN_UNDEF; }
		res = hc_store_metadata_ez( session, (hc_oid*)oid, nvr, &system_record );
		store_honey_errcode( this, res );
		res = hc_nvr_free( nvr );
		store_honey_errcode( this, res );
		RETVAL = system_record.oid;
	OUTPUT:
		RETVAL
		


	

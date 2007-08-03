/*
 * $Id: example_common.c 8089 2006-04-26 22:27:42Z sp198635 $
 *
 * Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#include "example_common.h"

void HandleError(hc_session_t *session, hcerr_t res)
{
        int32_t response_code = -1;
        char* errstr = "";
        hcerr_t err = -1;

	/* Print error message associated with error code */
	printf("\nThe server returned error code %d = %s\n", res, hc_decode_hcerr(res));

	/* Print error status message from the StorageTek 5800 session */ 
        if (session)
        {
                err = hc_session_get_status(session, &response_code, &errstr);
                if (err == HCERR_OK) 
                {
			printf("HTTP Response_code: %d\n",response_code);
			if (errstr[0] != 0) {
	                        printf("Server Error String: %s\n", errstr);
			}
                }
        } /* if session exists */
} /* HandleError */

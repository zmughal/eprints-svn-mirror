/*
 * $Id: example_common.c 10856 2007-05-19 02:58:52Z bberndt $
 *
 * Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#include "example_common.h"

void HandleError(hc_session_t *session, hcerr_t res)
{
        int32_t response_code = -1;
        char* errstr = "";
        hcerr_t err = -1;

	/* Print error message associated with error code */
	printf("\nThe client library returned error code %d = %s\n", res, hc_decode_hcerr(res));

	/* Print error status message from the 5800 system session */ 
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

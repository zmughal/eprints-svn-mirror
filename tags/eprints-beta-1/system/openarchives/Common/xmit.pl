#############################################################################
# Dienst - A protocol and server for a distributed digital technical report
# library
#
# File: xmit.pl
#
# Description:
#       File transmission routines.
#
#############################################################################
# Copyright (C) 2000, Cornell University, Xerox Incorporated                #
#                                                                           #
# This software is copyrighted by Cornell University (CU), and ownership of #
# this software remains with CU.                                            #
#                                                                           #
# This software was written as part of research work by:                    #
#   Cornell Digital Library Research Group                                  #
#   Department of Computer Science                                          #
#   Upson Hall                                                              #
#   Ithaca, NY 14853                                                        #
#   USA                                                                     #
#   email: info@prism.cornell.edu                                           #
# 									    #
# Pursuant to government funding guidelines, CU grants you a noncommercial, #
# nonexclusive license to use this software for academic, research, and	    #
# internal business purposes only.  There is no fee for this license.	    #
# You may distribute binary and source code to third parties provided	    #
# that this copyright notice is included with all copies and that no	    #
# charge is made for such distribution.					    #
# 									    #
# You may make and distribute derivative works providing that: 1) You	    #
# notify the Project at the above address of your intention to do so; and   #
# 2) You clearly notify those receiving the distribution that this is a	    #
# modified work and not the original version as distributed by the Cornell  #
# Digital Library Research Group.					    #
# 									    #
# Anyone wishing to make commercial use of this software should contact	    #
# the Cornell Digital Library Rsearch Group at the above address.	    #
# 									    #
# This software was created as part of an ongoing research project and is   #
# made available strictly on an "AS IS" basis.  NEITHER CORNELL UNIVERSITY  #
# NOR ANY OTHER MEMBERS OF THE CS-TR PROJECT MAKE ANY WARRANTIES, EXPRESSED #
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY IMPLIED WARRANTY OF	    #
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.  NEITHER CORNELL	    #
# NOR ANY OTHER MEMBERS OF THE CS-TR PROJECT SHALL BE LIABLE TO USERS OF    #
# THIS SOFTWARE FOR ANY INCIDENTAL, SPECIAL, OR CONSEQUENTIAL DAMAGES OR    #
# LOSS, EVEN IF ADVISED OF THE POSSIBILITY THEREOF.			    #
# 									    #
# This work was supported in part by the Defense Advanced Research Projects #
# Agency under Grant No. MDA972-92-J-1029 and Grant No. N66001-98-1-8908    #
# with the Corporation for National Research Initiatives (CNRI).  Support   #
# was also provided by the National Science Foundation under Grant No.      #
# IIS-9817416. Its content does not necessarily reflect                     #
# the position or the policy of the Government or CNRI, and no official	    #
# endorsement should be inferred.					    #
#############################################################################

package dienst;

# Send a file.  The server must supply the type of the file.
# If the source_path is not local (it is a URL), issues a redirect
# HTTP protocol mandates that there be a header which includes
# among other things the MIME content type of the data.
# Note that a tif file can be compressed internally (part of TIFF standard)
# or by the standard Unix compress program.  In the former case
# the compression is invisible to the server.
#  Add code to generate Content-encoding header if compressed.
#  Maybe add code here to transmit files compressed always.
sub xmit_file {
    local($source_path, $type, $body) = @_;
    my ($mtime);
    
    if ($type eq "") {
	$type = "application/octet-stream"}

    $mtime = &dienst::File_modification_time ($source_path);

    print CGI::header(-type=>$type, 
		      -status=>'200',
		      -content_length=>&dienst::File_size ($source_path),
		      -last_modified=>&dienst::Time_to_String ($mtime, ""),
		      );
    if ($body) {
	if (!open(SOURCE, $source_path)) {
	    &dienst::program_error("Cannot open file $source_path: $!");
	}
	while (<SOURCE>) {print;}
	close(SOURCE);
    }
}

# For including a file in the middle of something else.
sub xmit_raw {
    local($source_path) = @_;
    if (open(SOURCE, $source_path)) {
	while (<SOURCE>) {print;}
	close(SOURCE);
    }}


1;

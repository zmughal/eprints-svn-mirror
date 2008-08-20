#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <include/hcclient.h>

#include "const-c.inc"

MODULE = Net::HoneyComb		PACKAGE = Net::HoneyComb		

INCLUDE: const-xs.inc

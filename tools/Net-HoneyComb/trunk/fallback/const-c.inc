#define PERL_constant_NOTFOUND	1
#define PERL_constant_NOTDEF	2
#define PERL_constant_ISIV	3
#define PERL_constant_ISNO	4
#define PERL_constant_ISNV	5
#define PERL_constant_ISPV	6
#define PERL_constant_ISPVN	7
#define PERL_constant_ISSV	8
#define PERL_constant_ISUNDEF	9
#define PERL_constant_ISUV	10
#define PERL_constant_ISYES	11

#ifndef NVTYPE
typedef double NV; /* 5.6 and later define NVTYPE, and typedef NV to it.  */
#endif
#ifndef aTHX_
#define aTHX_ /* 5.6 or later define this for threading support.  */
#endif
#ifndef pTHX_
#define pTHX_ /* 5.6 or later define this for threading support.  */
#endif

static int
constant_12 (pTHX_ const char *name, IV *iv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     HC_BYTE_TYPE HC_CHAR_TYPE HC_DATE_TYPE HC_LONG_TYPE HC_TIME_TYPE */
  /* Offset 3 gives the best switch position.  */
  switch (name[3]) {
  case 'B':
    if (memEQ(name, "HC_BYTE_TYPE", 12)) {
    /*                  ^               */
#ifdef HC_BYTE_TYPE
      *iv_return = HC_BYTE_TYPE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'C':
    if (memEQ(name, "HC_CHAR_TYPE", 12)) {
    /*                  ^               */
#ifdef HC_CHAR_TYPE
      *iv_return = HC_CHAR_TYPE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'D':
    if (memEQ(name, "HC_DATE_TYPE", 12)) {
    /*                  ^               */
#ifdef HC_DATE_TYPE
      *iv_return = HC_DATE_TYPE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'L':
    if (memEQ(name, "HC_LONG_TYPE", 12)) {
    /*                  ^               */
#ifdef HC_LONG_TYPE
      *iv_return = HC_LONG_TYPE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'T':
    if (memEQ(name, "HC_TIME_TYPE", 12)) {
    /*                  ^               */
#ifdef HC_TIME_TYPE
      *iv_return = HC_TIME_TYPE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_14 (pTHX_ const char *name, IV *iv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     HC_BINARY_TYPE HC_DOUBLE_TYPE HC_STRING_TYPE */
  /* Offset 7 gives the best switch position.  */
  switch (name[7]) {
  case 'L':
    if (memEQ(name, "HC_DOUBLE_TYPE", 14)) {
    /*                      ^             */
#ifdef HC_DOUBLE_TYPE
      *iv_return = HC_DOUBLE_TYPE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'N':
    if (memEQ(name, "HC_STRING_TYPE", 14)) {
    /*                      ^             */
#ifdef HC_STRING_TYPE
      *iv_return = HC_STRING_TYPE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'R':
    if (memEQ(name, "HC_BINARY_TYPE", 14)) {
    /*                      ^             */
#ifdef HC_BINARY_TYPE
      *iv_return = HC_BINARY_TYPE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant (pTHX_ const char *name, STRLEN len, IV *iv_return) {
  /* Initially switch on the length of the name.  */
  /* When generated this function returned values for the list of names given
     in this section of perl code.  Rather than manually editing these functions
     to add or remove constants, which would result in this comment and section
     of code becoming inaccurate, we recommend that you edit this section of
     code, and use it to regenerate a new set of constant functions which you
     then use to replace the originals.

     Regenerate these constant functions by feeding this entire source file to
     perl -x

#!/usr/bin/perl -w
use ExtUtils::Constant qw (constant_types C_constant XS_constant);

my $types = {map {($_, 1)} qw(IV)};
my @names = (qw(HC_BINARY_TYPE HC_BOGUS_TYPE HC_BYTE_TYPE HC_CHAR_TYPE
	       HC_DATE_TYPE HC_DOUBLE_TYPE HC_EMPTY_VALUE_INIT HC_LONG_TYPE
	       HC_OBJECTID_TYPE HC_STRING_TYPE HC_TIMESTAMP_TYPE HC_TIME_TYPE
	       HC_UNKNOWN_TYPE));

print constant_types(); # macro defs
foreach (C_constant ("Net::HoneyComb", 'constant', 'IV', $types, undef, 3, @names) ) {
    print $_, "\n"; # C constant subs
}
print "#### XS Section:\n";
print XS_constant ("Net::HoneyComb", $types);
__END__
   */

  switch (len) {
  case 12:
    return constant_12 (aTHX_ name, iv_return);
    break;
  case 13:
    if (memEQ(name, "HC_BOGUS_TYPE", 13)) {
#ifdef HC_BOGUS_TYPE
      *iv_return = HC_BOGUS_TYPE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 14:
    return constant_14 (aTHX_ name, iv_return);
    break;
  case 15:
    if (memEQ(name, "HC_UNKNOWN_TYPE", 15)) {
#ifdef HC_UNKNOWN_TYPE
      *iv_return = HC_UNKNOWN_TYPE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 16:
    if (memEQ(name, "HC_OBJECTID_TYPE", 16)) {
#ifdef HC_OBJECTID_TYPE
      *iv_return = HC_OBJECTID_TYPE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 17:
    if (memEQ(name, "HC_TIMESTAMP_TYPE", 17)) {
#ifdef HC_TIMESTAMP_TYPE
      *iv_return = HC_TIMESTAMP_TYPE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 19:
    if (memEQ(name, "HC_EMPTY_VALUE_INIT", 19)) {
#ifdef HC_EMPTY_VALUE_INIT
      *iv_return = HC_EMPTY_VALUE_INIT;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}


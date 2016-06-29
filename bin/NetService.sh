#!/bin/bash
##################################################################
# NAME: NetService.sh
#
# DESC: Script to retrieve all NetManager Net Service entries from OID for a specified Realm/OracleContext.
#
# $HeadURL$
# $LastChangedBy$
# $LastChangedDate$
# $LastChangedRevision$
##################################################################

# Set variables
SCRIPT=${0}
EXIT_SUCC=0
EXIT_USAGE=2
EXIT_ENV=1

#
# Functions
#

usage ()
{ # Show script usage
  echo "
 ${SCRIPT} - Shell script to retrieve all Net Manager Net Service entries from OID for a specified realm.
 The user is prompted for any required values not provided on the command line. The password for the 
 connecting user to the OID instance can only be provided via prompt, or the environment variable OID_PASSWD.
 This provides for better security. To obtain entries under the root OracleContext you must specify 
 '-R root'. See usage below for an explanation of each option.

 DEPENDENCIES
  ORACLE_HOME - This environment variable must be set correctly to that of the OID home. 
  
 USAGE
 ${SCRIPT} [-n <hostname>] [-p <Port>] [-ssl] [-D <user_dn>] [-R <realm_dn>] [-f <output_filename>] [-m]
 
 OPTIONS
  -n <hostname>
    The hostname of the OID host.
  
  -p <Port>
    The port number to communicate with the OID instance. Default is 3060.
    
  -ssl
    Flag for using SSL connection to the OID instance.
    
  -D <user_dn>
    The distinguished name or DN for the user to be used in communicating with the OID instance.
    The default is 'cn=orcladmin'.
    
  -R <realm_dn>
    The distinguished name or DN for the realm from which to read.
    
  -f <output_filename>
    The full name of the file to which output results will be dumped.
    
  -m
    Flag to create an ordered output file, in the sequence:
      1. Net Service entry (ns)
      2. Net Description (nd)
      3. Net Address List (nl)
      4. Net Address (na)
    This is useful to capture the full, correct sequenced entries.
      
  -h
    Print this help usage.
"
  exit $EXIT_USAGE
}

confirm() 
{
  if [ "$SEP" = "1" ] ; then
    echo "The current search parameters will return Net Service Naming entries under cn=OracleContext$REALM to output files:
          $OUT_FILE.1.ns, $OUT_FILE.2.nd, $OUT_FILE.3.nl, $OUT_FILE.4.na"
  else
    echo "The current search parameters will return Net Service Naming entries under cn=OracleContext$REALM to output file $OUT_FILE"
  fi
  echo "continue [y/n]:" ; read CONT
  case "$CONT" in
  "y"|"Y")
    if [ "$RM_OUT" = "true" ] ; then
      rm -f $OUT_FILE
    fi
    ;;
  *)
    echo "Operation cancelled."
    exit $EXIT_SUCC
    ;;
  esac
}

runsearch_sep() 
{
  $ORACLE_HOME/bin/ldapsearch -h $OID_HOST -p $OID_PORT -D "$USER_DN" -w $OID_PASSWD -s sub -b "cn=OracleContext$REALM" objectclass=orclnetService dn | \
  grep -v ^$ | \
  while read dn ; do 
    $ORACLE_HOME/bin/ldapsearch -h $OID_HOST -p $OID_PORT -D "$USER_DN" -w $OID_PASSWD -s sub -b "$dn" objectclass=orclNetService  >> ${OUT_FILE}.1.ns ;
    echo "" >> ${OUT_FILE}.1.ns ;
    $ORACLE_HOME/bin/ldapsearch -h $OID_HOST -p $OID_PORT -D "$USER_DN" -w $OID_PASSWD -s sub -b "$dn" objectclass=orclNetDescription >> ${OUT_FILE}.2.nd ;
    echo "" >> ${OUT_FILE}.2.nd ;
    $ORACLE_HOME/bin/ldapsearch -h $OID_HOST -p $OID_PORT -D "$USER_DN" -w $OID_PASSWD -s sub -b "$dn" objectclass=orclNetAddressList >> ${OUT_FILE}.3.nl ;
    echo "" >> ${OUT_FILE}.3.nl ;
    $ORACLE_HOME/bin/ldapsearch -h $OID_HOST -p $OID_PORT -D "$USER_DN" -w $OID_PASSWD -s sub -b "$dn" objectclass=orclNetAddress >> ${OUT_FILE}.4.na ;
    echo "" >> ${OUT_FILE}.4.na ;
  done
  cat ${OUT_FILE}.1.ns ${OUT_FILE}.2.nd ${OUT_FILE}.3.nl ${OUT_FILE}.4.na > ${OUT_FILE}
  rm -f ${OUT_FILE}.1.ns ${OUT_FILE}.2.nd ${OUT_FILE}.3.nl ${OUT_FILE}.4.na
}

runsearch()
{
  $ORACLE_HOME/bin/ldapsearch -h $OID_HOST -p $OID_PORT -D "$USER_DN" -w $OID_PASSWD -s sub -b "cn=OracleContext$REALM" objectclass=orclnetService dn | \
  grep -v ^$ | \
  while read dn ; do
    $ORACLE_HOME/bin/ldapsearch -h $OID_HOST -p $OID_PORT -D "$USER_DN" -w $OID_PASSWD -s sub -b "$dn" objectclass=*  >> $OUT_FILE ;
    echo "" >> $OUT_FILE ;
  done
}

#
# Main code
#
# Check environment
if [ -z $ORACLE_HOME ] ; then
 echo "Missing \$ORACLE_HOME environment variable. Please set this environment variable and then re-run this script."
 usage
fi

if [ ! -f $ORACLE_HOME/bin/ldapsearch ] ; then
  echo ""
  echo "ERR: There is no ldapsearch tool available in the ORACLE_HOME: ${ORACLE_HOME}"
  echo ""
  usage
fi

# Parse command line arguments
while [ $# -gt 0 ] ; do
  case $1 in
  -n)
    # OID host
    OID_HOST=$2 ;
    [ -z $OID_HOST ] && usage
    shift ;;
  -p)
    # OID port
    OID_PORT=$2 ;
    [ -z $OID_PORT ] && usage
    shift ;;
  -ssl)
    # SSL connection
    SSL=1 ;;
  -D)
    # Authorizing user Distinguished Name (DN)
    USER_DN=$2 ;
    [ -z $USER_DN ] && usage
    shift ;;
  -R)
    # Realm
    REALM=$2 ;
    [ -z $REALM ] && usage
    REALM=,$REALM
    shift ;;
  -f)
    # Output file
    OUT_FILE=$2 ;
    [ -z $OUT_FILE ] && usage
    shift ;;
  -m)
    # Multiple or split file run
    SEP=1 ;;
  -*)
    # Usage print otherwise
    usage ;;
  esac
  shift
done

# Get missing OID hostname
if [ -z $OID_HOST ] ; then
  echo "Enter OID hostname [`hostname`]:" ; read OID_HOST
  [ -z $OID_HOST ] && OID_HOST=`hostname -f`
fi

# Get missing OID port
if [ -z $OID_PORT ] ; then
  echo "Enter OID Port [3060]:" ; read OID_PORT
  echo "Use SSL [y/n]:" ; read ISSSL
  [ "$ISSSL" = "y" ] && SSL=1
  # Use default OID port if still missing
  [ -z $OID_PORT ] && OID_PORT=3060
fi

# Configure SSL connection if specified
[ "$SSL" = "1" ] && OID_PORT="$OID_PORT -U 1"

# Verify LDAP host/port
$ORACLE_HOME/bin/ldapbind -h $OID_HOST -p $OID_PORT > /dev/null
if [ $? -ne 0 ]; then
{
  echo ""
  echo "ERR: Cannot connect to LDAP Server"
  echo "Check the following:"
  echo "1. OID is running on the host ${OID_HOST}"
  echo "2. The port ${OID_PORT} is correct"
  echo "3. Anonymous binds are enabled for the OID instance."
  echo ""
  exit $EXIT_ENV
}

# Get credentials
if [ -z $USER_DN ] ; then
  echo "Enter OID username [cn=orcladmin]:" ; read USER_DN
  [ -z $USER_DN ] && USER_DN="cn=orcladmin"
fi

if [ -z ${OID_PASSWD} ]; then
  echo "Enter the password for $USER_DN:" ; read -s OID_PASSWD
  echo ""
fi

# Confirm credentials
$ORACLE_HOME/bin/ldapbind -h $OID_HOST -p $OID_PORT -D "$USER_DN" -w $OID_PASSWD > /dev/null
if [ $? -ne 0 ]; then
{
  echo ""
  echo "ERR: Check the user credentials provided."
  echo ""
  exit $EXIT_ENV
}

#Get default Realm
DEF_REALM=$($ORACLE_HOME/bin/ldapsearch -h $OID_HOST -p $OID_PORT -D "$USER_DN" -w $OID_PASSWD -b "cn=common,cn=products,cn=oraclecontext" -s base objectclass=* orcldefaultsubscriber | grep -i orcldefaultsubscriber | cut -d '=' -f 2-)

if [ -z $REALM ] ; then
  echo "Enter OID Realm Base DN - enter \"root\" for the Root OracleContext [$DEF_REALM]:" ; read REALM
  if [ -z $REALM ] ; then
     REALM=",${DEF_REALM}"
  else
     if [ "$REALM" = "root" ] ; then
        unset REALM
     else
        REALM=",${REALM}"
     fi  
  fi
fi

if [ -z $OUT_FILE ] ; then
  echo "Enter output filename [NetServiceEntries.ldif]:" ; read OUT_FILE
  [ -z $OUT_FILE ] && OUT_FILE=NetServiceEntries.ldif
fi

if [ -f $OUT_FILE ] ; then
  echo "File $OUT_FILE already exists. Type \"y\" to overwrite, or enter new output filename:" ; read OW
  if [ "$OW" = "y" -o "$OW" = "Y" ] ; then
    RM_OUT=true
  else
    if [ -z $OW -o "$OW" = "n" -o  "$OW" = "N" ] ; then
      echo "Please enter new output filename:" ; read OUT_FILE
    else
      OUT_FILE=$OW
    fi
  fi
fi

confirm

if [ "$SEP" = "1" ] ; then
  runsearch_sep
else
  runsearch
fi

exit $EXIT_SUCC

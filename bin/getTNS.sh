#!/bin/bash
##################################################################
# NAME: getTNS.sh
#
# DESC: Script to export TNS entries from OID.
#
# $HeadURL$
# $LastChangedBy$
# $LastChangedDate$
# $LastChangedRevision$
#
# LOG:
# yyyy/mm/dd [userid]: [comments]
# 2013/02/13 cgwong: Initial creation based on MOS version
# 2014/04/16 cgwong: [v1.0.1] Updated usage print out.
#                             Modified command line parameter for hostname from 'h' to 'n'
#                             and used 'h' for help usage.
#                             Added SVN variables.
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
 ${SCRIPT} - Shell script to export Net Service entries from OID. The user is prompted for any
 required values not provided on the command line. The password for the connecting user to the
 OID instance can only be provided via prompt, or the environment variable OID_PASSWD. This
 provides for better security. See usage below for an explanation of each option.

 DEPENDENCIES
  ORACLE_HOME - This environment variable must be set correctly to that of the OID home. 
 
 USAGE
 ${SCRIPT} [-n <hostname>] [-p <Port>] [-ssl] [-D <user_dn>] [-f <output_filename>] [-h]
 
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
    
  -f <output_filename>
    The full name of the file to which output results will be dumped.
    
  -h
    Print this help usage.
"
  exit $EXIT_USAGE
}

runsearch() 
{
  # 1. Get all TNS entries from OID
  # 2. Remove all occurences of 'cn='
  # 3. Remove the string ',oraclecontext'
  # 4. Replace all ',dc=' with a dot(.).
  #    This allows every TNS alias to be pulled from OID and represented in a proper domain format.
  # 5. Remove the 'orclnetdescstring'
  # 6. An '=' sign needs to be placed at the end of the TNS alias.
  #    Add an '=' at the end of each line and remove the ones not needed
  $ORACLE_HOME/bin/ldapsearch -h $OID_HOST -p $OID_PORT -D "$USER_DN" -w $OID_PASSWD -b " " -s sub '(objectclass=orclNetService)' orclNetDescString \
  | sed -e 's/cn=//g' -e 's/,OracleContext//g' -e 's/,dc=/./g' -e 's/orclnetdescstring//g' -e 's/$/=/' -e 's/=(DES/ (DES/' -e 's/^=//' -e 's/))=/))/g' >> $OUT_FILE
}

runsearch_alt()
{
  # 1. Grab the entries we need from OID and dump them into file
  # 2. Generate an almost complete tnanames.ora file
  # a. 's/orclnetdescstring=/ /' - replace "orclnetdescstring=" with a [space] to prevent (DESCRIPTION= from being left justified.
  # b. 's/cn=//' - Remove "cn=" from the beginning of all lines
  # c. 's/,dc=/./g' - replace all "dc=" with a "." since Domain Components are separated with a "." character.
  # d. 's/,cn=OracleContext//' - Remove "cn=OracleContext" from each line
  # e. Add an "=" to the end of each net service name by adding an "=" to every line and then selectively removing them
  # f. '/^$/d' - Remove all blank lines
  # g. 's/$/=/g' - append a "=" to the end of each line
  # h. 's/)=/)/' - replace ")=" with ")" so only net srevice names end with an "="
  # i. '/)))/G' - reinsert a blank line after any line containing ")))" for a better looking file.
  $ORACLE_HOME/bin/ldapsearch -h $OID_HOST -p $OID_PORT -D "$USER_DN" -w $OID_PASSWD -b "" -s sub '(|(objectclass=orclNetService)(objectclass=orclService))' orclnetdescstring '(|(objectclass=orclNetService)(objectclass=orclNetServiceAlias))' orclnetdescstring aliasedobjectname \
  | sed -e 's/orclnetdescstring=/ /' -e 's/cn=//' -e 's/,dc=/./g' -e 's/,cn=OracleContext//' -e '/^$/d' -e 's/$/=/g' -e 's/)=/)/' -e '/)))/G' > $OUT_FILE
}

#
# Main code
#
# Check environment
if [ -z $ORACLE_HOME ] ; then
 echo ""
 echo "Missing \$ORACLE_HOME environment variable. Please set this environment variable and then re-run this script."
 echo ""
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
  -f)
    # Output file
    OUT_FILE=$2 ;
    [ -z $OUT_FILE ] && usage
    shift ;;
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
if [ "$SSL" = "1" ] ; then
   OID_PORT="$OID_PORT -U 1"
fi

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
  [ -z $USER_DN ] && USER_DN=cn=orcladmin
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

if [ -z $OUT_FILE ] ; then
  echo "Enter output filename [tnsnames.ora]:" ; read OUT_FILE
  [ -z $OUT_FILE ] && OUT_FILE=tnsnames.ora
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

runsearch

exit $EXIT_SUCC

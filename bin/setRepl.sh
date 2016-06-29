# ! /bin/sh
######################################################
# NAME: setRepl.sh
#
# DESC: Cleans up all previous replication configurations
#       and sets up new multi-master replication agreement.
#
# $HeadURL$
# $LastChangedBy$
# $LastChangedDate$
# $LastChangedRevision$
#
# LOG:
# yyyy/mm/dd [user] - [notes]
# 2013/08/22 cgwong - Recreation.
# 2014/04/16 cgwong: [v1.0.1] Updated usage print out.
#                             Modified command line parameters.
#                             Added SVN variables.
######################################################

# Variables #
SCRIPT=${0}

# Functions #
usage ()
{ # Show script usage
  echo "
 ${SCRIPT} - Shell script to clean up all previous replication configurations
 and set up a new multi-master LDAP replication agreement. The password for the
 connecting user to the OID instances can only be provided via the environment
 variable OID_PWD. This provides for better security. See usage below for 
 an explanation of each option.

 DEPENDENCIES
  ORACLE_HOME - This environment variable must be set correctly to that of the OID home. 
 
 USAGE
 ${SCRIPT} [-f <first_oid_host>] [-s <second_oid_host>] [-p <port>] [-D <user_dn>] [-l <LDIF>] [-h]
 
 OPTIONS
  -f <hostname>
    The first OID host.
  
  -s <hostname>
    The second OID host.

  -p <port>
    The port number to communicate with the OID instance. Default is 3060.
    
  -D <user_dn>
    The distinguished name or DN for the user to be used in communicating with the OID instances.
    The default is 'cn=orcladmin'.
    
  -l <LDIF>
    The LDIF format file which has the settings to stop replication (oidrepld).
    
  -h
    Print this help usage.
"
  exit $EXIT_USAGE
}

# Main #
# Parse command line arguments
while [ $# -gt 0 ] ; do
  case $1 in
  -f)
    # Set primary node
    NODE_PRI=${2}
    [ -z $NODE_PRI ] && usage
    shift ;;
  -s)
    # Set primary node
    NODE_SEC=${2}
    [ -z $NODE_SEC ] && usage
    shift ;;
  -p)
    # OID port
    OID_PORT=${2:3060} ;
    [ -z $OID_PORT ] && usage
    shift ;;
  -D)
    # Authorizing user Distinguished Name (DN)
    OID_USER=${2:"cn=orcladmin"}
    [ -z $OID_USER ] && usage
    shift ;;
  -l)
    # LDIF file used to stop OIDREPLD, assumed to be in current directory
    REPL_OFF=${2:"./setRepl.ldif"} ;
    [ -z $REPL_OFF ] && usage
    shift ;;
  -*)
    # Usage print otherwise
    usage ;;
  esac
  shift
done

# Check if password variable is set
if [ -z ${OID_PWD} ]; then
  echo "Enter the password for ${OID_USER}:" ; read -s OID_PASSWD
  echo ""
fi

# To stop OIDREPLD using command line you must first reset the flag in
# the replication configuration using LDAPMODIFY with the REPL_OFF LDIF (text) File
${ORACLE_HOME}/bin/ldapmodify -h ${NODE_PRI} -p ${OID_PORT} -D "$OID_USER" -w ${OID_PWD} -v -f ${REPL_OFF}

# Once orclactivereplication is set to 0 stop the oidrepld process
# The instance number is instance=0 instead of the typical instance=1
# whenever replication is configured and started from EM
${ORACLE_HOME}/bin/oidctl connect=oiddb server=oidrepld instance=0 stop

# On the Primary node, run the replication cleanup
${ORACLE_HOME}/ldap/bin/remtool -pcleanup

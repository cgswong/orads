# ! /bin/sh
######################################################
# NAME: OIDenv.sh
#
# DESC: Configures environment for Oracle Internet Directory
#       (OID) access.
#
# NOTE: Due to constraints of the shell in regard to environment
#       variables, the command MUST be prefaced with ".". If it
#       is not, then no permanent change in the user's environment
#       can take place.
#
# $HeadURL$
# $LastChangedBy$
# $LastChangedDate$
# $LastChangedRevision$
#
# LOG:
# yyyy/mm/dd [user] - [version] [notes]
# 2012/01/29 cgwong - Recreation.
# 2013/02/08 cgwong - Optimized coding
# 2013/03/11 cgwong - Modified some variables
# 2014/01/16 cgwong - [v1.0.0] Updated header with name and version.
#                   - Updated environment variable NOTSET
# 2014/05/06 cgwong: [v1.0.1] Fix for remtool core dumping (SR 3-7786328551)
#                    Potential heap errors are silently ignore (MALLOC_CHECK_=0)
######################################################

# Functions
pathman ()
{
# Function used to add non-existent directory (given as argument)
# to PATH variable.
  if ! echo ${PATH} | /bin/egrep -q "(^|:)$1($|:)" ; then
    PATH=$1:${PATH} ; export PATH
  fi
}

# Middleware variables
MW_HOME=/oracle/app/oracle/product/fmw ; export MW_HOME
WL_HOME=$MW_HOME/wlserver_10.3         ; export WL_HOME

# OID variables
INSTANCE_NAME=asinst_1                  ; export INSTANCE_NAME
ORACLE_INSTANCE_NAME=$INSTANCE_NAME     ; export ORACLE_INSTANCE_NAME
ORACLE_INSTANCE=$MW_HOME/$INSTANCE_NAME ; export ORACLE_INSTANCE
ORACLE_HOME_NAME=Oracle_IDM1            ; export ORACLE_HOME_NAME
COMPONENT_NAME=oid1                     ; export COMPONENT_NAME
MSERVER_NAME=wls_ods1                   ; export MSERVER_NAME

# Domain variables
DOMAIN_NAME=IDMDomain                                   ; export DOMAIN_NAME
DOMAIN_HOME=$MW_HOME/user_projects/domains/$DOMAIN_NAME ; export DOMAIN_HOME
DOMAIN_PORT=7001                                        ; export DOMAIN_PORT
DOMAIN_HOST=`hostname -f`                               ; export DOMAIN_HOST

# Misc.
NLS_LANG=AMERICAN_AMERICA.AL32UTF8     ; export NLS_LANG
ORACLE_SID=oidd1                       ; export ORACLE_SID
# Fix for remtool core dumping (SR 3-7786328551): Potential heap errors are silently ignore
MALLOC_CHECK_=0                        ; export MALLOC_CHECK_

# Unset LD_ASSUME_KERNEL
unset LD_ASSUME_KERNEL

# Ensure that OLD_TNS_ADMIN is non-null and use to store current TNS_ADMIN if any
OLD_TNS_ADMIN=${TNS_ADMIN:-NOTSET}
TNS_ADMIN=$ORACLE_INSTANCE/config ; export TNS_ADMIN

# Put new JAVA_HOME in path and remove old one if present
# Ensure that OLD_JAVA_HOME is non-null and use to store current JAVA_HOME if any
OLD_JAVA_HOME=${JAVA_HOME:-NOTSET}
JAVA_HOME=/oracle/app/jdk ; export JAVA_HOME
case "$PATH" in
  *$OLD_JAVA_HOME*)
    PATH=`echo $PATH | sed "s;${OLD_JAVA_HOME};${JAVA_HOME};g"` ; export PATH ;;
  *)
    pathman $JAVA_HOME/bin ;;
esac

# Put new OID binaries in path and remove old one if present
# Ensure that OLD_ORACLE_HOME is non-null and use to store current ORACLE_HOME if any
OLD_ORACLE_HOME=${ORACLE_HOME:-NOTSET}
ORACLE_HOME=$MW_HOME/$ORACLE_HOME_NAME ; export ORACLE_HOME
case "$PATH" in
  *$OLD_ORACLE_HOME*)
    PATH=`echo $PATH | sed "s;${OLD_ORACLE_HOME};${ORACLE_HOME};g"` ; export PATH ;;
esac
pathman $ORACLE_HOME/bin
pathman $ORACLE_HOME/ldap/bin
pathman $ORACLE_HOME/ldap/admin

pathman $ORACLE_INSTANCE/bin

# Cleanup
unset pathman

#! /bin/sh
# ######################################################
# NAME: oidctl.sh
#
# DESC: There is not a single command to startup the OID
#       stack in the 11g release, so this script automates 
#       the startup process.
#
# REQS: The following files need to exist:
#
#       $DOMAIN_HOME/servers/wls_ods1/security/boot.properties
#       $DOMAIN_HOME/servers/AdminServer/security/boot.properties
#
#       Each file must contain the following:
#
#       username=weblogic
#       password=<password>
#
#       The password is automatically obfuscated the next time
#       WebLogic Server is started.
#
# $HeadURL$
# $LastChangedBy$
# $LastChangedDate$
# $LastChangedRevision$
#
# LOG:
# yyyy/mm/dd [user] [version] [Notes]
# 2014/01/16 cgwong v1.0.0 Re-creation from original.
#                   Environment done from 'oracle' user home directory
# ######################################################

# Setup environment/configuration parameters
. ~oracle/bin/OIDenv.sh
SLEEP_TIME_ADM=1
SLEEP_TIME=10

start_stack()
{
  echo "Starting WLS Administration Server ..."
  # Although we redirect stdout and stderr to /dev/null they are redirected to
  # the AdminServer.log file by WLS.
  nohup sh $DOMAIN_HOME/bin/startWebLogic.sh >/dev/null 2>/dev/null &
  # Wait for some seconds to make sure the Admin Server is listening before we attempt
  # to start anything else which needs to connect to it in order for
  # EM to be able to "see" these instances.
  sleep $SLEEP_TIME_ADM
  while [ 1 -gt 0 ]; do
    tail -100 $DOMAIN_HOME/servers/AdminServer/logs/AdminServer.log | grep -i 'Server started in RUNNING mode'
    if [ $? -eq 0 ]; then
      printf "Admin Server is RUNNING.\n"
      break
    fi
    printf "."
    sleep $SLEEP_TIME_ADM
  done
  # Note that the AdminServer is not needed in order to run OID applications
  # or in general any Managed Server of a given WLS domain.
  # As long as we have the Managed Servers running and the OPMN managed 
  # processes running our environment is functional with the only caveat
  # that we cannot access EM or the Weblogic Admin Console.

  # Start the OPMN managed processes for this environment.
  echo "Starting OPMN managed components (OID Servers) ..."
  $ORACLE_INSTANCE/bin/opmnctl startall
  sleep $SLEEP_TIME
  $ORACLE_INSTANCE/bin/opmnctl status

  echo "Starting WLS Managed Server ..."
  nohup $DOMAIN_HOME/bin/startManagedWebLogic.sh $MSERVER_NAME "t3://${DOMAIN_HOST}:${DOMAIN_PORT}" >/dev/null 2>/dev/null &
}

stop_stack()
{
  echo "Stopping WLS Managed Server ..."
  nohup $DOMAIN_HOME/bin/stopManagedWebLogic.sh $MSERVER_NAME "t3://${DOMAIN_HOST}:${DOMAIN_PORT}" >/dev/null 2>/dev/null &

  # Stop the OPMN managed processes for this environment.
  echo "Stopping OPMN managed components (OID Servers) ..."
  $ORACLE_INSTANCE/bin/opmnctl stopall
  sleep $SLEEP_TIME
  $ORACLE_INSTANCE/bin/opmnctl status

  echo "Stopping WLS Administration Server ..."
  # Although we redirect stdout and stderr to /dev/null they are redirected to
  # the AdminServer.log file by WLS.
  nohup sh $DOMAIN_HOME/bin/stopWebLogic.sh >/dev/null 2>/dev/null &
}

check_stack()
{
  # Check OPMN managed processes for this environment.
  $ORACLE_INSTANCE/bin/opmnctl status
}

# See how we were called and take appropriate action.
case "$1" in
  start)
    start_stack
    ;;
  stop)
    stop_stack
    ;;
  check)
    check_stack
    ;;
  clean)
    stop_stack
    start_stack
    ;;
  abort)
    stop_stack
    ;;
esac

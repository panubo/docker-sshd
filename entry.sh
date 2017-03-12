#!/usr/bin/env bash
##
# @file entry.sh
# @brief entry point for docker image, create group and user if required.

# ----------------------------------------------------------------------
# Configure script here
# ----------------------------------------------------------------------
DEBUG="${DEBUG:-false}" ;

# ----------------------------------------------------------------------
# Typically nothing to configure (anymore) below this line
# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
# Function definition section
# Actual code activation can be found below at the
#     "Actual code activation section"
# ----------------------------------------------------------------------

function LVRSE_Initialise
{
    set -e ;

    ${DEBUG} && set -x ;
}

##
# @fn LVRSE_StopTrapHandler
# @brief function to terminate running daemon (if running).
# @sa LVRSE_STOP_TRAP_SIGNALS
function LVRSE_StopTrapHandler
{
    echo "Received SIGINT or SIGTERM. Shutting down $LVRSE_DAEMON"
    trap '' ${LVRSE_STOP_TRAP_SIGNALS[*]} ;
    # Get PID
    local pid=$(cat /var/run/${LVRSE_DAEMON}/${LVRSE_DAEMON}.pid) ;
    if [ -z "${pid}" ] ; then
	echo "Could not find daemon process id." >&2 ;
    else
	kill -SIGTERM "${pid}" ;
	wait "${pid}" ;
    fi ;
    echo "Done."
}

##
# @fn LVRSE_AddSshUsers
# @brief Create user an groups from env. var SSH_USERS
# @sa SSH_USERS
function LVRSE_AddSshUsers
{
    # Add users if SSH_USERS=user:uid:gid set
    if [ -z "${SSH_USERS}" ]; then
        # Warn if no authorized_keys
        if [ ! -e ~/.ssh/authorized_keys ] && [ -z "$(ls -A /etc/authorized_keys)" ]; then
          echo "WARNING: No SSH authorized_keys found!"
        fi ;
    else
        USERS=$(echo $SSH_USERS | tr "," "\n") ;
        for U in $USERS; do
            IFS=':' read -ra UA <<< "$U"
            _NAME="${UA[0]}" ;
            _UID="${UA[1]}" ;
            _GID="${UA[2]}" ;
            GROUP="${_NAME}" ;
    
            ACTUAL_GID="$( awk -F : '/^'"${_NAME}"':/{print $3}' /etc/group )" ;
            GROUPNAME="$( awk -F : '/^[^:]*:[^:]*:'"${_GID}"':/{print $1}' /etc/group )" ;
            if [ -n "${ACUTAL_GID}" ] ; then
                echo ">> usergroup ${GROUP} already defined with gid: ${ACTUAL_GID}." ;
                _GID=${ACTUAL_GID} ;
            elif [ -n "${GROUPNAME}" ] ; then
	        echo ">> group id  ${_GID} already occupied for group: ${GROUPNAME}." ;
	        GROUP="${GROUPNAME}" ;
            else 
                addgroup -g ${_GID} ${GROUP} ;
            fi ;
    	
            ACTUAL_UID="$( awk -F :  '/^'"${_NAME}"':[^:]*:[^:]*:/{print $3}' /etc/passwd )" ;
            ACTUAL_NAME="$( awk -F :  '/^[^:]*:[^:]*:'"${_UID}"':/{print $1}' /etc/passwd )" ;
            if [ -n "${ACUTAL_UID}" ] ; then
                if [ ${ACTUAL_UID} = ${_UID} ] ; then
                    echo ">> user ${_NAME} already existing: ${ACTUAL_UID}." ;
                else
                    echo ">> user ${_NAME} already existing: ${ACTUAL_UID} (instead of ${_UID})." ;
                    _UID=${ACTUAL_UID} ;
                fi ;
            elif [ -n "${ACTUAL_NAME}" ] ; then
                echo ">> user id ${_UID} already in use for user ${ACTUAL_NAME} (instead of ${_NAME})." ;
                _NAME="${ACTUAL_NAME}" ;
            else
                adduser -D -u ${_UID} -G ${GROUP} -s '' ${_NAME} ;
            fi ;
        done ;
    fi
}

##
# @fn LVRSE_CopySshDefaultConfigFromCache
# @brief Copy default config from cache
function LVRSE_CopySshDefaultConfigFromCache
{
    [ -z "$(ls -A /etc/ssh)" ] \
        || [ ! -d /etc/ssh.cache ] \
        || cp -a /etc/ssh.cache/* /etc/ssh/ ;
}

##
# @fn LVRSE_GenerateHostKeys
# @brief Generate Host keys, if required
function LVRSE_GenerateHostKeys
{
    [ -n "$( ls /etc/ssh/ssh_host_* 2>/dev/null )" ] \
        || ssh-keygen -A ;
}

##
# @fn LVRSE_FixSshPermissions
# @brief Fix permissions, if writable
function LVRSE_FixSshPermissions
{
    [ -w ~/.ssh/authorized_keys ] \
        && chown root:root ~/.ssh/authorized_keys \
        && chmod 600 ~/.ssh/authorized_keys ;
    [ -w ~/.ssh ] \
        && chown root:root ~/.ssh \
        && chmod 700 ~/.ssh ;
    
    if [ -w /etc/authorized_keys ]; then
        chown root:root /etc/authorized_keys
        chmod 755 /etc/authorized_keys
        find /etc/authorized_keys/ -type f -exec chmod 644 {} \;
    fi ;
}

# ----------------------------------------------------------------------
# Variable definition section
# ----------------------------------------------------------------------
##
# @def LVRSE_DAEMON
# @brief name of the daemon process to run
LVRSE_DAEMON='sshd' ;

##
# @def LVRSE_STOP_TRAP_SIGNALS
# @brief array with the signals to trap, for stopping the daemon
# @sa LVRSE_StopTrapHandler
LVRSE_STOP_TRAP_SIGNALS=(SIGINT SIGTERM) ;

# ----------------------------------------------------------------------
# Actual code activation section
# ----------------------------------------------------------------------

LVRSE_Initialise ;
LVRSE_CopySshDefaultConfigFromCache ;
LVRSE_GenerateHostKeys ;
LVRSE_FixSshPermissions ;
LVRSE_AddSshUsers

# Update MOTD
if [ -v MOTD ]; then
    echo -e "$MOTD" > /etc/motd
fi

echo "Running $@"
if [ "$(basename $1)" == "$LVRSE_DAEMON" ]; then
    trap LVRSE_StopTrapHandler ${LVRSE_STOP_TRAP_SIGNALS[*]} ;
    $@ &
    pid="$!"
    mkdir -p /var/run/${LVRSE_DAEMON} \
	&& echo "${pid}" > /var/run/${LVRSE_DAEMON}/${LVRSE_DAEMON}.pid ;
    echo "Daemon running as pid ${pid}." ;
    wait "${pid}" ;
    daemon_exit_status=${?} ;
    echo "Daemon ${LVRSE_DAEMON} exited with status ${daemon_exit_status}." ;
    exit ${daemon_exit_status} ;
else
    exec "$@"
    exit_status=${?} ;
    echo "Instruction (${@}) exited with status ${exit_status}." ;
    exit ${exit_status} ;
fi ;

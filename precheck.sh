#!/usr/bin/env bash

readonly DETECTED_PUID=${SUDO_UID:-$UID}
readonly DETECTED_UNAME=$(id -un "${DETECTED_PUID}" 2> /dev/null || true)
readonly DETECTED_PGID=$(id -g "${DETECTED_PUID}" 2> /dev/null || true)
readonly DETECTED_UGROUP=$(id -gn "${DETECTED_PUID}" 2> /dev/null || true)
readonly DETECTED_HOMEDIR=$(eval echo "~${DETECTED_UNAME}" 2> /dev/null || true)
readonly PRECHECK_DIR="${DETECTED_HOMEDIR}/precheck"

if [[ ! -d "${PRECHECK_DIR}" ]]; then
    mkdir -p "${PRECHECK_DIR}"
fi

if [[ -f "${PRECHECK_DIR}/precheck.config" ]]; then
    source "${PRECHECK_DIR}/precheck.config"
fi

start=$(date +%s)
start_display=$(date)
duration=""
elapsed_minutes="none"
APT_COUNT_LAST=0
APT_COUNT_LAST_ELAPSED_MINUTES=0
UPDATE_COUNT_LAST=0
UPDATE_COUNT_LAST_ELAPSED_MINUTES=0
UPGRADE_COUNT_LAST=0
UPGRADE_COUNT_LAST_ELAPSED_MINUTES=0
WAIT_TIME=5
WAIT_UPTIME=10
WAIT_COMPLETE=0
DNS_PASS=1
FAILED=0

# Colors
# https://misc.flogisoft.com/bash/tip_colors_and_formatting
readonly BLU='\e[34m'
readonly GRN='\e[32m'
readonly RED='\e[31m'
readonly YLW='\e[33m'
readonly NC='\e[0m'

# Log Functions
readonly LOG_FILE="${PRECHECK_DIR}/precheck.log"
sudo chown "${DETECTED_PUID:-$DETECTED_UNAME}":"${DETECTED_PGID:-$DETECTED_UGROUP}" "${LOG_FILE}" > /dev/null 2>&1 || true # This line should always use sudo
log() {
    if [[ -v DEBUG && $DEBUG == 1 ]] || [[ -v VERBOSE && $VERBOSE == 1 ]] || [[ -v DEVMODE && $DEVMODE == 1 ]]; then
        echo -e "${NC}$(date +"%F %T") ${BLU}[LOG]${NC}        $*${NC}" | tee -a "${LOG_FILE}";
    else
        echo -e "${NC}$(date +"%F %T") ${BLU}[LOG]${NC}        $*${NC}" | tee -a "${LOG_FILE}" > /dev/null;
    fi
}
info() { echo -e "${NC}$(date +"%F %T") ${BLU}[INFO]${NC}       $*${NC}" | tee -a "${LOG_FILE}"; }
warning() { echo -e "${NC}$(date +"%F %T") ${YLW}[WARNING]${NC}    $*${NC}" | tee -a "${LOG_FILE}"; }
error() { echo -e "${NC}$(date +"%F %T") ${RED}[ERROR]${NC}      $*${NC}" | tee -a "${LOG_FILE}"; }
fatal() {
    echo -e "${NC}$(date +"%F %T") ${RED}[FATAL]${NC}      $*${NC}" | tee -a "${LOG_FILE}"
    exit 1
}
debug() {
    if [[ -v DEBUG && $DEBUG == 1 ]] || [[ -v VERBOSE && $VERBOSE == 1 ]] || [[ -v DEVMODE && $DEVMODE == 1 ]]; then
        echo -e "${NC}$(date +"%F %T") ${GRN}[DEBUG]${NC}      $*${NC}" | tee -a "${LOG_FILE}"
    fi
}

exec 2> >(tee -a "${LOG_FILE}")

if [[ ${DETECTED_PUID} == "0" ]] || [[ ${DETECTED_HOMEDIR} == "/root" ]]; then
    error "Running as root is not supported. Please run as a standard user with sudo."
    exit 1
fi

if [[ ${DEV_BRANCH:-} == "development" ]]; then
    if [[ ${PRECHECK_BRANCH:-} == "" ]]; then
        warning "PRECHECK_BRANCH not set. Defaulting to master"
    fi
    if [[ ${SETUP_BRANCH:-} == "" ]]; then
        warning "SETUP_BRANCH not set. Defaulting to origin/master"
    fi
fi

if [[ ${EUID} -ne 0 ]]; then
    if [[ ${DEV_MODE:-} == "local" && -f "${DETECTED_HOMEDIR}/precheck.sh" ]]; then
        exec sudo bash precheck.sh
    else
        exec sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/openflixr/Docs/${PRECHECK_BRANCH:-master}/precheck.sh)"
    fi
fi

info " ------ Starting precheck ------"

if [[ ! -f "${PRECHECK_DIR}/uptimecomplete" ]]; then
    echo ""
    info "Waiting for the system to have been running for ${WAIT_UPTIME} minutes"
    while (true); do
        UPTIME_HOURS=$(awk '{print int($1/3600)}' /proc/uptime)
        UPTIME_MINUTES=$(awk '{print int(($1%3600)/60)}' /proc/uptime)
        UPTIME_SECONDS=$(awk '{print int($1%60)}' /proc/uptime)
        if [[ ${UPTIME_HOURS} -gt 0 || ${UPTIME_MINUTES} -ge ${WAIT_UPTIME} ]]; then
            touch "${PRECHECK_DIR}/uptimecomplete"
            info "- Wait complete!"
            break
        else
            echo -en "\rCurrent Uptime: ${UPTIME_HOURS} hours ${UPTIME_MINUTES} minutes ${UPTIME_SECONDS} seconds    "
        fi
        sleep 5s
    done
else
    info "System uptime check already completed!"
fi

if [[ ! -f "${PRECHECK_DIR}/processcheckcomplete" ]]; then
    info "Waiting for the system to finish some processes..."
    while (true); do
        clear
        elapsed=$(($(date +%s)-$start))
        duration=$(date -ud @$elapsed +'%M minutes %S seconds')
        echo ""
        echo "Waiting for the system to finish some processes..."
        echo "Started: ${start_display}"
        echo "Now:     $(date)"
        echo "Elapsed: ${duration}"
        APT_COUNT=$(ps -ef | grep apt | grep -v tail | grep -v grep | wc -l)
        echo " - Apt processes remaining: ${APT_COUNT}"
        if [[ ${APT_COUNT} != 0 && ${APT_COUNT_LAST_ELAPSED:-} != "" ]]; then
            echo "   Last changed: $(date -ud @${APT_COUNT_LAST_ELAPSED} +'%M minutes %S seconds')"
        else
            echo ""
        fi

        UPDATE_COUNT=$(ps -ef | grep update | grep -v "no-update" | grep -v tail | grep -v shellinabox | grep -v grep | wc -l)
        echo " - Update processes remaining: ${UPDATE_COUNT}"
        if [[ ${UPDATE_COUNT} != 0 && ${UPDATE_COUNT_LAST_ELAPSED:-} != "" ]]; then
            echo "   Last changed: $(date -ud @${UPDATE_COUNT_LAST_ELAPSED} +'%M minutes %S seconds')"
        else
            echo ""
        fi

        UPGRADE_COUNT=$(ps -ef | grep upgrade | grep -v tail | grep -v shellinabox | grep -v unattended-upgrade | grep -v grep | wc -l)
        echo " - Upgrade processes remaining: ${UPGRADE_COUNT}"
        if [[ ${UPGRADE_COUNT} != 0 && ${UPGRADE_COUNT_LAST_ELAPSED:-} != "" ]]; then
            echo "   Last changed: $(date -ud @${UPGRADE_COUNT_LAST_ELAPSED} +'%M minutes %S seconds')"
        else
            echo ""
        fi

        if [[ ${APT_COUNT} = 0 && ${UPDATE_COUNT} = 0 && ${UPGRADE_COUNT} = 0 ]]; then
            WAIT_COMPLETE=1
            touch "${PRECHECK_DIR}/processcheckcomplete"
            info "- Completed!"
            log "  Elapsed: ${duration}"
            break
        elif [[ ${APT_COUNT_LAST_ELAPSED_MINUTES#0} -ge ${WAIT_TIME} || ${UPDATE_COUNT_LAST_ELAPSED_MINUTES#0} -ge ${WAIT_TIME} || ${UPGRADE_COUNT_LAST_ELAPSED_MINUTES#0} -ge ${WAIT_TIME} ]]; then
            echo "> It has been more than ${WAIT_TIME} minutes since at least one of the above changed..."
            echo "> You might want to consider rebooting but you can wait, it just might take a while."
            echo "> Press Ctrl+C or Cmd+C to exit this script at any time."
            echo "> 'sudo reboot' can be used to reboot the machine and this script will run again automatically when you log in again."
            if [[ $(grep -c "precheck.sh" ".bashrc") == 0 ]]; then
                log "- Adding precheck script to .bashrc"
                echo "" >> .bashrc
                echo 'echo "Running precheck script"' >> .bashrc
                if [[ -f "$precheck.sh" ]]; then
                    echo 'bash precheck.sh' >> .bashrc
                else
                    echo 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/openflixr/Docs/'${PRECHECK_BRANCH:-master}'/precheck.sh)"' >> .bashrc
                fi
            fi
        else
            echo "> Keep waiting..."
        fi

        if [[ ${APT_COUNT} != ${APT_COUNT_LAST} ]]; then
            APT_COUNT_LAST=${APT_COUNT}
            APT_COUNT_CHANGED=$(date +%s)
        elif [[ ${APT_COUNT} == 0 ]]; then
            APT_COUNT_CHANGED=""
        fi
        if [[ ${APT_COUNT_CHANGED:-} != "" ]]; then
            APT_COUNT_LAST_ELAPSED=$(($(date +%s)-${APT_COUNT_CHANGED}))
            APT_COUNT_LAST_ELAPSED_MINUTES=$(date -ud @${APT_COUNT_LAST_ELAPSED} +%M)
        fi

        if [[ ${UPDATE_COUNT} != ${UPDATE_COUNT_LAST} ]]; then
            UPDATE_COUNT_LAST=${UPDATE_COUNT}
            UPDATE_COUNT_CHANGED=$(date +%s)
        elif [[ ${UPDATE_COUNT} == 0 ]]; then
            UPDATE_COUNT_CHANGED=""
        fi
        if [[ ${UPDATE_COUNT_CHANGED:-} != "" ]]; then
            UPDATE_COUNT_LAST_ELAPSED=$(($(date +%s)-${UPDATE_COUNT_CHANGED}))
            UPDATE_COUNT_LAST_ELAPSED_MINUTES=$(date -ud @${UPDATE_COUNT_LAST_ELAPSED} +%M)
        fi

        if [[ ${UPGRADE_COUNT} != ${UPGRADE_COUNT_LAST} ]]; then
            UPGRADE_COUNT_LAST=${UPGRADE_COUNT}
            UPGRADE_COUNT_CHANGED=$(date +%s)
        elif [[ ${UPGRADE_COUNT} == 0 ]]; then
            UPGRADE_COUNT_CHANGED=""
        fi
        if [[ ${UPGRADE_COUNT_CHANGED:-} != "" ]]; then
            UPGRADE_COUNT_LAST_ELAPSED=$(($(date +%s)-${UPGRADE_COUNT_CHANGED}))
            UPGRADE_COUNT_LAST_ELAPSED_MINUTES=$(date -ud @${UPGRADE_COUNT_LAST_ELAPSED} +%M)
        fi

        sleep 5;
    done
else
    WAIT_COMPLETE=1
    info "Process check already completed!"
fi

if [[ ! -f "${PRECHECK_DIR}/fixescomplete" ]]; then
    echo ""
    info "Putting some fixes in place..."
    info "These fixes can be run again later using 'setupopenflixr'"
    echo ""
    info "- Getting latest for 'setupopenflixr'"
    if [[ -d /opt/OpenFLIXR2.SetupScript/.git ]] && [[ -d /opt/OpenFLIXR2.SetupScript/.scripts ]]; then
        cd "/opt/OpenFLIXR2.SetupScript/" || fatal "Failed to change to '/opt/OpenFLIXR2.SetupScript/' directory."
        info "  Fetching recent changes from git."
        git fetch > /dev/null 2>&1 || fatal "Failed to fetch recent changes from git."
        GH_COMMIT=$(git rev-parse --short ${SETUP_BRANCH:-origin/master})
        info "  Updating OpenFLIXR2 Setup Script to '${GH_COMMIT}' on '${SETUP_BRANCH:-origin/master}'."
        git reset --hard "${SETUP_BRANCH:-origin/master}" > /dev/null 2>&1 || fatal "Failed to reset to '${SETUP_BRANCH:-origin/master}'."
        git pull > /dev/null 2>&1 || fatal "Failed to pull recent changes from git."
        git for-each-ref --format '%(refname:short)' refs/heads | grep -v master | xargs git branch -D > /dev/null 2>&1 || true
        chmod +x "/opt/OpenFLIXR2.SetupScript/main.sh" > /dev/null 2>&1 || fatal "OpenFLIXR2 Setup Script must be executable."
        info "  OpenFLIXR2 Setup Script has been updated to '${GH_COMMIT}' on '${SETUP_BRANCH:-origin/master}'"
    else
        if [[ -d /opt/OpenFLIXR2.SetupScript/ ]]; then
            rm -r /opt/OpenFLIXR2.SetupScript/
        fi
        git clone https://github.com/openflixr/OpenFLIXR2.SetupScript /opt/OpenFLIXR2.SetupScript
    fi
    if [[ ${DEV_MODE:-} == "local" && -d "${DETECTED_HOMEDIR}/OpenFLIXR2.SetupScript/" ]]; then
        cp -r "${DETECTED_HOMEDIR}/OpenFLIXR2.SetupScript/main.sh" "/opt/OpenFLIXR2.SetupScript/"
        cp -r "${DETECTED_HOMEDIR}/OpenFLIXR2.SetupScript/.scripts" "/opt/OpenFLIXR2.SetupScript/"
    fi
    echo ""
    echo ""

    if [[ -f "'/etc/apt/sources.list.d/nijel-ubuntu-phpmyadmin-xenial.list" || -f "/etc/apt/sources.list.d/nijel-ubuntu-phpmyadmin-xenial.list.save" ]]; then
        info "- Removing bad sources (nijel/phpmyadmin)"
        if [[ -f "'/etc/apt/sources.list.d/nijel-ubuntu-phpmyadmin-xenial.list" ]]; then
            rm /etc/apt/sources.list.d/nijel-ubuntu-phpmyadmin-xenial.list
        fi
        if [[ -f "/etc/apt/sources.list.d/nijel-ubuntu-phpmyadmin-xenial.list.save" ]]; then
            rm /etc/apt/sources.list.d/nijel-ubuntu-phpmyadmin-xenial.list.save
        fi
        echo ""
    fi
    info "- Fixing setupopenflixr symlink"
    bash /opt/OpenFLIXR2.SetupScript/main.sh -s
    info "- Running 'setupopenflixr -f {fix name}' to do fixes"
    info "  - Updater"
    bash /opt/OpenFLIXR2.SetupScript/main.sh -f updater || error "  - Unable to run command or an error occurred..."
    info "  - Mono"
    bash /opt/OpenFLIXR2.SetupScript/main.sh -f mono || error "  - Unable to run command or an error occurred..."
    info "  - Redis"
    bash /opt/OpenFLIXR2.SetupScript/main.sh -f redis || error "  - Unable to run command or an error occurred..."
    info "  - PHP"
    bash /opt/OpenFLIXR2.SetupScript/main.sh -f php || error "  - Unable to run command or an error occurred..."
    info "- Fixes completed"
    touch "${PRECHECK_DIR}/fixescomplete"
else
    info "Fixes already completed!"
fi

if [[ ! -f "${PRECHECK_DIR}/dnscheckcomplete" ]]; then
    echo ""
    info "Doing some basic DNS checks..."
    warning "If any of these fail, you might have issues in the next steps."
    dns_servers_ips=("8.8.8.8" "208.67.222.222" "127.0.0.1" "")
    dns_servers_names=("Google" "OpenDNS" "OpenFLIXR Local Resolution" "OpenFLIXR Auto DNS Resolution")
    websites=("example.com" "google.com" "github.com")

    for dns_server_index in ${!dns_servers_ips[@]}; do
        dns_server_ip=${dns_servers_ips[${dns_server_index}]}
        dns_servers_name=${dns_servers_names[${dns_server_index}]}
        for website in ${websites[@]}; do
            if [[ ${dns_server_ip} == "" ]]; then
                info "- Checking ${website} via ${dns_servers_name}"
                dig ${website} > /dev/null
            else
                info "- Checking ${website} via ${dns_servers_name} (${dns_server_ip})"
                dig @${dns_server_ip} ${website} > /dev/null
            fi
            return_code=$?
            if [[ ${return_code} -eq 0 ]]; then
                info "  Good!"
            else
                DNS_PASS=0
                case "${return_code}" in
                    1)
                        error "  I messed up..."
                        ;;
                    8)
                        error "  This shouldn't have happened..."
                        ;;
                    9)
                        error "  No reply from server..."
                        ;;
                    10)
                        error "  dig internal error..."
                        ;;
                esac
            fi
        done
    done
    info "- DNS Check complete"
else
    DNS_PASS=1
    info "DNS Checks already completed!"
fi
if [[ ${DNS_PASS} == 1 ]]; then
    touch "${PRECHECK_DIR}/dnscheckcomplete"
fi
echo ""
if [[ ${WAIT_COMPLETE} == 1 ]]; then
    sed -i 's#echo "Running precheck script"##g' ".bashrc"
    sed -i 's#bash precheck.sh##g' ".bashrc"
    sed -i 's#bash -c "$(curl -fsSL https://raw.githubusercontent.com/openflixr/Docs/.*/precheck.sh)"##g' ".bashrc"
fi
if [[ ${WAIT_COMPLETE} == 1 && ${DNS_PASS} == 1 ]]; then
    info "|------------------------------------------------|"
    info "| OpenFLIXR is PROBABLY ready for the next step! |"
    if [[ ! -f "${PRECHECK_DIR}/rebootselected" ]]; then
        info "| REBOOT RECOMMENDED!                            |"
    fi
    info "|------------------------------------------------|"
    if [[ ! -f "${PRECHECK_DIR}/rebootselected" ]]; then
        echo ""
        while true; do
            read -t60 -p 'Do you want to reboot now? (Automatically YES after 60 seconds) [Y/n]: ' reboot
            if [ $? -gt 128 ]; then
                reboot="Y"
            fi
            case ${reboot} in
                [yY]*)
                    touch "${PRECHECK_DIR}/rebootselected"
                    reboot
                    ;;
                [nN]*)
                    warning "Not rebooting!"
                    ;;
                *)
                    echo "Please enter Y, Yes, N, or No"
                    ;;
            esac
        done
    fi
else
    warning "> Something went wrong and you probably shouldn't continue... "
    warning "> Check the wiki for troubleshooting information."
    warning "> If further help is needed, join OpenFLIXR's Discord Server or post on the forums for assistance"
fi

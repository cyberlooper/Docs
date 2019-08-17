#!/usr/bin/env bash

readonly DETECTED_PUID=${SUDO_UID:-$UID}
readonly DETECTED_UNAME=$(id -un "${DETECTED_PUID}" 2> /dev/null || true)
readonly DETECTED_PGID=$(id -g "${DETECTED_PUID}" 2> /dev/null || true)
readonly DETECTED_UGROUP=$(id -gn "${DETECTED_PUID}" 2> /dev/null || true)
readonly DETECTED_HOMEDIR=$(eval echo "~${DETECTED_UNAME}" 2> /dev/null || true)

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

exec 1> >(tee -a precheck.log) 2>&1

if [[ ${DETECTED_PUID} == "0" ]] || [[ ${DETECTED_HOMEDIR} == "/root" ]]; then
    echo "Running as root is not supported. Please run as a standard user with sudo."
    exit 1
fi
if [[ ${EUID} -ne 0 ]]; then
    exec sudo bash precheck.sh
fi

TODAY=$(date)
echo "-----------------------------------------------------"
echo "Date:          $TODAY"
echo "-----------------------------------------------------"

if [[ ! -f "precheck_nouptime" ]]; then
    echo ""
    echo "Waiting for the system to have been running for ${WAIT_UPTIME} minutes"
    while (true); do
        UPTIME_HOURS=$(awk '{print int($1/3600)}' /proc/uptime)
        UPTIME_MINUTES=$(awk '{print int(($1%3600)/60)}' /proc/uptime)
        UPTIME_SECONDS=$(awk '{print int($1%60)}' /proc/uptime)
        if [[ ${UPTIME_HOURS} -gt 0 || ${UPTIME_MINUTES} -ge ${WAIT_UPTIME} ]]; then
            touch precheck_nouptime
            break
        else
            echo -en "\rCurrent Uptime: ${UPTIME_HOURS} hours ${UPTIME_MINUTES} minutes ${UPTIME_SECONDS} seconds"
        fi
        sleep 5s
    done
fi

while (true); do
    clear
    elapsed=$(($(date +%s)-$start))
    duration=$(date -ud @$elapsed +'%M minutes %S seconds')
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
        echo "> Completed!"
        break
    elif [[ ${APT_COUNT_LAST_ELAPSED_MINUTES#0} -ge ${WAIT_TIME} || ${UPDATE_COUNT_LAST_ELAPSED_MINUTES#0} -ge ${WAIT_TIME} || ${UPGRADE_COUNT_LAST_ELAPSED_MINUTES#0} -ge ${WAIT_TIME} ]]; then
        echo "> It has been more than ${WAIT_TIME} minutes since at least one of the above changed..."
        echo "> You might want to consider rebooting and running this script again."
        echo "> Press Ctrl+C or Cmd+C to exit this script at any time."
        echo "> 'sudo reboot' can be used to reboot the machine."
    else
        echo "> Keep waiting..."
    fi

    if [[ ${APT_COUNT} != ${APT_COUNT_LAST} ]]; then
        APT_COUNT_LAST=${APT_COUNT}
        APT_COUNT_CHANGED=$(date +%s)
    fi
    if [[ ${APT_COUNT_CHANGED:-} != "" ]]; then
        APT_COUNT_LAST_ELAPSED=$(($(date +%s)-${APT_COUNT_CHANGED}))
        APT_COUNT_LAST_ELAPSED_MINUTES=$(date -ud @${APT_COUNT_LAST_ELAPSED} +%M)
    fi

    if [[ ${UPDATE_COUNT} != ${UPDATE_COUNT_LAST} ]]; then
        UPDATE_COUNT_LAST=${UPDATE_COUNT}
        UPDATE_COUNT_CHANGED=$(date +%s)
    fi
    if [[ ${UPDATE_COUNT_CHANGED:-} != "" ]]; then
        UPDATE_COUNT_LAST_ELAPSED=$(($(date +%s)-${UPDATE_COUNT_CHANGED}))
        UPDATE_COUNT_LAST_ELAPSED_MINUTES=$(date -ud @${UPDATE_COUNT_LAST_ELAPSED} +%M)
    fi

    if [[ ${UPGRADE_COUNT} != ${UPGRADE_COUNT_LAST} ]]; then
        UPGRADE_COUNT_LAST=${UPGRADE_COUNT}
        UPGRADE_COUNT_CHANGED=$(date +%s)
    fi
    if [[ ${UPGRADE_COUNT_CHANGED:-} != "" ]]; then
        UPGRADE_COUNT_LAST_ELAPSED=$(($(date +%s)-${UPGRADE_COUNT_CHANGED}))
        UPGRADE_COUNT_LAST_ELAPSED_MINUTES=$(date -ud @${UPGRADE_COUNT_LAST_ELAPSED} +%M)
    fi

    sleep 5;
done

echo ""
echo "Putting some fixes in place..."
echo ""
echo "Updating setup page"
if [[ ! -f "/usr/share/nginx/html/setup/index.php.orig" ]]; then
    cp /usr/share/nginx/html/setup/index.php /usr/share/nginx/html/setup/index.php.orig
fi
if [[ ! -f "/usr/share/nginx/html/setup/index.php.placeholder" ]]; then
    echo "If you are seeing this, your system isn't ready..." > index.php.placeholder
    mv index.php.placeholder /usr/share/nginx/html/setup/index.php.placeholder
    mv /usr/share/nginx/html/setup/index.php.placeholder /usr/share/nginx/html/setup/index.php
else
    mv /usr/share/nginx/html/setup/index.php.placeholder /usr/share/nginx/html/setup/index.php
fi

echo ""
echo "Fixing mono"
if [[ ! -f "/etc/mono/config.openflixr" ]]; then
    mv "/etc/mono/config" "/etc/mono/config.openflixr"
fi
if [[ -f "/etc/mono/config.dpkg-new" ]]; then
    cp "/etc/mono/config.dpkg-new" "/etc/mono/config"
fi

echo ""
echo "Fixing redis config"
sed -i "s/bind 127.0.0.1 ::1/bind 127.0.0.1/g" "/etc/redis/redis.conf"

echo ""
echo "Fixing php"
export DEBIAN_FRONTEND=noninteractive
export UCF_FORCE_CONFFNEW=1
apt-get -y -o Dpkg::Options::=--force-confnew install php7.3-fpm
export DEBIAN_FRONTEND=
export UCF_FORCE_CONFFNEW=

echo ""
echo "Doing some basic DNS checks..."
echo "If any of these fail, you might have issues in the next steps."
dns_servers_ips=("8.8.8.8" "208.67.222.222" "127.0.0.1" "")
dns_servers_names=("Google" "OpenDNS" "OpenFLIXR Local Resolution" "OpenFLIXR Auto DNS Resolution")
websites=("example.com" "google.com" "github.com")

for dns_server_index in ${!dns_servers_ips[@]}; do
    dns_server_ip=${dns_servers_ips[${dns_server_index}]}
    dns_servers_name=${dns_servers_names[${dns_server_index}]}
    for website in ${websites[@]}; do
        if [[ ${dns_server_ip} == "" ]]; then
            echo "- Checking ${website} via ${dns_servers_name}"
            dig ${website} > /dev/null
        else
            echo "- Checking ${website} via ${dns_servers_name} (${dns_server_ip})"
            dig @${dns_server_ip} ${website} > /dev/null
        fi
        return_code=$?
        if [[ ${return_code} -eq 0 ]]; then
            echo "  Good!"
        else
            DNS_PASS=0
            case "${return_code}" in
                1)
                    echo "  I messed up..."
                    ;;
                8)
                    echo "  This shouldn't have happened..."
                    ;;
                9)
                    echo "  No reply from server..."
                    ;;
                10)
                    echo "  dig internal error..."
                    ;;
            esac
        fi
    done
done

echo ""
if [[ ${WAIT_COMPLETE} == 1 && ${DNS_PASS} == 1 ]]; then
    echo "|------------------------------------------------|"
    echo "| OpenFLIXR is PROBABLY ready for the next step! |"
    echo "|------------------------------------------------|"
else
    echo "> Something went wrong and you probably shouldn't continue... "
    echo "> Check the wiki for troubleshooting information."
    echo "> If further help is needed, join OpenFLIXR's Discord Server or post on the forums for assistance"
fi

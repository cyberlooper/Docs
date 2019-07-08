start=$(date +%s)
start_display=$(date)
duration=""
elapsed_minutes="none"
APT_COUNT_LAST=0
UPDATE_COUNT_LAST=0
UPGRADE_COUNT_LAST=0
WAIT_TIME=5
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

    UPDATE_COUNT=$(ps -ef | grep update | grep -v tail | grep -v shellinabox | grep -v grep | wc -l)
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
        echo "|------------------------------------------------|"
        echo "| OpenFLIXR is probably ready for the next step! |"
        echo "|------------------------------------------------|"
        exit
    elif [[ ${APT_COUNT_LAST_ELAPSED_MINUTES#0} -ge ${WAIT_TIME} || ${UPDATE_COUNT_LAST_ELAPSED_MINUTES#0} -ge ${WAIT_TIME} || ${UPGRADE_COUNT_LAST_ELAPSED#0} -ge ${WAIT_TIME} ]]; then
        echo "> It has been more than ${WAIT_TIME} minutes since at least one of the above changed..."
        echo "> You might want to consider rebooting and running this script again."
        echo "> Press Ctrl+C or Cmd+C to exit this script at any time."
        echo "> 'sudo reboot' can be used to reboot the machine."
    else
        echo "> Keep waiting..."
    fi

    if [[ ${APT_COUNT} != ${APT_COUNT_LAST} ]]; then
        APT_COUNT_LAST=${APT_COUNT}
        APT_COUNT_LAST_ELAPSED=$(($(date +%s)-$start))
        APT_COUNT_LAST_ELAPSED_MINUTES=$(date -ud @${APT_COUNT_LAST_ELAPSED} +%M)
    fi

    if [[ ${UPDATE_COUNT} != ${UPDATE_COUNT_LAST} ]]; then
        UPDATE_COUNT_LAST=${APT_COUNT}
        UPDATE_COUNT_LAST_ELAPSED=$(($(date +%s)-$start))
        UPDATE_COUNT_LAST_ELAPSED_MINUTES=$(date -ud @${UPDATE_COUNT_LAST_ELAPSED} +%M)
    fi

    if [[ ${UPGRADE_COUNT} != ${UPGRADE_COUNT_LAST} ]]; then
        UPGRADE_COUNT_LAST=${APT_COUNT}
        UPGRADE_COUNT_LAST_ELAPSED=$(($(date +%s)-$start))
        UPGRADE_COUNT_LAST_ELAPSED_MINUTES=$(date -ud @${UPGRADE_COUNT_LAST_ELAPSED} +%M)
    fi

    sleep 5;
done

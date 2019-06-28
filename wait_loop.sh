start=$(date)
while (true); do
    clear
    echo "Started: ${start}"
    echo "Now:     $(date)"
    AP_COUNT=$(ps -ef | grep apt | grep -v tail | grep -v grep | wc -l)
    echo " - Apt processes remaining: ${AP_COUNT}"

    UPDATE_COUNT=$(ps -ef | grep update | grep -v tail | grep -v shellinabox | grep -v grep | wc -l)
    echo " - Update processes remaining: ${UPDATE_COUNT}"

    UPGRADE_COUNT=$(ps -ef | grep upgrade | grep -v tail | grep -v shellinabox | grep -v unattended-upgrade | grep -v grep | wc -l)
    echo " - Upgrade processes remaining: ${UPGRADE_COUNT}"

    if [[ ${AP_COUNT:-} = 0 && ${UPDATE_COUNT:-} = 0 && ${UPGRADE_COUNT:-} = 0 ]]; then
        echo "|------------------------------------------------|"
        echo "| OpenFLIXR is probably ready for the next step! |"
        echo "|------------------------------------------------|"
        exit
    else
        echo "> Keep waiting <"
    fi

    sleep 1;
done

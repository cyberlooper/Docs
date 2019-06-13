while (true); do
    clear
    date
    echo "-- APT --"
    ps -ef | grep apt | grep -v tail | grep -v grep && printf "\n" || APT_DONE=1
    if [[ ${APT_DONE:-} = 1 ]]; then
        echo "No apt processes remaining"
    fi
    echo "-- UPDATE --"
    ps -ef | grep update | grep -v tail | grep -v grep && printf "\n" || UPDATE_DONE=1
    if [[ ${UPDATE_DONE:-} = 1 ]]; then
        echo "No update processes remaining"
    fi
    echo "-- UPGRADE --"
    ps -ef | grep upgrade | grep -v tail | grep -v grep || UPGRADE_DONE=1
    if [[ ${UPGRADE_DONE:-} = 1 ]]; then
        echo "No upgrade processes remaining"
    fi

    if [[ ${APT_DONE:-} = 1 && ${UPDATE_DONE:-} = 1 && ${UPGRADE_DONE:-} = 1 ]]; then
        clear
        echo "OpenFLIXR is probably ready for the next step!"
        exit
    fi

    sleep 1;
done

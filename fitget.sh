#!/bin/bash

#
# Fetches training statistics for a registred member of http://fitness.dk
#
# Requirements: wget
#


###############################################################################
# CONFIG
###############################################################################

if [[ -s "fitget.conf" ]]; then
    source "fitget.conf"     # Local overrides
fi
pushd ${BASH_SOURCE%/*} > /dev/null
if [[ -s "fitget.conf" ]]; then
    source "fitget.conf"     # Local overrides
fi
: ${LOGIN:="12a3456"}
: ${PASSWORD:="S3€R37"}

: ${DEBUG:="false"] # If true, temporary files are not deleted

: ${LOGIN_PAGE:="https://www.fitnessdk.dk/user"}
: ${LOGIN_POST:="https://www.fitnessdk.dk/user"}
: ${DATA_URL_PREFIX:="https://www.fitnessdk.dk/info/training"}
: ${LOGOUT_PAGE:="https://www.fitnessdk.dk/user/logout"}
popd > /dev/null

usage() {
    echo "Usage: ./fitget.sh"
    echo ""
    echo "See README.md on how to specify LOGIN + PASSWORD using config file or specify directly with"
    echo "LOGIN=\"12a3456\" PASSWORD=\"S3€R37\" ./fitget.sh"
    exit $1
}

check_parameters() {
    if [[ "." == ".$LOGIN" || ".$LOGIN" == ".12a3456" ]]; then
        >&2 echo "Error: LOGIN not specified"
        usage 2
    fi
    if [[ "." == ".$PASSWORD" ]]; then
        >&2 echo "Error: Empty PASSWORD"
        usage 3
    fi
    if [[ ".S3€R37" == ".$PASSWORD" ]]; then
        >&2 echo "Warning: Password is the sample password. This is probably not intended"
    fi
    if [[ ! -s "fitget.json" ]]; then
        touch "fitget.json"
    fi
}

################################################################################
# FUNCTIONS
################################################################################

delete() {
    local FILE="$1"
    if [[ ".true" == ".$DEBUG" ]]; then
        echo "File '$FILE' marked for deletion but DEBUG==true so it is kept"
        return
    fi
    rm "$FILE"
}

log_in() {
    echo "- Logging in to $LOGIN_PAGE"
    wget --no-verbose --keep-session-cookies --save-cookies fitget.cookies "$LOGIN_PAGE" -O temp_login.html > /dev/null
    FBI=$(grep form_build_id temp_login.html | sed 's/.*value="\([^"]*\)".*/\1/')
    delete "temp_login.html"
    if [[ "." == "$FBI" ]]; then
        >&2 echo "Error: Unable to locate form_build_id on login page $LOGIN_PAGE"
    fi
    wget --no-verbose --load-cookies fitget.cookies --keep-session-cookies --save-cookies fitget.cookies --post-data "name=${LOGIN}&pass=${PASSWORD}&form_build_id=${FBI}&form_id=user_login&op=Log+ind" "$LOGIN_POST" -O "temp_loggedin.html" > /dev/null
    delete "temp_loggedin.html"
}

# Merges the given data into fidget.dat, eliminating duplicates
absorb() {
    local T=$(mktemp)
    cat "fitget.json" "$1" > "$T"
    cat "$T" | LC_ALL=C sort | LC_ALL=C uniq > "fitget.json"
    rm "$T"
}

fetch_data() {
    if [[ -s "fitget.json" ]]; then
        local LAST=$(tail -n 1 "fitget.json")
    else
        local LAST=""
    fi
    local YEAR=$(date +%Y)
    local MONTH=$(date +%m)
    while [[ true ]]; do
        echo "- Fetching data for ${YEAR}-${MONTH}"
        wget --no-verbose --load-cookies fitget.cookies --keep-session-cookies --save-cookies fitget.cookies "${DATA_URL_PREFIX}?month=${MONTH}&year=${YEAR}" -O "temp_data_${YEAR}-${MONTH}.html" > /dev/null
        grep -A 9999 '<table>' temp_data_${YEAR}-${MONTH}.html | grep -B 9999 '</table>' | grep -o "<tr[^>]*><td.*" | sed 's/.*<td[^>]*>\([^<]*\)<\/td>[^<]*<td[^>]*>\([^<]*\)<\/td>[^<]*<td[^>]*>\([^<]*\)<\/td>[^<]*<td[^>]*>\([^<]*\)<\/td>.*/{"time":"\1 \2", "activity":"\3", "place":"\4"}/' > "temp_data_${YEAR}-${MONTH}.dat"
        delete "temp_data_${YEAR}-${MONTH}.html"
        if [[ ! -s "temp_data_${YEAR}-${MONTH}.dat" ]]; then
            # TODO: Add override to handle months wihout activity
            echo "- Stopped fetching at ${YEAR}-${MONTH} as there were no data"
            delete "temp_data_${YEAR}-${MONTH}.dat"
            break
        fi
        absorb "temp_data_${YEAR}-${MONTH}.dat"
        if [[ "." != ".$LAST" && "." != .$(grep -F "$LAST" "temp_data_${YEAR}-${MONTH}.dat") ]]; then
            echo "- Stopped fetching at ${YEAR}-${MONTH} as data-overlap was detected"
            delete "temp_data_${YEAR}-${MONTH}.dat"
            break
        fi
        delete "temp_data_${YEAR}-${MONTH}.dat"
        MONTH=$(( MONTH-1 ))
        if [[ "$MONTH" -eq "0" ]]; then
            MONTH="12"
            YEAR=$(( YEAR-1 ))
        fi
    done
}

log_out() {
    wget --no-verbose --load-cookies fitget.cookies --keep-session-cookies --save-cookies fitget.cookies "$LOGOUT_PAGE" -O "temp_logout.html" > /dev/null
    delete "temp_logout.html"
    delete "fitget.cookies"
}


###############################################################################
# CODE
###############################################################################

check_parameters "$@"

log_in
fetch_data
log_out
echo "Data available in fitget.json"

#!/bin/sh

## slacheck - a simple Bash script for monitoring HTTP service availability.
## Copyright (c) 2014 Thomas Szteliga <ts@websafe.pl>, <https://websafe.pl>
## 
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
## 
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
## 
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.
## 
## ----------------------------------------------------------------------------


##
set -e;


##
## Configuration
##
CMD_CAT=${CMD_CAT:-/usr/bin/cat};
CMD_CURL=${CMD_CURL:-/usr/bin/curl};
CMD_CUT=${CMD_CUT:-/usr/bin/cut};
CMD_DATE=${CMD_DATE:-/usr/bin/date};
CMD_HEAD=${CMD_HEAD:-/bin/head};
CMD_LYNX=${CMD_LYNX:-/usr/bin/lynx};
CMD_MKDIR=${CMD_MKDIR:-/usr/bin/mkdir};
CMD_MV=${CMD_MV:-/usr/bin/mv};
CMD_RM=${CMD_RM:-/usr/bin/rm};
CMD_TRACEROUTE=${CMD_TRACEROUTE:-/usr/bin/traceroute};
TIMEOUT_CONNECT=${TIMEOUT_CONNECT:-5};
DATA_DIR="/var/lib/slacheck/http";


## ----------------------------------------------------------------------------


##
## Input params
##
if [ -z "${1}" ];
then
  echo "Usage: ${0} <URI>";
  exit 1;
else
  URI="${1}";
fi;


##
##
##
URI_DOMAIN=$(echo ${URI} | ${CMD_CUT} -d'/' -f3);


##
## Make sure DATA_DIR structure exists for current domain
##
if [ ! -d "${DATA_DIR}/${URI_DOMAIN}/archive" ];
then
  if ! ${CMD_MKDIR} -p "${DATA_DIR}/${URI_DOMAIN}/archive";
  then
    echo "Cant't create directory: ${DATA_DIR}/${URI_DOMAIN}/archive"
    exit 2;
  fi;
fi;


##
TIMESTAMP=$(${CMD_DATE} "+%s");


## ----------------------------------------------------------------------------


##
## Removes files created during curl request. Should be used mostly after
## a successful request, because in that case we don't want to keep detailed
## request logs.
slacheck_cleanup_current_tempfiles() {
  ## Remove the stored timestamped response body file:
  if [ -e "${DATA_DIR}/${URI_DOMAIN}/archive/${TIMESTAMP}.response.body" ];
  then
    ${CMD_RM} -f \
      "${DATA_DIR}/${URI_DOMAIN}/archive/${TIMESTAMP}.response.body";
  fi;

  ## Remove the stored timestamped curl output file:
  if [ -e "${DATA_DIR}/${URI_DOMAIN}/archive/${TIMESTAMP}.curl.output" ];
  then
    ${CMD_RM} -f \
      "${DATA_DIR}/${URI_DOMAIN}/archive/${TIMESTAMP}.curl.output";
  fi;

  ## Remove the stored timestamped curl error file:
  if [ -e "${DATA_DIR}/${URI_DOMAIN}/archive/${TIMESTAMP}.curl.error" ];
  then
    ${CMD_RM} -f \
      "${DATA_DIR}/${URI_DOMAIN}/archive/${TIMESTAMP}.curl.error";
  fi;
}


##
## Initialize global variables used in script body.
## Must be called AFTER curl request.
##
slacheck_initialize_current_variables() {
  ##
  current_http_response_code=$(
    ${CMD_HEAD} -n 1 \
      "${DATA_DIR}/${URI_DOMAIN}/archive/${TIMESTAMP}.curl.output" \
      | ${CMD_CUT} -d':' -f1
  );

  ##
  current_curl_timing=$(
    ${CMD_HEAD} -n 1 \
      "${DATA_DIR}/${URI_DOMAIN}/archive/${TIMESTAMP}.curl.output" \
      | ${CMD_CUT} -d':' -f2-
  );

  ##
  previous_http_response_code=$(
    if [ -e "${DATA_DIR}/${URI_DOMAIN}/previous.http-response-code" ];
    then
      ${CMD_CAT} "${DATA_DIR}/${URI_DOMAIN}/previous.http-response-code";
    fi;
  );
}


##
##
##
slacheck_run_tasks_on_curl_error() {
  ## Log traceroute
  ${CMD_TRACEROUTE} \
    "${URI_DOMAIN}" \
    1> "${DATA_DIR}/${URI_DOMAIN}/archive/${TIMESTAMP}.traceroute.output" \
    2> "${DATA_DIR}/${URI_DOMAIN}/archive/${TIMESTAMP}.traceroute.error";
}


##
##
##
slacheck_log_status() {
  local status="${1}";
  echo "${TIMESTAMP}:${status}:${current_http_response_code}:${current_curl_timing}" \
    >> "${DATA_DIR}/${URI_DOMAIN}/log";
}


## ----------------------------------------------------------------------------


##
##
##
if ${CMD_CURL} \
  --connect-timeout "${TIMEOUT_CONNECT}" \
  --write-out %{http_code}:%{time_connect}:%{time_starttransfer}:%{time_total} \
  --output "${DATA_DIR}/${URI_DOMAIN}/archive/${TIMESTAMP}.response.body" \
  --silent \
  "${URI}" \
  1> "${DATA_DIR}/${URI_DOMAIN}/archive/${TIMESTAMP}.curl.output" \
  2> "${DATA_DIR}/${URI_DOMAIN}/archive/${TIMESTAMP}.curl.error";
then

  ## --------------------------------------------------------------------------
  ##
  ## On CURL success
  ##
  ## --------------------------------------------------------------------------

  ##
  slacheck_initialize_current_variables;

  ## Log status (OK)
  slacheck_log_status "OK";

  ## If response code has changed do not cleanup temp files:
  if [ "${current_http_response_code}" != "${previous_http_response_code}" ];
  then

    ## store the current response code in `previous.http-response-code`
    echo "${current_http_response_code}" \
      > "${DATA_DIR}/${URI_DOMAIN}/previous.http-response-code";

  else

    ## Response code not changed, so we can cleanup temp files:
    slacheck_cleanup_current_tempfiles;

  fi;

else

  ## --------------------------------------------------------------------------
  ##
  ## On CURL error
  ##
  ## --------------------------------------------------------------------------

  ##
  slacheck_initialize_current_variables;

  ## Log status (ERROR)
  slacheck_log_status "ERROR";

  ## If response code has changed
  if [ "${current_http_response_code}" != "${previous_http_response_code}" ];
  then

    ## store the current response code in `previous.http-response-code`
    echo "${current_http_response_code}" \
      > "${DATA_DIR}/${URI_DOMAIN}/previous.http-response-code";

    ## Execute additional tasks on curl error for debugging
    slacheck_run_tasks_on_curl_error;

  else

    ## Response code not changed, so we can cleanup temp files:
    slacheck_cleanup_current_tempfiles;

  fi;

fi;


## ----------------------------------------------------------------------------


##
exit 0;

#!/bin/bash
#
# Depend packages: curl, unzip
# 
# Require Environments:
#
#   REDMINE_PLUGIN_DIR: redmine plugin root directory
#   REDMINECRM_USER: user email for www.redminecrm.com
#   REDMINECRM_PASS: user password for www.redminecrm.com
#   PLUGIN_NAME: plugin name, this will be used as folder name in redmine plugin directory
#   PLUGIN_URL: plugin url get from download page
#               e.g. "http://www.redminecrm.com/license_manager/zzzz/xxx.zip"

set -e
set -x
temp_dir=$(mktemp -d)
cookie_file=${temp_dir}/cookies

cd ${temp_dir}
authenticity_token=$(curl -c "${cookie_file}" "http://www.redminecrm.com/login" |grep -o '<input\s*name=\"authenticity_token\"[^<>]*'|grep -oP --color=never 'value=\"\K[^\"]*(?=\")')

login_success=$(curl -b "${cookie_file}" -c "${cookie_file}" -F "authenticity_token=${authenticity_token}" -F  "username=${REDMINECRM_USER}" -F "password=${REDMINECRM_PASS}" -F "login=Login »" -F "back_url=http://www.redminecrm.com" "http://www.redminecrm.com/login" | grep "redirected")

[[ -z "${login_success}" ]] && echo "login failed" && rm -fr ${temp_dir} && return 1

# download with session cookies
curl -b "${cookie_file}" -o "${PLUGIN_NAME}.zip" "${PLUGIN_URL}"

if ! [[ -f "${PLUGIN_NAME}.zip" ]]; then
  rm -fr ${temp_dir}
  echo "Plugin [${PLUGIN_NAME}] not downloaded from ${PLUGIN_URL}"
  return 2
fi

# extract and strip if only one directory
mkdir ${PLUGIN_NAME}_extracted
cd ${PLUGIN_NAME}_extracted
unzip ../"${PLUGIN_NAME}.zip"

plugin_dest_dir=${REDMINE_PLUGIN_DIR}/${PLUGIN_NAME}
mkdir -p ${plugin_dest_dir}

files=(./*)
if (( ${#files[@]} == 1 )) && [[ -d "${files[0]}" ]] ; then
  mv ./*/* ${plugin_dest_dir}/
else
  mv ./* ${plugin_dest_dir}/
fi

rm -fr ${temp_dir}

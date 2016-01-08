#!/bin/bash
#
# Depend packages: curl, unzip
# 
# Require Environments:
#
#   TARGET_DIR: output directory
#   REDMINECRM_USER: user email for www.redminecrm.com
#   REDMINECRM_PASS: user password for www.redminecrm.com
#   DOWNLOAD_URL: url get from download page e.g. "http://www.redminecrm.com/license_manager/123/xx.zip"

set -e
set -x
temp_dir=$(mktemp -d)
cookie_file=${temp_dir}/cookies

cd ${temp_dir}
authenticity_token=$(curl -c "${cookie_file}" "http://www.redminecrm.com/login" |grep -o '<input\s*name=\"authenticity_token\"[^<>]*'|grep -oP --color=never 'value=\"\K[^\"]*(?=\")')

login_success=$(curl -b "${cookie_file}" -c "${cookie_file}" -F "authenticity_token=${authenticity_token}" -F  "username=${REDMINECRM_USER}" -F "password=${REDMINECRM_PASS}" -F "login=Login »" -F "back_url=http://www.redminecrm.com" "http://www.redminecrm.com/login" | grep "redirected")

[[ -z "${login_success}" ]] && echo "login failed" && rm -fr ${temp_dir} && return 1

# download with session cookies
curl -b "${cookie_file}" -o "download.zip" "${DOWNLOAD_URL}"

if ! [[ -f "download.zip" ]]; then
  rm -fr ${temp_dir}
  echo "Cannot download from ${DOWNLOAD_URL}"
  return 2
fi

# extract and strip if only one directory
mkdir extracted
cd extracted
unzip ../download.zip

[[ -d "${TARGET_DIR}" ]] || mkdir -p ${TARGET_DIR}

files=(./*)
if (( ${#files[@]} == 1 )) && [[ -d "${files[0]}" ]] ; then
  mv ./*/* ${TARGET_DIR}/
else
  mv ./* ${TARGET_DIR}/
fi

rm -fr ${temp_dir}

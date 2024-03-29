#!/bin/bash -e
# shellcheck disable=SC2155,SC1001
##############################################################################
# Copyright (c) 2017 Mirantis Inc., Enea AB and others.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
#
# Library of shell functions
#

function generate_ssh_key {
  local user=${USER}
  if [ -n "${SUDO_USER}" ] && [ "${SUDO_USER}" != 'root' ]; then
    user=${SUDO_USER}
  fi

  if [ -f "${SSH_KEY}" ]; then
    ssh-keygen -f ${SSH_KEY} -y > ${SSH_KEY}.pub
  fi

  [ -f "${SSH_KEY}" ] || ssh-keygen -f ${SSH_KEY} -N ''
  
  [ -f "${USER_SSH_KEY}" ] || {
    install -D -o "${user}" -m 0600 "${SSH_KEY}" "${USER_SSH_KEY}"
    install -D -o "${user}" -m 0600 "${SSH_KEY}.pub" "${USER_SSH_KEY}.pub"
  }
}

function parse_idf {
  idf="${CONF_DIR}/idf-${TARGET_POD}.yaml"
  [[ -f ${idf} ]] && eval $(parse_yaml ${idf}) || {
    echo "${idf} must exist"
    exit 5
  }
}

function parse_pdf {
  pdf="${CONF_DIR}/pdf-${TARGET_POD}.yaml"
  [[ -f ${pdf} ]] && {
    eval $(python ${DEPLOY_DIR}/parse_pdf.py -y ${pdf} 2>&1)
    IFS=':' read -a vnodes <<< "${nodes}"
  } || {
    echo "${pdf} must exist"
    exit 5
  }
}

function parse_yaml {
  local prefix=$2
  local s
  local w
  local fs
  s='[[:space:]]*'
  w='[a-zA-Z0-9_]*'
  fs="$(echo @|tr @ '\034')"
  sed -e 's|---||g' -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
      -e "s|^\($s\)\($w\)$s[:-]$s\(.*\)$s\$|\1$fs\2$fs\3|p" "$1" |
  awk -F"$fs" '{
  indent = length($1)/2;
  vname[indent] = $2;
  for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
          vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
          printf("%s%s%s=(\"%s\")\n", "'"$prefix"'",vn, $2, $3);
      }
  }' | sed 's/_=/+=/g'
}

function get_admin_ip {
  local vnode=${1}
  local node_id=$(eval echo "\$nodes_${vnode}_node_id")
  echo $(eval echo "${idf_cactus_jumphost_fixed_ips_admin%.*}.${node_id}")
}

function get_mgmt_ip {
  local vnode=${1}
  local node_id=$(eval echo "\$nodes_${vnode}_node_id")
  echo $(eval echo "${idf_cactus_jumphost_fixed_ips_mgmt%.*}.${node_id}")
}

function ssh_exc {
  local ip=${1}; shift
  local cmdstr="$@"; shift
  ssh ${SSH_OPTS} cactus@${ip} bash -s -e << SSH_EXE_END
    $cmdstr
SSH_EXE_END
}

function sudouser_exc {
  cmdstr=${1}
  no_error=${2:-true}

  [[ ${no_error} == true ]] && {
    /bin/su -s /bin/bash -c "${cmdstr}" ${SUDO_USER} || true
  } || {
    /bin/su -s /bin/bash -c "${cmdstr}" ${SUDO_USER}
  }
}

#!/usr/bin/env bash

##############################################################################
# BEGIN of usage description
#
usage ()
{
cat << EOF
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
$(notify_i "USAGE:" 2)
  $(basename "$0") -P prefix -c cleanup_level

$(notify_i "OPTIONS:" 2)
  -p  Pod-name
  -P  VM prefix, \${prefix}_<nodename>
  -l  cleanup level dib or sto
  -h  help information

$(notify_i "Input parameters to the build script are:" 2)
-p POD name as defined in the configuration directory, e.g. pod2
-P Prefix of vm name, e.g. if prefix=cactus, vm name will be cactus_<node name>
-l cleanup level dib=all resources(vm, network, dib image,,,etc),
   sto=all resources except dib image, used by default.
-h Print this help information

$(notify_i "[NOTE] sudo & virsh priviledges are needed for this script to run" 3)

Example:
$(notify_i "sudo $(basename "$0") -P prefix -s calico-noha -c sto" 2)
EOF
}

do_exit () {
  notify_n "[OK] VMs: VMs installation finished succesfully!\n\n" 2
}

export TERM=xterm

# BEGIN of variables to customize
#
CI_DEBUG=${CI_DEBUG:-0}; [[ "${CI_DEBUG}" =~ (false|0) ]] || set -x
REPO_ROOT_PATH=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")
DEPLOY_DIR=$(cd "${REPO_ROOT_PATH}/deploy"; pwd)
CONF_DIR="${REPO_ROOT_PATH}/config"
STORAGE_DIR=/var/vms
PREFIX=vms
LEVEL=sto

##############################################################################
# BEGIN of main
#
while getopts "p:s:P:l:h" OPTION
do
  case $OPTION in
    p) TARGET_POD=${OPTARG} ;;
    P) PREFIX=${OPTARG}; TMP_DIR=/tmp/vms_${PREFIX} ;;
    l) LEVEL=${OPTARG} ;;
    h) usage; exit 0 ;;
    *) notify_e "[ERROR] Arguments not according to new argument style\n" ;;
  esac
done

if [[ "$(sudo whoami)" != 'root' ]]; then
  notify_e "[ERROR] This script requires sudo rights!"
  exit 1
fi


source "${DEPLOY_DIR}/globals.sh"
source "${DEPLOY_DIR}/lib.sh"
source "${DEPLOY_DIR}/vms.sh"

# Enable the automatic exit trap
trap do_exit SIGINT SIGTERM EXIT

pushd "${DEPLOY_DIR}" > /dev/null

if ! virsh list >/dev/null 2>&1; then
  notify_e "[ERROR] This script requires hypervisor access!"
fi

# Infra setup
parse_idf

update_bridges

parse_pdf

cleanup_vms

cleanup_networks

cleanup_sto

[[ ${LEVEL} == img ]] && cleanup_img
[[ ${LEVEL} == dib ]] && cleanup_dib


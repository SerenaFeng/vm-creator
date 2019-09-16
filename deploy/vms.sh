#!/usr/bin/env bash

BRIDGE_IDENTITY="idf_cactus_jumphost_bridges_"

function imagedir {
  echo ${STORAGE_DIR}/images
}

function diskdir {
  echo ${STORAGE_DIR}/${PREFIX}
}

function __get_bridges {
  set +x
  compgen -v ${BRIDGE_IDENTITY} |
  while read var; do {
    echo ${var#${BRIDGE_IDENTITY}}
  }
  done || true
  [[ "${CI_DEBUG}" =~ (false|0) ]] || set -x
}

function update_bridges {
  read -r -a BR_NAMES <<< $(__get_bridges)
  for br in "${BR_NAMES[@]}"; do
    old=$(eval echo "\$${BRIDGE_IDENTITY}${br}")
    eval "${BRIDGE_IDENTITY}${br}=${PREFIX}_${old}"
  done
}

function prepare_networks {
  [[ ! "${BR_NAMES[@]}" =~ "admin" ]] && {
    notify_n "[ERR] Bridge admin must be defined\n" 2
    exit 1
  }

  for br in "${BR_NAMES[@]}"; do
    bridge_name=${PREFIX}_$br
    bridge_ip=$(eval echo "\$idf_cactus_jumphost_fixed_ips_${br}")
    eval "cat <<-EOF
      $(<"${TEMPLATE_DIR}/net.xml.template")
EOF" 2> /dev/null > "${TMP_DIR}/${br}.net.xml"
  done
}

function cleanup_vms {
  # clean up existing nodes
  for node in $(virsh list --name | grep -P "${PREFIX}_"); do
    virsh destroy "${node}"
  done
  for node in $(virsh list --name --all | grep -P "${PREFIX}_"); do
    virsh domblklist "${node}" | awk '/^.da/ {print $2}' | \
      xargs --no-run-if-empty -I{} sudo rm -f {}
    # TODO command 'undefine' doesn't support option --nvram
    virsh undefine "${node}" --remove-all-storage
    ip=$(get_admin_ip ${node##${PREFIX}_})
    sudouser_exc "ssh-keygen -R ${ip}"
    ssh-keygen -R ${ip} || true
  done
}

function prepare_vms {
  mkdir $(diskdir) || true

  # Create vnode images and resize OS disk image for each foundation node VM
  for vnode in "${vnodes[@]}"; do
    if [ $(eval echo "\$nodes_${vnode}_enabled") == "True" ]; then
      echo "preparing for vnode: [${vnode}]"
      image="ubuntu16.04.qcow2"
      cp "$(imagedir)/${image}" "$(diskdir)/${vnode}.qcow2"
      disk_capacity="nodes_${vnode}_node_disk"
      qemu-img resize "$(diskdir)/${vnode}.qcow2" ${!disk_capacity}
    fi
  done
}

function cleanup_networks {
  for br in "${BR_NAMES[@]}"; do
    net=$(eval echo "\$${BRIDGE_IDENTITY}${br}")
    if virsh net-info "${net}" >/dev/null 2>&1; then
      virsh net-destroy "${net}" || true
      virsh net-undefine "${net}"
    fi
  done
}

function create_networks {

  # create required networks
  for br in "${BR_NAMES[@]}"; do
    net=$(eval echo "\$${BRIDGE_IDENTITY}${br}")
    # in case of custom network, host should already have the bridge in place
    if [ -f "${TMP_DIR}/${br}.net.xml" ] && [ ! -d "/sys/class/net/${net}/bridge" ]; then
      virsh net-define "${TMP_DIR}/${br}.net.xml"
      virsh net-autostart "${net}"
      virsh net-start "${net}"
    fi
  done
}

function create_vms {
  cpu_pass_through=$1; shift

  # AArch64: prepare arch specific arguments
  local virt_extra_args=""
  if [ "$(uname -i)" = "aarch64" ]; then
    # No Cirrus VGA on AArch64, use virtio instead
    virt_extra_args="$virt_extra_args --video=virtio"
  fi

  # create vms with specified options
  for vnode in "${vnodes[@]}"; do
    # prepare network args
    net_args=""
    for br in "${BR_NAMES[@]}"; do
      net=$(eval echo "\$${BRIDGE_IDENTITY}${br}")
      net_args="${net_args} --network bridge=${net},model=virtio"
    done

    [ ${cpu_pass_through} -eq 1 ] && \
    cpu_para="--cpu host-passthrough" || \
    cpu_para=""

    [[ $(eval echo "\$nodes_${vnode}_node_features") =~ hugepage ]] && hugepage="--memorybacking hugepages=yes" || hugepage=""

    # shellcheck disable=SC2086
    virt-install --name "${PREFIX}_${vnode}" \
    --memory $(eval echo "\$nodes_${vnode}_node_memory") ${hugepage} \
    --vcpus $(eval echo "\$nodes_${vnode}_node_cpus") \
    ${cpu_para} --accelerate ${net_args} \
    --disk path="${STORAGE_DIR}/${PREFIX}/${vnode}.qcow2",format=qcow2,bus=virtio,cache=none,io=native \
    --os-type linux --os-variant none \
    --boot hd --vnc --console pty --autostart --noreboot \
    --noautoconsole \
    ${virt_extra_args}
  done
}

function update_network {
  net=${1}
  for vnode in "${vnodes[@]}"; do
    local br=$(eval echo "\$idf_cactus_jumphost_bridges_${net}")
    local guest="${PREFIX}_${vnode}"
    local ip=$(eval "get_${net}_ip ${vnode}")
    local mac=$(virsh domiflist ${guest} 2>&1 | grep ${br} | awk '{print $5; exit}')
    virsh net-update "${br}" add ip-dhcp-host \
      "<host mac='${mac}' name='${guest}' ip='${ip}'/>" --live --config
  done
}

function start_vms {
  # start vms
  for node in "${vnodes[@]}"; do
    virsh start "${PREFIX}_${node}"
    sleep $((RANDOM%5+1))
  done
}

function check_connection {
  local total_attempts=60
  local sleep_time=5

  set +e
  echo '[INFO] Attempting to get into master ...'

  # wait until ssh on master is available
  # shellcheck disable=SC2034
  for vnode in "${vnodes[@]}"; do
    for attempt in $(seq "${total_attempts}"); do
      ssh_exc $(get_admin_ip ${vnode}) uptime
      case $? in
        0) echo "${attempt}> Success"; break ;;
        *) echo "${attempt}/${total_attempts}> master ain't ready yet, waiting for ${sleep_time} seconds ..." ;;
      esac
      sleep $sleep_time
    done
  done
  set -e
}

function cleanup_dib {
  rm -fr $(imagedir) || true
}

function cleanup_sto {
  rm -fr $(diskdir) || true
}

function cleanup_img {
  rm -fr $(imagedir) || true
  rm -fr $(diskdir) || true
}

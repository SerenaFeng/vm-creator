set -x


function get_mgmt_ip {
  echo "192.168.7.2"
}

function render_istio {
  echo "IstioConfig"
}

cluster_pod_cidr="10.0.0.1"
vnode=master01

nodes_master01_hostname=m1
cluster_version=v1.12.2
cluster_name=cactus.k8s

tp="templates/kubeadm-v1.12.template"
eval "cat <<-EOF
  $(<"${tp}")
EOF" 2> /dev/null > "templates/$(basename ${tp%.template})"

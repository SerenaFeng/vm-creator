
#!/bin/sh

WORKDIR=/home
PUBKEY=/home/id_rsa.pub
images="$@"


function create_centos7_image {
    echo "Begin to build centos7 image"
    image_name=${1:-centos7.qcow2}
    image_format=${2:-qcow2}

    ELEMENTS_PATH=/elements \
    DIB_DEV_USER_USERNAME=cactus \
    DIB_DEV_USER_PASSWORD=cactus \
    DIB_DEV_USER_PWDLESS_SUDO=true \
    DIB_DEV_USER_AUTHORIZED_KEYS=$PUBKEY \
    disk-image-create centos7 vm dhcp-all-interfaces \
    cloud-init-nocloud devuser install-static common-static master-static \
    -p docker,vim \
    -o ${image_name} -t ${image_format}
}

function create_ubuntu1604_image {
    echo "Begin to build ubuntu16.04 image"
    image_name=${1:-ubuntu16.04.qcow2}
    image_format=${2:-qcow2}

    DIB_RELEASE=xenial \
    ELEMENTS_PATH=/elements \
    DIB_DEV_USER_USERNAME=cactus \
    DIB_DEV_USER_PASSWORD=cactus \
    DIB_DEV_USER_PWDLESS_SUDO=true \
    DIB_DEV_USER_AUTHORIZED_KEYS=$PUBKEY \
    disk-image-create ubuntu vm dhcp-all-interfaces enable-serial-console \
    cloud-init-nocloud devuser apt-sources dpkg install-static common-static \
    -p docker,vim \
    -o ${image_name} -t ${image_format} -x
}

#for image_item in $( set | awk '{FS="="}  /^VM_BASE_IMAGE/ {print $2}' ); do
for image_item in "${images}"; do
    echo "Image [${image_item}] will be created...."

    [[ -f ${image_item} ]] && {
       echo "Image [${image_item}] already exists, skip it."
       continue
    }

    image_name=${image_item##*/}
    image_format=${image_item##*.}
    [[ ${image_item} =~ "/" ]] && dir_name=${image_item%/*} || dir_name=""

    [[ ${image_item} =~ "centos7" ]] && {
        [[ -n ${dir_name} ]] && {
            mkdir -p ${dir_name}
            pushd ${dir_name}
            create_centos7_image ${image_name} ${image_format} || true
            popd
        } || {
            create_centos7_image ${image_name} ${image_format} || true
        }
        echo "Image [${image_item}] create successfully."
        continue
    }
    [[ ${image_item} =~ "ubuntu16.04" ]] && {

        [[ -n ${dir_name} ]] && {
            mkdir -p ${dir_name}
            pushd ${dir_name}
            create_ubuntu1604_image ${image_name} ${image_format} || true
            popd
        } || {
            create_ubuntu1604_image ${image_name} ${image_format} || true
        }
        echo "Image [${image_item}] create successfully."
        continue
    }
done

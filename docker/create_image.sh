#! /bin/bash -e

WORKDIR=/home
PUBKEY=/home/id_rsa.pub
image=$1

dib_opts_c7=(dhcp-all-interfaces cloud-init-nocloud devuser install-static common-static master-static)
pkg_opts_c7=(docker,vim,git)
dib_opts_u16=(dhcp-all-interfaces enable-serial-console cloud-init-nocloud devuser apt-sources dpkg install-static common-static)
pkg_opts_u16=(docker,vim,git)

function create_centos7_image {
    image_name=${1:-centos7.qcow2}
    image_format=${2:-qcow2}

    while IFS= read -r -d '' item; do
        dib_opts_c7+=( "$item" )
    done < <([[ $DIB_OPTS ]] && xargs printf '%s\0' <<<"$DIB_OPTS")

    while IFS= read -r -d '' item; do
        pkg_opts_c7+=( "$item" )
    done < <([[ $PKG_OPTS ]] && xargs printf '%s\0' <<<"$PKG_OPTS")

    echo "Begin to build ${image_name} image"
    echo "With dib opts: ${dib_opts_c7[@]}"
    echo "With pkg opts: ${pkg_opts_c7[@]}"

    ELEMENTS_PATH=/elements \
    DIB_DEV_USER_USERNAME=cactus \
    DIB_DEV_USER_PASSWORD=cactus \
    DIB_DEV_USER_PWDLESS_SUDO=true \
    DIB_DEV_USER_AUTHORIZED_KEYS=$PUBKEY \
    disk-image-create centos7 vm "${dib_opts_c7[@]}" \
    -p "${pkg_opts_c7[@]}" \
    -o ${image_name} -t ${image_format}
}

function create_ubuntu1604_image {
    image_name=${1:-ubuntu16.04.qcow2}
    image_format=${2:-qcow2}

    while IFS= read -r -d '' item; do
        dib_opts_u16+=( "$item" )
    done < <([[ $DIB_OPTS ]] && xargs printf '%s\0' <<<"$DIB_OPTS")

    while IFS= read -r -d '' item; do
        pkg_opts_u16+=( "$item" )
    done < <([[ $PKG_OPTS ]] && xargs printf '%s\0' <<<"$PKG_OPTS")

    echo "Begin to build ${image_name} image"
    echo "With dib opts: ${dib_opts_u16[@]}"
    echo "With pkg opts: ${pkg_opts_u16[@]}"

    DIB_RELEASE=xenial \
    ELEMENTS_PATH=/elements \
    DIB_DEV_USER_USERNAME=cactus \
    DIB_DEV_USER_PASSWORD=cactus \
    DIB_DEV_USER_PWDLESS_SUDO=true \
    DIB_DEV_USER_AUTHORIZED_KEYS=$PUBKEY \
    disk-image-create ubuntu vm "${dib_opts_u16[@]}" \
    -p "${pkg_opts_u16[@]}" \
    -o ${image_name} -t ${image_format} -x
}

[[ -f ${image} ]] && {
   echo "Image [${image}] already exists, skip it."
   continue
}

echo "Image [${image}] will be created...."

image_name=${image##*/}
image_format=${image##*.}
[[ ${image} =~ "/" ]] && dir_name=${image%/*} || dir_name=""

[[ ${image} =~ "centos7" ]] && {
    [[ -n ${dir_name} ]] && {
        mkdir -p ${dir_name}
        pushd ${dir_name}
        create_centos7_image ${image_name} ${image_format}
        popd
    } || {
        create_centos7_image ${image_name} ${image_format}
    }
    echo "Image [${image}] create successfully."
}
[[ ${image} =~ "ubuntu16.04" ]] && {
    [[ -n ${dir_name} ]] && {
        mkdir -p ${dir_name}
        pushd ${dir_name}
        create_ubuntu1604_image ${image_name} ${image_format}
        popd
    } || {
        create_ubuntu1604_image ${image_name} ${image_format}
    }
    echo "Image [${image}] create successfully."
}

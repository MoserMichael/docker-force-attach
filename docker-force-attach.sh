#!/usr/bin/env bash

#set -x

function Help() {
cat <<EOF
$0 DOCKER_ID

Attach a shell on a given docker container
If no shell is installed on the docker container, then download and copy an appropriate shell and run it.
EOF
exit 1
}

CONTAINER_ID=$1
if [[ "$CONTAINER_ID" == "" ]]; then
    Help
fi

DIR="$HOME/.force-attach-shell"

try_regular_attach() {
    if docker exec -it "${CONTAINER_ID}" '/bin/bash'; then
        exit 0
    fi

    if docker exec -it "${CONTAINER_ID}" '/bin/sh'; then
        exit 0
    fi

    if docker exec -it "${CONTAINER_ID}" '/bin/ksh'; then
        exit 0
    fi

    if docker exec -it "${CONTAINER_ID}" 'bash'; then
        exit 0
    fi

    if docker exec -it "${CONTAINER_ID}" 'sh'; then
        exit 0
    fi

    if docker exec -it "${CONTAINER_ID}" 'ksh'; then
        exit 0
    fi
}

# True iff all arguments are executable in $PATH , from: https://stackoverflow.com/questions/6569478/detect-if-executable-file-is-on-users-path
function assert_bins_in_path {
  if [[ -n $ZSH_VERSION ]]; then
    builtin whence -p "$1" &> /dev/null
  else  # bash:
    builtin type -P "$1" &> /dev/null
  fi
  if [[ $? != 0 ]]; then
    echo "Error: $1 is not in the current path"
    exit 1
  fi    
  if [[ $# -gt 1 ]]; then
    shift  # We've just checked the first one
    assert_bins_in_path "$@"
  fi
}

download_stuff() {
    DIR=${1}
    USER=${2}
    REPO=${3}

    echo "Downloading shells..."

    assert_bins_in_path "jq" "curl"

    LATEST_TAG=$(curl -L -s -S  -H "Accept: application/json" "https://github.com/${USER}/${REPO}/releases/latest" | jq --raw-output .tag_name)

    for artifact in $(curl -L -s -S -H "Accept: application/vnd.github+json" "https://api.github.com/repos/${USER}/${REPO}/actions/artifacts" | jq --raw-output '.artifacts[] | select(.expired==false) | .name'); do
        echo "downloading artifact: ${artifact} to: ${DIR}/${artifact}"
        ARTIFACT_URL="https://github.com/${USER}/${REPO}/releases/download/${LATEST_TAG}/${artifact}"
        curl -L -s -S "${ARTIFACT_URL}" -o "${DIR}/${artifact}"
    done
}


make_tars() {

    echo "Prepare shells..."

    TAR=tar
    if [[ $(uname) == "Darwin" ]]; then
        TAR=gtar
    fi

    pushd "${DIR}"
    mkdir bin

    for file in $(ls bash-*); do
        
        rm -f bin/bash || true

        cp $file bin/bash
        chmod +x bin/bash

        #pushd bin
        #ln -sf bash ./sh
        #popd
        #pwd
        
        ${TAR} -c -v --owner=0 --group=0 -f ${file}.tar -C bin bash

        rm "${file}"
    done

    rm -rf bin
    echo "1" >"${DIR}/download_completed"
}

find_image_version() {
    IMAGE_ID=$(docker inspect "${CONTAINER_ID}" --format='{{json .Image}}')
    IMAGE_ID="${IMAGE_ID:1:${#IMAGE_ID}-2}"

    IMAGE_INFO=$(docker inspect "${IMAGE_ID}"  --format='{{json .Architecture}} {{json .Os}} {{json .Variant}}')

    read -r ARCH OS VARIANT <<< $(ECHO "${IMAGE_INFO}") 

    ARCH="${ARCH:1:${#ARCH}-2}"
    OS="${OS:1:${#OS}-2}"
    VARIANT="${VARIANT:1:${#VARIANT}-2}"

 
    if [[ "$ARCH" == "amd64" ]]; then
        ARCH="x86_64"
    else 
        if [[ "$ARCH" == "arm64" ]]; then
            ARCH="aarch64" 
        fi 
    fi

    TAR_FILE="${DIR}/bash-${OS}-${ARCH}.tar";
}

run_it() {
    #docker cp -a -L ${TAR_FILE} "$CONTAINER_ID:/bin"
    cat  ${TAR_FILE} | docker cp -a -L - ${CONTAINER_ID}:/
    docker exec -it "${CONTAINER_ID}" '/bash'
}

attach_to_docker() {
    try_regular_attach

    if [[ ! -d "${DIR}" ]]; then
       echo "force attach, first time init. Downloading statically linked bash shells..."
       mkdir ${DIR}
       download_stuff "${DIR}" "robxu9" "bash-static"
       make_tars
    else
        if [[ ! -f "${DIR}/download_completed" ]]; then  
           download_stuff "${DIR}" "robxu9" "bash-static"
           make_tars
        fi
    fi
    find_image_version
    run_it
}

attach_to_docker



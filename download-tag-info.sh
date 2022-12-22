#!/usr/bin/env bash


function Help() {
cat <<EOF
$0  [-n <image-name>] -o <output_file>

-n <image_name>         - docker image name (mandatory)
-o <output file>        - json output file

Search DockerHub for the image-name and get the json that describes all tags
EOF
exit 1
}

IMAGE_NAME=""
OUT_FILE=""

while getopts "hvn:o:" opt; do
  case ${opt} in
    h)
        Help
        ;;
    v)
        set -x
        export PS4='+(${BASH_SOURCE}:${LINENO}) '
        ;;
    n)
        IMAGE_NAME="${OPTARG}"
        ;;
    o)
        OUT_FILE="${OPTARG}"
        ;;
    *)
        Help "Invalid option"
        ;;
   esac
done

if [[ "$IMAGE_NAME" == "" ]]; then
    echo "-n <image_name> argument not given"
    Help
fi

if [[ "$OUT_FILE" == "" ]]; then
    echo "-o <out_file> argument not given"
    Help
fi


if [[ $IMAGE_NAME =~ .*/.* ]]; then
    URL="https://registry.hub.docker.com/v2/repositories/${IMAGE_NAME}/tags";
else
    URL="https://registry.hub.docker.com/v2/repositories/library/${IMAGE_NAME}/tags";
fi

echo "" >${OUT_FILE}

while true; do
    JSON=$(curl -L -s "${URL}")
    if [[ $? != 0 ]]; then 
        break;
    fi

    echo "$JSON" | jq '.results[]' >>${OUT_FILE}

    URL=$(echo "${JSON}" | jq -r .next)
    if [[ $URL == "" ]]; then
        break        
    fi
done



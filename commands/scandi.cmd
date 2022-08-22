#!/usr/bin/env bash
[[ ! ${WARDEN_DIR} ]] && >&2 echo -e "\033[31mThis script is not intended to be run directly!\033[0m" && exit 1

WARDEN_ENV_PATH="$(locateEnvPath)" || exit $?
loadEnvConfig "${WARDEN_ENV_PATH}" || exit $?

## set defaults for this command which can be overridden either using exports in the user
## profile or setting them in the .env configuration on a per-project basis
WARDEN_ENV_SHELL_CONTAINER=${WARDEN_ENV_SHELL_CONTAINER:-php-fpm}

## allow return codes from sub-process to bubble up normally
trap '' ERR

## get name of first folder in directory
SCANDI_DIR="src/scandipwa/"
DOC_PATH="${WARDEN_ENV_PATH}/${SCANDI_DIR}"
SCANDI_DIR_NAME=$(ls -1 ${DOC_PATH} | head -n 1)

SCANDI_FULLPATH="${SCANDI_DIR}${SCANDI_DIR_NAME}"

function isNodeModulesInstalled {

    if [[ -d "${DOC_PATH}${SCANDI_DIR_NAME}/node_modules" ]]; then
        return 0
    else
        return 1
    fi
}

function removeNodeModules {
    echo -e "\033[31mRemoving node - ${SCANDI_FULLPATH}...\033[0m"
    "${WARDEN_DIR}/bin/warden" env exec "${WARDEN_ENV_SHELL_CONTAINER}" rm -rf "${SCANDI_FULLPATH}"/node_modules
}

function removeBuildIfExists {
    if [[ -d "${DOC_PATH}/${SCANDI_DIR_NAME}/build" ]]; then
        echo -e "\033[31mRemoving build - ${SCANDI_FULLPATH}/build...\033[0m"
        "${WARDEN_DIR}/bin/warden" env exec "${WARDEN_ENV_SHELL_CONTAINER}" rm -rf "${SCANDI_FULLPATH}"/build
    fi
}



## return if scandi_dir_name is empty
if [[ -z ${SCANDI_DIR_NAME} ]]; then
    echo -e "\033[31mScandi directory is empty!\033[0m"
    exit 1
fi

# Check if argument r exists 
if [[ "${WARDEN_PARAMS[0]}" == "r" ]]; then
    removeNodeModules
fi

# Check if argument i exists or if node modules required
if [[ "${WARDEN_PARAMS[0]}" == "i" || !isNodeModulesInstalled ]]; then
    echo -e "\033[31mInstalling ${SCANDI_FULLPATH}...\033[0m"
    "${WARDEN_DIR}/bin/warden" env exec "${WARDEN_ENV_SHELL_CONTAINER}" yarn --cwd "${SCANDI_FULLPATH}" install
fi

removeBuildIfExists


echo -e "\033[32mRunning Scandi in docker for ${SCANDI_FULLPATH}\033[0m"

"${WARDEN_DIR}/bin/warden" env exec "${WARDEN_ENV_SHELL_CONTAINER}" yarn --cwd "${SCANDI_FULLPATH}" dev
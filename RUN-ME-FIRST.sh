#!/usr/bin/env bash
#===============================================================================
#
#          FILE: run_me_first.sh
# 
#         USAGE: ./run_me_first.sh 
# 
#   DESCRIPTION: This script will be used by the customer's users and will be executed
#                from a shared drive.  
#                The steps that the script will do is:
#                   - check for and install bash version 4
#                   - check for and install aws cli
#                   - check for and install jq
#                   - ask where they want dcUtils
#                   - create the directory if it doesn't exist
#                   - cd to that directory 
#                   - clone dcUtils
#                   - then ...
#           
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Gregg Jensen (), gjensen@devops.center
#                Bob Lozano (), bob@devops.center
#  ORGANIZATION: devops.center
#       CREATED: 07/18/2017 15:17:42
#      REVISION:  ---
#
# Copyright 2014-2017 devops.center llc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#===============================================================================

#set -o nounset     # Treat unset variables as an error
#set -o errexit      # exit immediately if command exits with a non-zero status
#set -x             # essentially debug mode
unset CDPATH

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  getBasePath
#   DESCRIPTION:  gets the path where this file is executed from...somewhere alone the $PATH
#    PARAMETERS:  
#       RETURNS:  
#-------------------------------------------------------------------------------
getBasePath()
{
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
      DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
      SOURCE="$(readlink "$SOURCE")"
      [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    BASE_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  copyLoggingScript
#   DESCRIPTION:  copy dcUtils/script/dcEnv.sh to destination directory
#    PARAMETERS:  
#       RETURNS:  
#-------------------------------------------------------------------------------
copyLoggingScript()
{
    if [[ -w /usr/local/bin ]]; then
        cp ${dcUTILS}/scripts/dcEnv.sh /usr/local/bin/dcEnv.sh  > /dev/null 2>&1
    else
        echo 
        echo "We need to put a logging script in /usr/local/bin and it doesn't"
        echo "appear to be writable by you"
        read -i "y" -p "Do you want it use sudo to put it there [y or n]: " -e createdReply
        if [[ ${createdReply} == "y" ]]; then
            sudo cp ${dcUTILS}/scripts/dcEnv.sh /usr/local/bin/dcEnv.sh
        else
            echo
            echo "NOT COPIED. This script just standardizes output from the devops.center"
            echo "scripts. You can put it somewhere else in your path.  The file is: "
            echo "${dcUTILS}/scritps/dcEnv.sh"
            echo
        fi
    fi
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  createUserSpecificKeys
#   DESCRIPTION:  creates the private/public keys that will have the public key
#                 sent to devops.center to deploy to the appropriate customer instances
#    PARAMETERS:  
#       RETURNS:  
#-------------------------------------------------------------------------------
createUserSpecificKeys()
{
    if [[ ! -d ~/.ssh/devops.center ]]; then
        mkdir -p ~/.ssh/devops.center
    fi

    # and create a separate key for the dcAuthorization server
    ssh-keygen -t rsa -N "" -f ~/.ssh/devops.center/dcauthor-${USER_NAME}-key -q
    mv ~/.ssh/devops.center/dcauthor-${USER_NAME}-key ~/.ssh/devops.center/dcauthor-${USER_NAME}-key.pem
}



#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  writeToSettings
#   DESCRIPTION:  this function will write the necessary key/value pairs out to
#                 ~/dcConfig/settings and ~/.dcConfig/devops.center-rc
#    PARAMETERS:  
#       RETURNS:  
#-------------------------------------------------------------------------------
writeToSettings()
{
    echo "dcCloudService=NA" > ~/.dcConfig/settings
    echo "dcUTILS=${dcUTILS}" >> ~/.dcConfig/settings
    echo "CUSTOMER_NAME=${CUSTOMER_NAME}" >> ~/.dcConfig/settings
    echo "PROFILE=${PROFILE}" >> ~/.dcConfig/settings
    echo "USER_NAME=${USER_NAME}" >> ~/.dcConfig/settings
    echo "REGION=${REGION}" >> ~/.dcConfig/settings
    echo "DEV_BASE_DIR=${DEV_BASE_DIR}" >> ~/.dcConfig/settings
    echo "dcCOMMON_SHARED_DIR=\"${dcCOMMON_SHARED_DIR}\"" >> ~/.dcConfig/settings
    echo  >> ~/.dcConfig/settings
    echo "export dcUTILS=${dcUTILS}" >> ~/.dcConfig/settings

    cat << 'EOF' >> ~/.dcConfig/settings
if [[ -z ${PYTHONPATH} ]]; then
    export PYTHONPATH=${dcUTILS}/scripts
elif [[ "${PYTHONPATH}" != *"${dcUTILS}"* ]]; then
    export PYTHONPATH=${PYTHONPATH}:${dcUTILS}/scripts
else
    export PYTHONPATH=${dcUTILS}/scripts
fi

if [[ -z ${PATH} ]]; then
    export PATH=${dcUTILS}/scripts
elif [[ "${PATH}" != *"${dcUTILS}"* ]]; then
    export PATH=${dcUTILS}:${PATH}
fi
EOF

    echo "unset dcCloudService" >> ~/.dcConfig/settings
    echo "unset CUSTOMER_NAME" >> ~/.dcConfig/settings
    echo "unset PROFILE" >> ~/.dcConfig/settings
    echo "unset USER_NAME" >> ~/.dcConfig/settings
    echo "unset REGION" >> ~/.dcConfig/settings
    echo "unset DEV_BASE_DIR" >> ~/.dcConfig/settings

    # and now write out the git service and account name to the
    # shared setting file
    if [[ ! -d ${dcCOMMON_SHARED_DIR} ]]; then
        echo 
        echo "NOTE: the common shared directory: ${dcCOMMON_SHARED_DIR}"
        echo "doesn't exist, so the shared settings can not be created."
        echo "Please contact a devops.center engineer to correct, they"
        echo "may have to create it by hand."
        echo 
        return
    fi

    # ok at least the shared directory is there so lets see if the directory
    # we need to write the shared settings exists and if not create it
    SHARED_CONFIG_DIR=${dcCOMMON_SHARED_DIR}/devops.center/dcConfig
    if [[ ! -d ${SHARED_CONFIG_DIR} ]]; then
        mkdir -p ${SHARED_CONFIG_DIR}

        if [[ ! -d ${SHARED_CONFIG_DIR} ]]; then
            echo 
            echo "NOTE: tried to create the directory that will house the shared "
            echo "settings on the shared drive and could not.  Trying to create directory "
            echo "${SHARED_CONFIG_DIR}/dcConfig"
            echo "Please contact a devops.center engineer to correct, they"
            echo "may need to assist with this."
            echo 
            return
        fi
    fi

    # if we get here the shared drive is connected and the shared directory is there
    # now for the settings file
    if [[ ! -f  ${SHARED_CONFIG_DIR}/settings ]]; then
        echo "GIT_SERVICE_NAME=${GIT_SERVICE_NAME}" >> ${SHARED_CONFIG_DIR}/settings
        echo "GIT_ACCOUNT_NAME=${GIT_ACCOUNT_NAME}" >> ${SHARED_CONFIG_DIR}/settings
    fi
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  clonedcUtils
#   DESCRIPTION:  clone dcUtils where the user wants it
#    PARAMETERS:  
#       RETURNS:  
#-------------------------------------------------------------------------------
clonedcUtils()
{
    echo 
    echo "We need to grab a clone of the devops.center utilitities: dcUtils"
    echo "And for that, we need a directory location on your machine.  It can go"
    echo "anywhere.  Once this is cloned the path to the dcUtils directory will"
    echo "need to go into your PATH variable and then exported. This way the scripts"
    echo "can be run from anywhere on your machine."
    echo "Note: if you already have cloned dcUtils, provide the path to dcUtils and it"
    echo "      will updated rather than cloned."
    echo 
    # check to see if we have a default value
    if [[ "${dcUTILS_BASE_DIR}" ]]; then
        read -i "${dcUTILS_BASE_DIR}" -p "Enter your directory location and press [ENTER]: "  -e aBaseDir
    else
        read -i "~/devops/devopscenter" -p "Enter your directory location and press [ENTER]: "  -e aBaseDir
    fi

    if [[ ${aBaseDir} == "~"* || ${aBaseDir} == "\$HOME"* ]]; then
        homePath=$(echo $HOME)
        partialBaseDir=${aBaseDir#*/}
        dcUtilsBaseDir="${homePath}/${partialBaseDir}"
    else
        dcUtilsBaseDir=${aBaseDir}
    fi

    if [[ ! -d "${dcUtilsBaseDir}/dcUtils" ]]; then
        if [[ ! -d ${dcUtilsBaseDir} ]]; then
            echo "That directory ${dcUtilsBaseDir} doesn't exist"
            read -i "y" -p "Do you want it created [y or n]: " -e createdReply
            if [[ ${createdReply} == "y" ]]; then
                mkdir -p ${dcUtilsBaseDir}
            else
                echo "not created."
                exit 1
            fi
        fi

        cd ${dcUtilsBaseDir}
        echo "cloning dcUtils in directory: ${dcUtilsBaseDir}"
        git clone https://github.com/devopscenter/dcUtils.git

        dcUTILS="${dcUtilsBaseDir}/dcUtils"
    else
        dcUTILS="${dcUtilsBaseDir}/dcUtils"

        echo 
        echo "Great, it looks like you already have that directory."
        echo "we'll just update it"
        echo

        cd ${dcUTILS}
        git pull origin master
    fi
}


#-----  End of Function definition  -------------------------------------------


# get BASE_DIR from getMyPath
getBasePath

# get the init.conf to set up some common defaults
if [[ -f "${BASE_DIR}/init.conf" ]]; then
    source "${BASE_DIR}/init.conf"
fi


#-------------------------------------------------------------------------------
# set up $HOME/.dcConfig 
#-------------------------------------------------------------------------------

if [[ ! -d $HOME/.dcConfig ]]; then
    mkdir "${HOME}"/.dcConfig
fi

CUR_DIR=$(pwd)

#-------------------------------------------------------------------------------
# need to check what version of bash they have on their machine
# if their machine is OSX they will need to use homebrew to install the lastest bash
# if not on OSX and the version is less then 4, then tell them they need to update bash
#-------------------------------------------------------------------------------
OSNAME=$(uname -s)

BV=$(/usr/bin/env bash -c 'echo $BASH_VERSION')
if [[ $BV != "4"* ]]; then
    if [[ ${OSNAME} == "Linux" ]]; then
        echo "The devops.center scripts all run with Bash version 4+.  It doesn't have"
        echo "to be the shell that you use, but the scripts will look specifically for bash."
        echo "You will need to update your version of bash to the major revison 4.  The"
        echo "devops.center scripts work with the latest bash version 4."
        echo "Please use your normal installation method for installing/upgrading new"
        echo "software to install/update the latest version 'bash'."
        exit 1
    elif [[ ${OSNAME} == "Darwin" ]]; then
        echo "The devops.center scripts all run with Bash version 4+.  It doesn't have"
        echo "to be the shell that you use, but the scripts will look specifically for bash."
        echo "You will need to update your version of bash to the major revison 4.  The"
        echo "devops.center scripts work with the latest bash version 4."
        echo "For OSX it is suggested to get bash via Homebrew and then make sure that the"
        echo "path to the installation of bash is first on your PATH environment variable."
        exit 1
    else
        echo "We need to determine what version of Bash is running on your machine and we"
        echo "can't determine what type of OS you are running. Please report the name of the"
        echo "OS that you are running to devops.center representative. This is accomplished"
        echo "by running the command 'uname -s' on the command line."
        exit 1
    fi
fi

#-------------------------------------------------------------------------------
# get some details to go into settings:
#     customer name
#     user name
#     region
#     base directory for application development
#     dcUtils path
#     directory path to common shared directory
#     
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# get customer name
#-------------------------------------------------------------------------------
echo 
echo "First, we ask for your customer name.  This will be used"
echo "as the value for the cloud based profile and should be the same for everyone"
echo "within the company.  Please enter one word, no spaces, all lowercase letters"
echo "and can use periods instead of spaces."
echo 

# check to see if we have a default value
if [[ ${CUSTOMER_NAME} ]]; then
    read -i ${CUSTOMER_NAME} -p "Enter your customer name and press [ENTER]: " -e  customerName
else
    read -p "Enter your customer name and press [ENTER]: "  customerName
fi

if [[ -z ${customerName} ]]; then
    echo "Entering the customer name is required, exiting..."
    exit 1
fi

CUSTOMER_NAME=${customerName,,}
PROFILE=${CUSTOMER_NAME}


#-------------------------------------------------------------------------------
# get user name  for the cloud environment
#-------------------------------------------------------------------------------
echo 
echo "Enter your username, one word, no spaces and all lowercase letters."
echo 

# check to see if we have a default value
if [[ ${USER_NAME} ]]; then
    read -i ${USER_NAME} -p "Enter your user name and press [ENTER]: " -e userName
else
    read -i $USER -p "Enter your user name and press [ENTER]: " -e userName
fi

if [[ -z ${userName} ]]; then
    echo "Entering the user name is required, exiting..."
    exit 1
fi
USER_NAME=${userName,,}


#-------------------------------------------------------------------------------
# get the base directory name for the  shared drive path
#-------------------------------------------------------------------------------
echo
echo "We need the directory path to where the shared drive is located on your local"
echo "machine.  This will be used to look for shared keys and other administrative"
echo "functions that are shared between all developers working with the devops.center"
echo "tools."
echo

if [[ "${dcCOMMON_SHARED_DIR}" ]]; then
    read -i "${dcCOMMON_SHARED_DIR}" -p "Enter the shared drive path and press [ENTER]: " -e sharedDrivePath
else
    read -i "~/Google Drive" -p "Enter the shared drive path and press [ENTER]: " -e sharedDrivePath
fi

if [[ ${sharedDrivePath} == "~"* || ${sharedDrivePath} == "\$HOME"* ]]; then
    homePath=$(echo $HOME)
    partialCommonDir=${sharedDrivePath#*/}
    dcCOMMON_SHARED_DIR="${homePath}/${partialCommonDir}"
else
    dcCOMMON_SHARED_DIR=${sharedDrivePath}
fi

#-------------------------------------------------------------------------------
# get which git service the customer is using and their repository account name
#-------------------------------------------------------------------------------
echo  
echo "Provide the git service name (ie, github, assembla, etc) that holds your repositories"
echo "for you company. Defaults to github"
echo 
# check to see if we have a default value
if [[ "${GIT_SERVICE_NAME}" ]]; then
    read -i "${GIT_SERVICE_NAME}" -p "Enter the git service name and press [ENTER]: "  -e gitService
else
    read -i "github" -p "Enter the git service name and press [ENTER]: "  -e gitService
fi

echo 
echo "And now enter the account name on that service"
echo 
# check to see if we have a default value
if [[ "${GIT_ACCOUNT_NAME}" ]]; then
    read -i "${GIT_ACCOUNT_NAME}" -p "Enter your git account name and press [ENTER]: "  -e gitAccount
else
    read -i "${CUSTOMER_NAME}" -p "Enter your git account name and press [ENTER]: "  -e gitAccount
fi


#-------------------------------------------------------------------------------
# get the local development directory
#-------------------------------------------------------------------------------
echo  
echo "Enter the directory name that will serve as the basis for you application development"
echo "The devops.center scripts will use this directory to put the application development"
echo "files and the application website. This can be anywhere within your local machine and"
echo "named anything you would like.  A suggestion might be to put it in your "
echo "home directory and call it devops: ~/devops/apps"
echo  

# check to see if we have a default value
if [[ "${DEV_BASE_DIR}" ]]; then
    read -i "${DEV_BASE_DIR}" -p "Enter the directory and press [ENTER]: "  -e localDevBaseDir
else
    read -i "~/devops/apps" -p "Enter the directory and press [ENTER]: "  -e localDevBaseDir
fi

if [[ -z ${localDevBaseDir} ]]; then
    echo "Entering the local development directory is required, exiting..."
    exit 1
fi

if [[ ${localDevBaseDir} == "~"* || ${localDevBaseDir} == "\$HOME"* ]]; then
    homePath=$(echo $HOME)
    partialBaseDir=${localDevBaseDir#*/}
    localDevBaseDir="${homePath}/${partialBaseDir}"
fi

if [[ ! -d ${localDevBaseDir} ]]; then
    echo "That directory ${localDevBaseDir} doesn't exist"
    read -i "y" -p "Do you want it created [y or n]: " -e createdReply
    if [[ ${createdReply} == "y" ]]; then
        mkdir -p ${localDevBaseDir}
    else
        echo "not created."
        exit 1
    fi
fi
DEV_BASE_DIR=${localDevBaseDir}


#-------------------------------------------------------------------------------
# clone dcUtils where the user wants it
#-------------------------------------------------------------------------------
clonedcUtils

#-------------------------------------------------------------------------------
# create the personal private access key to authenticate ssh to an instance 
# ... put it in the .ssh/devops.center directory or the ~/.dcConfig/ directory
#-------------------------------------------------------------------------------
createUserSpecificKeys

#-------------------------------------------------------------------------------
# we have collected all the information we need now write it out to .dcConfig/settings
#-------------------------------------------------------------------------------
writeToSettings

#-------------------------------------------------------------------------------
# we need to copy over the dcEnv.sh over to /usr/local/bin so the scripts that
# don't use process_dc_env.py can still get the logging functions that display a 
# better output. 
#-------------------------------------------------------------------------------
copyLoggingScript

#-------------------------------------------------------------------------------
# tell the user to add path to dcUtils to the $PATH
#-------------------------------------------------------------------------------
echo
echo "** NOTE **"
echo "You will need to add a line in your shell rc file where the specific rc file is "
echo "dependent on what shell (ie bash, zsh, csh,...) you run when interacting with "
echo "the terminal.  The line is : "
echo "    source ~/.dcConfig/settings"
echo "Sourcing this file will put the minimal amount of environment variables in your"
echo "environment and put $dcUTILS into your PATH,"
echo "both of which are needed to run the devops.center scripts. Then you will need"
echo "to either log out and log back in, or if you cant't log out, then in each "
echo "terminal window that you use, execute that source command. If you don't put"
echo "it in the appropriate rc file then any new terminal you open will not have"
echo "the proper environment variables to run the devops.center scripts."
echo


#-------------------------------------------------------------------------------
# and now move back to the original directory this script was started in
#-------------------------------------------------------------------------------
cd ${CUR_DIR}

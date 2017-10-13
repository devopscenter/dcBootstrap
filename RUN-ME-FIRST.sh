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
#                   - then 
#           
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Gregg Jensen (), gjensen@devops.center
#  ORGANIZATION: devops.center
#       CREATED: 07/18/2017 15:17:42
#      REVISION:  ---
#===============================================================================

#set -o nounset             # Treat unset variables as an error
#set -x                     # essentially debug mode
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
#          NAME:  determineProfile
#   DESCRIPTION:  will check to see if the .aws/config is on the default or a real-profile
#    PARAMETERS:  
#       RETURNS:  
#-------------------------------------------------------------------------------
determineProfile()
{
    aProfile=$(aws configure get region --profile ${PROFILE} 2>&1 > /dev/null)
    if [[ ${aProfile} == *"could not be found"* ]]; then
        anotherProfile=$(aws configure get region --profile default)
        if [[ ${anotherProfile} == "us-west-2" ]] || [[ ${anotherProfile} == "us-east-1" ]]; then
            INITIAL_PROFILE="default"
        fi
    else
        INITIAL_PROFILE=${PROFILE}
    fi
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
        cp ${dcUTILS}/scripts/dcEnv.sh /usr/local/bin/dcEnv.sh
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
#          NAME:  setupIAMUser
#   DESCRIPTION:  creates the IAM user under a specific group which defines the rolse
#                 for this user.  
#    PARAMETERS:  
#       RETURNS:  
#-------------------------------------------------------------------------------
setupIAMUser()
{
    echo "Setting up this user as an IAM user"

    # The group name that was set up at customer registration time.  There should be a group that would
    # be named CUSTOMER_NAME-dev and the policy for the group is to have EC2 and S3 full read/write access
    # but not admin priviledge.  That is left to the authenticated user(s)
    IAMUserGroup="${CUSTOMER_NAME}-dev"
        

	IAMUserToCreate=${USER_NAME}
    if [[ $(aws --profile ${INITIAL_PROFILE} --region ${REGION} iam get-user --user-name ${IAMUserToCreate} 2>&1 > /dev/null) == *"cannot be found"* ]]; then
        sleep 2
        createUser=$(aws --profile ${INITIAL_PROFILE} --region ${REGION} iam create-user --user-name  ${IAMUserToCreate} 2>&1 > /dev/null)
        sleep 2

        # create the keys for the user
        accessKeys=$(aws --profile ${INITIAL_PROFILE} --region ${REGION} iam create-access-key --user-name  ${IAMUserToCreate})
        SECRET_ACCESS_KEY=$(jq -r '.AccessKey.SecretAccessKey' <<< "$accessKeys")
        ACCESS_KEY=$(jq -r '.AccessKey.AccessKeyId' <<< "$accessKeys")
        sleep 2

        # add the login to a group so that the policy can be attached to the group rather  than the user
        addToGroup=$(aws --profile ${INITIAL_PROFILE} --region ${REGION} iam add-user-to-group --user-name ${IAMUserToCreate} --group-name ${IAMUserGroup} 2>&1 > /dev/null)
        sleep 2
    else
        # add the login to a group so that the policy can be attached to the group rather than the user
        addToGroup=$(aws --profile ${INITIAL_PROFILE} --region ${REGION} iam add-user-to-group --user-name ${IAMUserToCreate} --group-name ${IAMUserGroup} 2>&1 > /dev/null)
        sleep 2

        # create the keys for the user
        accessKeys=$(aws --profile ${INITIAL_PROFILE} --region ${REGION} iam create-access-key --user-name  ${IAMUserToCreate})
        SECRET_ACCESS_KEY=$(jq -r '.AccessKey.SecretAccessKey' <<< "$accessKeys")
        ACCESS_KEY=$(jq -r '.AccessKey.AccessKeyId' <<< "$accessKeys")
        sleep 2

    fi
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  runAWSConfigure
#   DESCRIPTION:  runs the aws configure --profile command with the appropriate informaitno
#                 this constitutes running several aws configure set commands with the required data
#    PARAMETERS:  
#       RETURNS:  
#-------------------------------------------------------------------------------
runAWSConfigure()
{
    echo "Setting up this users AWS configuration"

    if [[ -z ${ACCESS_KEY} ]]; then
        echo
        echo "** NOTE **"
        echo "The keys could not be created so the .aws/credentials could not be updated"
        echo "This will have to be corrected manually before any additional devops.center"
        echo "scripts can be run."
        echo
    else
        aws configure set aws_access_key_id ${ACCESS_KEY} --profile ${PROFILE}
        sleep 2
        aws configure set aws_secret_access_key ${SECRET_ACCESS_KEY} --profile ${PROFILE}
        sleep 2
        aws configure set region ${REGION} --profile ${PROFILE}
        sleep 2
        aws configure set output json --profile ${PROFILE}
        sleep 2
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
    # call the ssh-keygen to create a private/public set of keys
    echo "Creating ssh access keys (dcaccess-key) to be used to access the AWS instances"
    ssh-keygen -t rsa -N "" -f ~/.ssh/dcaccess-key -q
    mv ~/.ssh/dcaccess-key ~/.ssh/dcaccess-key.pem
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  sendKeysTodc
#   DESCRIPTION:  sends the public key to devops.center,whom will distribute to the 
#                 customer instances
#    PARAMETERS:  
#       RETURNS:  
#-------------------------------------------------------------------------------
sendKeysTodc()
{
    # TODO: when creating the groups that will be used by the IAM users, need to create
    #       one that has the policies: IAMUserSSHKeys
    #       this group will be used for the script in this function to upload the ssh public
    #       keys to the IAM role
    #       PLACEHOLDER name for the group: public-key-transfer

    echo "And now we need to associate the public key with the new IAM user"
    echo
    # send the public key to the IAM user just created and devops.center will disseminate
    # it to the appropriate instances
    # add group public-key-tranfer to the IAM user
    aws --profile ${INITIAL_PROFILE} --region ${REGION} iam add-user-to-group --user-name ${USER_NAME} --group-name public-key-transfer 2>&1 > /dev/null
    sleep 2

    # upload the public key
    UPLOAD=$(aws --profile ${INITIAL_PROFILE} --region ${REGION} iam upload-ssh-public-key --user-name ${USER_NAME} --ssh-public-key-body "$(cat ~/.ssh/dcaccess-key.pub) 2>&1 > /dev/null")
    sleep 2

    # remove the group public-key-tranfer from the IAM user
    aws --profile ${INITIAL_PROFILE} --region ${REGION} iam remove-user-from-group --user-name ${USER_NAME} --group-name public-key-transfer 2>&1 > /dev/null
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  writeToSettings
#   DESCRIPTION:  this function will write the necessary key/value pairs out to
#                 ~/dcConfig/settings
#    PARAMETERS:  
#       RETURNS:  
#-------------------------------------------------------------------------------
writeToSettings()
{
    echo "dcCloudService=AWS" > ~/.dcConfig/settings
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
    
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  cleanUpAWSConfigs
#   DESCRIPTION:  remove the bootstrap section from the .aws/{config|credentials}
#    PARAMETERS:  
#       RETURNS:  
#-------------------------------------------------------------------------------
cleanUpAWSConfigs()
{
    cd ~/.aws

    # do a diff and grab the lines that are different in the new one
    echo "[profile ${PROFILE}]" > config.NEW
    diff config.OLD config | grep '^>' | sed 's/^>\ //' >> config.NEW
    echo "[${PROFILE}]" > credentials.NEW
    diff credentials.OLD credentials | grep '^>' | sed 's/^>\ //' >> credentials.NEW

    #-------------------------------------------------------------------------------
    # make the NEW ones the ones to keep
    #-------------------------------------------------------------------------------
    mv config.NEW config
    mv credentials.NEW credentials

    #-------------------------------------------------------------------------------
    # and remove the OLD ones
    #-------------------------------------------------------------------------------
    rm config.OLD credentials.OLD

    if [[ ${ALREADY_HAS_AWS_CONFIGS} == "yes" ]]; then
        # they had an original config and credentials.  Append the new files to the 
        # original ones
        alreadyHasEntry=$(grep $PROFILE ~/.aws/config.ORIGINAL)
        if [[ -z ${alreadyHasEntry} ]]; then
            cat config >> config.ORIGINAL
            cat credentials >> credentials.ORIGINAL
        else
            # they already have a profile by this name so make a second one
            echo 
            echo "There was already an entry in the original .aws/config for the "
            echo "profile (${PROFILE} you are creating.  So, the entry will be marked"
            echo "as ${PROFILE}-2 and you might need to do some manual work to clean"
            echo "this up or work with the new name of the profile."

            sed -i "s/${PROFILE}/${PROFILE}-2/" config
            sed -i "s/${PROFILE}/${PROFILE}-2/" credentials

            # and append them to the original file
            cat config >> config.ORIGINAL
            cat credentials >> credentials.ORIGINAL
        fi

        # and move the original back to the only copy left in the .aws directory.
        mv config.ORIGINAL config
        mv credentials.ORIGINAL credentials
    fi
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  bootstrapAWSConfigs
#   DESCRIPTION:  
#    PARAMETERS:  
#       RETURNS:  
#-------------------------------------------------------------------------------
bootstrapAWSConfigs()
{
    ALREADY_HAS_AWS_CONFIGS="no"

    if [[ -f $HOME/.aws/credentials ]]; then
        # copy the original config and credentials so we don't bother them
        mv ~/.aws/config ~/.aws/config.ORIGINAL
        mv ~/.aws/credentials ~/.aws/credentials.ORIGINAL

        # set this to yes, meaning that they already had a config/credentials file so do NOT
        # clean it up
        ALREADY_HAS_AWS_CONFIGS="yes"
    fi

    if [[ -f "${BASE_DIR}/bootstrap-aws.tar" ]]; then
        cd $HOME
        tar -xf "${BASE_DIR}/bootstrap-aws.tar"
        cp ~/.aws/config ~/.aws/config.OLD
        cp ~/.aws/credentials ~/.aws/credentials.OLD
    else
        echo 
        echo "Could not find the bootstrap-aws tar ball which is required to begin"
        echo "this script.  Contact the devops.center representative to ensure that"
        echo "the file is created and put into the directory: ${BASE_DIR}"
        echo
        exit 1
    fi

    #-------------------------------------------------------------------------------
    # NOTE: Don't forget to remove the bootstrap sections out of the config and credentials
    # when this script is done
    #-------------------------------------------------------------------------------
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
# need to check to see if aws and jq have been loaded and if not install them
#-------------------------------------------------------------------------------
CHECK_AWS=$(which aws)
if [[ ! ${CHECK_AWS} ]]; then
    echo 
    echo "The devops.center scripts will use the AWS cli commands to access AWS."
    echo "The command 'aws' does not appear to be installed on your machine."
    echo "Note that the aws cli is installed via the python installation process"
    echo "called: pip.  This requires python to be installed with version 2.7+."
    echo "(python version 2.7+ is what the devops.center scripts use)"
    echo 
    exit 1
fi

CHECK_JQ=$(which jq)
if [[ ! ${CHECK_JQ} ]]; then
    echo 
    echo "The devops.center scripts will use the aws cli commands to access AWS"
    echo "and then the jq command (jq is a json output interpreter) to cull"
    echo "additional information from the results that come from the aws command."
    echo "The command 'jq' does not appear to be installed on your machine."
    echo "Please use your normal installation method for intalling new"
    echo "software to install the command 'jq'."
    echo 
    exit 1
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
echo "This value will be used to create a AWS IAM user specifically for you."
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
# if using AWS get the region for the instances
#-------------------------------------------------------------------------------
echo 
echo "If the cloud environment you are using is AWS, enter the region that the cloud "
echo "instances will be in when they are created. This value can be obtained from the"
echo "main authentication user if it is not known. "
echo "(The value is typically us-west-2 or us-east-1.)"
echo 

# check to see if we have a default value
if [[ ${REGION} ]]; then
    read -i ${REGION} -p "Enter the region and press [ENTER]: " -e region
else
    read -i us-west-2  -p "Enter the region and press [ENTER]: " -e region
fi

if [[ -z ${region} ]]; then
    REGION=us-west-2
else
    REGION=${region,,}
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
# now we need to get the bootstrap aws config and credentials to be able to set
# up the IAM user
#-------------------------------------------------------------------------------
bootstrapAWSConfigs

#-------------------------------------------------------------------------------
# need to help them run through setting up the IAM user for this user and use 
# the AccessKey and SecretKey that is created specifically for this user to be 
# used in the aws configure setup. 
#-------------------------------------------------------------------------------
determineProfile
setupIAMUser

#-------------------------------------------------------------------------------
# create the personal private access key to authenticate ssh to an instance 
# ... put it in the .ssh/devops.center directory or the ~/.dcConfig/ directory
#-------------------------------------------------------------------------------
createUserSpecificKeys

#-------------------------------------------------------------------------------
# and make the shared key available to devops.center 
#-------------------------------------------------------------------------------
sendKeysTodc

#-------------------------------------------------------------------------------
# run aws configure with the appropriate information gathered so far
#-------------------------------------------------------------------------------
runAWSConfigure

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
# Now is the time to remove the bootstrap section from the .aws/{config|credentials}
# this will leave the config and credentials with the PROFILE specifc information and
# their specific credentials in the ~/.aws/ config files.
#-------------------------------------------------------------------------------
cleanUpAWSConfigs

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
echo "environment and put $dcUTILS into your PATH, both of which are needed to run the"
echo "devops.center scripts. Then you will need to either log out and log back in,"
echo "or if you cant't log out, then in each terminal window that you use, execute "
echo "that source command. If you don't put it in the appropriate rc file then any new"
echo "terminal you open will not have the proper environment variables to run the "
echo "devops.center scripts."
echo


#-------------------------------------------------------------------------------
# and now move back to the original directory this script was started in
#-------------------------------------------------------------------------------
cd ${CUR_DIR}

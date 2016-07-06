#!/usr/bin/env bash
set -euo pipefail

# http://unix.stackexchange.com/questions/10922/temporarily-suspend-bash-history-on-a-given-shell
# http://stackoverflow.com/a/2654048/2975300
# http://stackoverflow.com/a/28393320/2975300

github_username="SatelliteQE"
playbooks_repo_name="sat6helper"

repo_zip_package_url="https://github.com/$github_username/$playbooks_repo_name/archive/master.zip"

current_user="$USER"
current_directory=$(pwd)
stty_orig=$(stty -g)

trap "stty '$stty_orig'; stty echo" SIGINT SIGTERM

function read_secret()
{   
    
    # Disable echo.
    stty_orig=$(stty -g)
    stty -echo

    # Set up trap to ensure echo is enabled before exiting if the script
    # is terminated while echo is disabled.
    trap 'stty echo' EXIT

    # run command
    read -p "[sudo] password for $current_user": user_passwd

    # Enable echo.
    stty "$stty_orig"
    stty echo
    trap - EXIT

    # Print a newline because the newline entered by the user after
    # entering the passcode is not echoed. This ensures that the
    # next line of output begins at a new line.
    echo
}


function install_ansible_and_other_required_tools(){
    sudo -S <<< "$user_passwd" dnf update -y
    sudo -S <<< "$user_passwd" dnf install -y wget unzip python2 python-devel libffi-devel redhat-rpm-config openssl-devel yum python-dnf

    is_python2_pip=$(pip --version | grep 2.7 &> /dev/null && echo 'yes' || echo 'no')
    if [ "$is_python2_pip" = "no" ]; then
      echo "pip to Python2 is not installed. installing now"
      wget https://bootstrap.pypa.io/get-pip.py -O /tmp/get-pip.py
      sudo -H -S <<< "$user_passwd" python2 /tmp/get-pip.py -U
    fi
    
    
    is_ansible_old_version=$(ansible --version | grep " 2." &> /dev/null && echo 'no' || echo 'yes')
    if [ "$is_ansible_old_version" = "yes" ]; then
        sudo -H -S <<< "$user_passwd" pip install ansible -U
    fi
    

}

function run_playbook(){
    local file_name="$playbooks_repo_name.zip"
    local file_full_output_path="/tmp/deploy_my_machine/$file_name"
    cd /tmp || exit
    sudo -H -S <<< "$user_passwd" rm -r /tmp/deploy_my_machine 2> /dev/null 
    mkdir -p /tmp/deploy_my_machine
    cd /tmp/deploy_my_machine || exit
    wget -O $file_full_output_path "$repo_zip_package_url"

    unzip $playbooks_repo_name
    cd "$playbooks_repo_name-master" || exit

    echo "running playbook"
    cd dev/playbooks
    ansible-playbook workstation.yml --extra-vars "ansible_become_pass=$user_passwd"
    cd $current_directory
    rm -r /tmp/deploy_my_machine 2> /dev/null 
}


if [[ $EUID -ne 0 ]]; then
    # temporary disable history record
    set +o history
    echo -e "\nStarting Installation" 2>&1
    
    # read current user password
    read_secret
    
    # install ansible, wget and unzip
    install_ansible_and_other_required_tools
    
    run_playbook
    
    unset user_passwd
    
    cd $current_directory
    
    # re-enable history record
    set -o history

    exit 0
else
    echo -e "\nPlease not run this with root privilege" 2>&1
    echo -e "Stopping the installation and exiting\n" 2>&1

    exit 1

fi

#!/bin/bash
set -e

# bash script that makes bash scripts run at startup

# colors some things
green="\e[32m"
red="\e[31m"
reset="\e[0m" 

# configure
configure(){

    # I think it is recomended directory for the startup script
    dest_dir_for_target_file=/usr/local/sbin/
    
    printf "Enter your script filename that you want to run at startup\n${red}>>> ${reset}"
    read target_file

    echo "
Do you want to let this script in its current dicrectory or move it to other directory?
Options:
1-- Let it in it's current dicrectory
2-- Move it to '${dest_dir_for_target_file}'
3-- Move it to other dicrectory (you choose it)
"
    printf "${red}>>>${reset} "
    read choice
    
    temp_target_file=${target_file%.*}.service
    temp_target_file=${temp_target_file##*/}
    target_service_file=${temp_target_file}
    # i had problems when tried to move service file to /etc/systemd/user/ so i use /etc/systemd/system/ instead
    dest_dir_for_target_service_file=/etc/systemd/system/
    
    case $choice in
        1)
        if [ -f $(pwd)/${target_file} ]; then
            dest_dir_for_target_file=$(pwd)/
        else
            dest_dir_for_target_file="${target_file%/*}"
        fi
        move_target_file_to_another_dir=0 # false
        ;;
        2)
        dest_dir_for_target_file=/usr/local/sbin/
        move_target_file_to_another_dir=1 # true
        ;;

        3)
        echo "Enter directory where you want your startup script to be stored:"
        printf "\n${red}>>>${reset} "
        read dest_dir_for_target_file
        move_target_file_to_another_dir=1 # true
        ;;

        *)
        printf "\n${red}Your option is not valid!\n${reset}"
        exit 1
        ;;
    esac
}

# check if everything is ok
check_if_ok(){
    printf "Checking some things..."

    problems=()
    
    # check if script is running as root
    if [ $EUID -ne 0 ]; then
        problems+=("Please run me as root")
    fi

    # check if needed file exists (In our dir)
    if [ $choice -eq 1 ]; then
        if [ ! -f "$target_file" ]; then
            problems+=("File: ' ${target_file} ' does not exist!")
        fi
    fi
    
    # check if needed directory exists
    if [ $move_target_file_to_another_dir -eq 1 ]; then
        if [ ! -d $dest_dir_for_target_file ]; then
            problems+=("Directory: ' ${dest_dir_for_target_file} ' does not exist!")
        fi
    fi
    
    # check if needed file exists
    if [ $choice -eq 2 ] || [ $choice -eq 3 ]; then
        if [ ! -f ${target_file} ]; then
            problems+=("File: ' ${target_file} ' does not exist!")
        fi
    fi

    if [ ${#problems[@]} -ne 0 ]; then
        printf "\n${red}Some problems occurred:${reset}\n\n"
        for eachProblem in "${problems[@]}"; do echo -e "${red}*${reset} $eachProblem"; done
        exit 1
    else
        printf "${green}OK${reset}\n"
    fi
}

# ask user if proceed or no
ask_if_proceed(){
    echo "
I will do this things:
1-- Move ${target_file} to ${dest_dir_for_target_file} 
2-- Make it executable
3-- Create and edit ${dest_dir_for_target_service_file}${target_service_file}
4-- Reload daemon
5-- Enable service ${target_service_file}
6-- Start service ${target_service_file}
"

    printf "\nIs this ok? [y/n]\n${red}>>>${reset} "
    read is_ok

    case $is_ok in
        y | Y | yes | YES) echo ;;
        *) exit 0;;
    esac
}

# main function to make script run at startup
register_on_startup(){

    if [ $move_target_file_to_another_dir -eq 1 ]; then
        printf "Moving  ${target_file} to ${dest_dir_for_target_file} ..."
        mv $target_file $dest_dir_for_target_file
        target_file=${dest_dir_for_target_file}/${target_file##*/}
        printf "${green}OK${reset}\n"
        
    fi
    
    printf "Changing permissions for ${target_file} ..."
    sudo chmod +x ${target_file}
    target_file=${target_file##*/}
    printf "${green}OK${reset}\n"
    
    # Don't remove underscores, because this script won't write all this config to the service file, anyways you can edit this service file later
    config_for_target_service_file="[Unit]\nDescription=Startup_bash_script\n\n[Service]\nExecStart=${dest_dir_for_target_file}/${target_file}\n\n[Install]\nWantedBy=multi-user.target\n"
    
    printf "Editing ${dest_dir_for_target_service_file}${target_service_file} ..."
    printf ${config_for_target_service_file} > ${dest_dir_for_target_service_file}${target_service_file}
    printf "${green}OK${reset}\n"

    printf "Reloading daemon..."
    systemctl daemon-reload
    printf "${green}OK${reset}\n"

    printf "Enabling service: ${target_service_file} ..."
    systemctl enable ${target_service_file}
    printf "${green}OK${reset}\n"

    printf "Starting service: ${target_service_file} ..."
    systemctl start ${target_service_file}
    printf "${green}OK${reset}\n"
    
    printf "${green}\nDone\n${reset}"
    # print some useful info
    echo -e "
${green}Do ${red}not${reset} forget that:
${red}*${reset} You can edit ${dest_dir_for_target_service_file}${target_service_file} at any time, or remove it
${red}*${reset} You can disable ${target_service_file} by typing: sudo systemctl disable ${target_service_file}
${red}*${reset} You can remove ${target_service_file} by typing: sudo rm ${dest_dir_for_target_service_file}${target_service_file}
"

}

echo "Before using this script, make sure that SELinux is set to permissive mode"
configure
check_if_ok
ask_if_proceed
register_on_startup

!/bin/bash

echo -e "---------------------------------------------------------\nThis script will transfer files from your specified directory to the Coronation Group remote server."
read -p "Please enter your username on the remote server: " user_name

read -p  "Enter remote server ip or dns: " remote

read -p "Please enter the the path to save the file on $remote: " remote_path 

read -p "Please enter the the path to the file you want to move: " local_dir

echo -e "\nThe command being run is: scp $local_dir $user_name@$remote:$remote_path"

scp $local_dir $user_name@$remote:$remote_path

if ["$?" -eq "0"]; then
    echo -e "\nThe file has been copied to $remote successfully."
else 
    echo -e "---------------------------------------------\nTransfer failed, please retry again."
fi

#Another method using SFTP and not SCP
# echo -e "Running $user_name@$remote"
# sftp $user_name@$remote

# if ["$?" -eq "0"]; then
#     echo -e "\nRunning put $local_dir"
#     put $local_dir
# else
#     echo -e "---------------------------------------------\nTransfer failed, please retry again."
# fi
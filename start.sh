#!/bin/zsh
# If you want to run yours with root, then you can remove this. I run mine as the user so I can run some commands that are far more annoying to run with root.
if [[ $(id -u) = 0 ]]; then
	echo "This script may not run properly with root."
	exit 33
else
	echo "Checking for sudo."
	sudo -k
	if sudo true; then
		echo "You have sudo."
	else
		echo "No sudo."
		exit 33
	fi
fi

# VM chooser. You can add a grep below if you want to only show VMs that match a certain string.
echo "List of Virtual Machines:"
virsh list --name --all | nl # | grep "gpu" for example before the nl 
read "VMN?Enter the number of the virtual machine you want to select: "
VM=$(virsh list --name --all | sed "${VMN}q;d") # If you added a grep above, you'll need to add it here as well, before the sed.
echo "You have chosen $VM."

echo "Stopping Display Manager, then waiting 5 seconds." && sudo systemctl stop display-manager.service
sleep 5
# You can add anything else you want in here, like starting an SMB service for a network drive in your VM.
echo "Running GPU driver checks."
if sudo fuser -s $(find /dev/dri/ -iname "renderD*") || sudo fuser -s $(find /dev/dri/ -iname "card*"); then
	echo "GPU still in use."
	read "REPLY?Attempt to force kill all processes using the GPU? [Y/n] "
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		sudo lsof -t $(find /dev/dri/ -iname "renderD*") | xargs -I '{}' sudo kill -9 {}
		if sudo fuser -s $(find /dev/dri/ -iname "renderD*") || sudo fuser -s $(find /dev/dri/ -iname "card*"); then
			echo "\nGPU still in use, even after force kill. \n\nAborting."
			read -s -k \?"Press any key to start Display Manager and exit."
			sudo systemctl start display-manager.service
			{ exit 1; }
		else
			echo "\nGPU no longer in use."
			# You can add services, drive mounts, etc here as well. Make sure to add them in the other places this comment is placed as well.
			echo "Booting VM."
			virsh start $VM
		fi
	else
		echo "\nAborting."
		read -s -k \?"Press any key to start Display Manager and exit."
		sudo systemctl start display-manager.service
		{ exit 1; }
	fi
else
	# You can add services, drive mounts, etc here as well. Make sure to add them in the other places this comment is placed as well.
	echo "Booting VM."
	virsh start $VM
fi

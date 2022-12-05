These playbooks will perform basic configuration of slurm login and compute nodes

tasks:
  - Allow * to ssh without checking keys
  - Set sysctl.conf file
  - Set motd
  - Change hostname to remove account number
  - Remove /home
  - Create symlink for /home and mount /home from Powerscale
  - Add internally hosted repos
  - Configure chronyd to time1.r-hpc.com & time2.r-hpc.com 
  - Login: Export /opt
  - Login: Enable SSH
  - Login: Generate SSH key for root
  - Compute: Create /scratch and mount, if /dev/sdb exists
  - Compute: Configure autofs, mount /opt
  - Compute: Add login node ssh key to authorized_keys and copy the login ssh key

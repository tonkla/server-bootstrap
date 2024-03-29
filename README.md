# Debian-based Server Bootstrap

This script is a 2009 DevOps, now I have utilized container-based deployment.

## Steps

Update locale,

`update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8`

Update security patches,

`apt update && apt upgrade`

Create a new sudoer user,

`useradd -m -s /bin/bash -G sudo [username]`

Copy `.ssh/authorized_keys` to the new user's home directory,

`cp -r .ssh /home/[username] && chown -R [username]:[usergroup] /home/[username]/.ssh`

Then, login with the new user.

Set Vim as a default editor,

`update-alternatives --config editor`

Disable root login `PermitRootLogin no` and password authentication `PasswordAuthentication no`,

`sudo vi /etc/ssh/sshd_config`

Restart SSH daemon,

`sudo service ssh restart`

Optional, disable password for sudoer users,

`sudo visudo`

Modify the line,

`%sudo ALL=(ALL) NOPASSWD: ALL`

Install some useful tools,

`sudo apt install -y byobu htop`

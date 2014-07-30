# Ubuntu init

Personal storage for getting and installing programs I use (especially for
aws hosts).

If you like it, awesome, if not, fork and change it, but this
particular project is not a collaborative project so I won''t fix anything
that works for me.

##Install
sudo apt-get install -y git &&
git clone https://github.com/tobias-/initUbuntu &&
cd initUbuntu &&
./initSystem.sh

##Programs installed
* **Java** All modern versions (6, 7, 8) including JCE
* **Groovy** Latest & greatest version in ubuntu repo
* ~~**Ruby** Latest & greatest version (at the moment)~~
* ~~**Ruby aws** Gem installed version of ruby-aws~~
* **Locales** Locales installed because I use them
* **Various tools** 7zip, tcpdump, zip, unzip etc
* **Cronic** Patched version to only mail stderr or failed programs from cron
* **Nullmailer** Install and configure nullmailer (requires tar.bz2 and base64 /etc/nullmailer
* **Inputrc** Alternative Ctrl-PgUp and Ctrl-PgDown
* **Git /etc** get all of /etc version controlled in case bad stuff happens
* **mongo** mongo from mongodb
* **mms-agent** mms-agent installation and autostart

.. + probably something I forgot

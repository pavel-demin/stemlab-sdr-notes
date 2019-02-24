---
layout: page
title: Development machine
permalink: /development-machine/
---

The following are the instructions for installing a virtual machine with [Debian](https://www.debian.org/releases/jessie) 8.11 (amd64) and [Vivado Design Suite](https://www.xilinx.com/products/design-tools/vivado) 2018.3 with full SDK.

Creating virtual machine with Debian 8.11 (amd64)
-----

- Download and install [VirtualBox](https://www.virtualbox.org/wiki/Downloads)

- Download [mini.iso](http://deb.debian.org/debian/dists/jessie/main/installer-amd64/current/images/netboot/mini.iso) for Debian 8.11

- Start VirtualBox

- Create at least one host-only interface:

  - From the "File" menu select "Preferences"

  - Select "Network" and then "Host-only Networks"

  - Click the small "+" icon

  - Click "OK"

- Create a new virtual machine:

  - Click the blue "New" icon

  - Pick a name for the machine, then select "Linux" and "Debian (64 bit)"

  - Set the memory size to at least 2048 MB

  - Select "Create a virtual hard drive now"

  - Select "VDI (VirtualBox Disk Image)"

  - Select "Dynamically allocated"

  - Set the image size to at least 129 GB

  - Select the newly created virtual machine and click the yellow "Settings" icon

  - Select "Network" and enable "Adapter 2" attached to "Host-only Adapter"

  - Set "Adapter Type" to "Paravirtualized Network (virtio-net)" for both "Adapter 1" and "Adapter 2"

  - Select "System" and select only "Optical" in the "Boot Order" list

  - Select "Storage" and select "Empty" below the "IDE Controller"

  - Click the small CD/DVD icon next to the "Optical Drive" drop-down list and select the location of the `mini.iso` image

  - Click "OK"

- Select the newly created virtual machine and click the green "Start" icon

- Press TAB when the "Installer boot menu" appears

- Edit the boot parameters at the bottom of the boot screen to make them look like the following:

  (the content of the `goo.gl/eagfri` installation script can be seen at [this link](https://github.com/pavel-demin/stemlab-sdr-notes/blob/gh-pages/etc/debian.seed))

{% highlight bash %}
linux initrd=initrd.gz url=goo.gl/eagfri auto=true priority=critical interface=auto
{% endhighlight %}

- Press ENTER to start the automatic installation

- After installation is done, stop the virtual machine

- Select the newly created virtual machine and click the yellow "Settings" icon

- Select "System" and select only "Hard Disk" in the "Boot Order" list

- Click "OK"

- The virtual machine is ready to use (the default password for the `root` and `stemlab-sdr` accounts is `changeme`)

Accessing the virtual machine
-----

The virtual machine can be accessed via SSH. To display applications with graphical user interfaces, a X11 server ([Xming](http://sourceforge.net/projects/xming) for MS Windows or [XQuartz](https://www.xquartz.org) for Mac OS X) should be installed on the host computer. X11 forwarding should be enabled in the SSH client.

Installing Vivado Design Suite
-----

- Download "Vivado HLx 2018.3: All OS installer Single-File Download" from the [Xilinx download page](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/2018-3.html) (the file name is Xilinx_Vivado_SDK_2018.3_1207_2324.tar.gz)

- Create the `/opt/Xilinx` directory, unpack the installer and run it:
{% highlight bash %}
mkdir /opt/Xilinx
cd /opt/Xilinx
tar -zxf Xilinx_Vivado_SDK_2018.3_1207_2324.tar.gz
cd Xilinx_Vivado_SDK_2018.3_1207_2324
sed -i '/uname -i/s/ -i/ -m/' xsetup
./xsetup
{% endhighlight %}

- Follow the installation wizard and don't forget to select "Software Development Kit" on the installation customization page (for detailed information on installation, see [UG973](https://www.xilinx.com/support/documentation/sw_manuals/xilinx2018_3/ug973-vivado-release-notes-install-license.pdf))

- Xilinx SDK requires `gmake` that is unavailable on Debian. The following command creates a symbolic link called `gmake` and pointing to `make`:
{% highlight bash %}
ln -s make /usr/bin/gmake
{% endhighlight %}

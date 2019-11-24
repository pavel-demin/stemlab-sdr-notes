---
layout: page
title: LED blinker
permalink: /led-blinker/
---

Introduction
-----

For my experiments with the STEMlab SDR, I'd like to have the following development environment:

 - recent version of the [Vitis Core Development Kit](https://www.xilinx.com/products/design-tools/vitis.html)
 - recent version of the [Linux kernel](https://www.kernel.org)
 - recent version of the [Debian distribution](https://www.debian.org/releases/stretch) on the development machine
 - recent version of the [Alpine distribution](https://alpinelinux.org) on the STEMlab SDR
 - basic project with all the STEMlab SDR peripherals connected
 - mostly command-line tools
 - shallow directory structure

Here is how I set it all up.

Pre-requirements
-----

My development machine has the following installed:

 - [Debian](https://www.debian.org/releases/stretch) 9.9 (amd64)

 - [Vitis Core Development Kit](https://www.xilinx.com/products/design-tools/vitis.html) 2019.2

The installation of the development machine is described at [this link]({{ "/development-machine/" | prepend: site.baseurl }}).

Here are the commands to install all the other required packages:
{% highlight bash %}
sudo apt-get update

sudo apt-get --no-install-recommends install \
  build-essential git curl ca-certificates sudo \
  libxrender1 libxtst6 libxi6 lib32ncurses5 \
  bc u-boot-tools device-tree-compiler libncurses5-dev \
  libssl-dev qemu-user-static binfmt-support zip \
  squashfs-tools dosfstools parted debootstrap zerofree

sudo ln -s make /usr/bin/gmake
{% endhighlight %}

Source code
-----

The source code is available at

<https://github.com/pavel-demin/stemlab-sdr-notes>

This repository contains the following components:

 - [Makefile](https://github.com/pavel-demin/stemlab-sdr-notes/blob/master/Makefile) that builds everything (almost)
 - [cfg](https://github.com/pavel-demin/stemlab-sdr-notes/tree/master/cfg) directory with constraints and board definition files
 - [cores](https://github.com/pavel-demin/stemlab-sdr-notes/tree/master/cores) directory with IP cores written in Verilog
 - [projects](https://github.com/pavel-demin/stemlab-sdr-notes/tree/master/projects) directory with Vivado projects written in Tcl
 - [scripts](https://github.com/pavel-demin/stemlab-sdr-notes/tree/master/scripts) directory with
   - Tcl scripts for Vivado and SDK
   - shell scripts that build a bootable SD card and SD card image

More details about the directory structure and about the toolchain can be found in the [slides](https://www.dropbox.com/sh/a1yecde4hs91ji0/AABs1GbYTk4WNyZ3spiFR9VFa/ClubVivado2016_Pavel_Demin.pdf?dl=1) of my presentation at [Club Vivado 2016](https://www.xilinx.com/products/design-tools/vivado/club_vivado_2016_archives.html).

Syntactic sugar for IP cores
-----

The [projects/led_blinker](https://github.com/pavel-demin/stemlab-sdr-notes/tree/master/projects/led_blinker) directory contains one Tcl file [block_design.tcl](https://github.com/pavel-demin/stemlab-sdr-notes/blob/master/projects/led_blinker/block_design.tcl) that instantiates, configures and interconnects all the needed IP cores.

By default, the IP core instantiation and configuration commands are quite verbose:
{% highlight Tcl %}
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps_0

set_property CONFIG.PCW_IMPORT_BOARD_PRESET cfg/stemlab_sdr.xml [get_bd_cells ps_0]

connect_bd_net [get_bd_pins ps_0/FCLK_CLK0] [get_bd_pins ps_0/M_AXI_GP0_ACLK]
{% endhighlight %}

With the Tcl's flexibility, it's easy to define a less verbose command that looks similar to the module instantiation in Verilog:
{% highlight Tcl %}
cell xilinx.com:ip:processing_system7:5.5 ps_0 {
  PCW_IMPORT_BOARD_PRESET cfg/stemlab_sdr.xml
} {
  M_AXI_GP0_ACLK ps_0/FCLK_CLK0
}
{% endhighlight %}

The `cell` command is defined in the [scripts/project.tcl
](https://github.com/pavel-demin/stemlab-sdr-notes/blob/master/scripts/project.tcl) script as follows:
{% highlight Tcl %}
proc cell {cell_vlnv cell_name {cell_props {}} {cell_ports {}}} {
  set cell [create_bd_cell -type ip -vlnv $cell_vlnv $cell_name]
  set prop_list {}
  foreach {prop_name prop_value} [uplevel 1 [list subst $cell_props]] {
    lappend prop_list CONFIG.$prop_name $prop_value
  }
  if {[llength $prop_list] > 1} {
    set_property -dict $prop_list $cell
  }
  foreach {local_name remote_name} [uplevel 1 [list subst $cell_ports]] {
    set local_port [get_bd_pins $cell_name/$local_name]
    set remote_port [get_bd_pins $remote_name]
    if {[llength $local_port] == 1 && [llength $remote_port] == 1} {
      connect_bd_net $local_port $remote_port
      continue
    }
    set local_port [get_bd_intf_pins $cell_name/$local_name]
    set remote_port [get_bd_intf_pins $remote_name]
    if {[llength $local_port] == 1 && [llength $remote_port] == 1} {
      connect_bd_intf_net $local_port $remote_port
      continue
    }
    error "** ERROR: can't connect $cell_name/$local_name and $remote_name"
  }
}
{% endhighlight %}

Getting started
-----

Setting up the Vitis and Vivado environment:
{% highlight bash %}
source /opt/Xilinx/Vitis/2019.2/settings64.sh
{% endhighlight %}

Cloning the source code repository:
{% highlight bash %}
git clone https://github.com/pavel-demin/stemlab-sdr-notes
cd stemlab-sdr-notes
{% endhighlight %}

Building `boot.bin`, `devicetree.dtb` and `uImage`:
{% highlight bash %}
make NAME=led_blinker all
{% endhighlight %}

SD card image
-----

Building a bootable SD card image:
{% highlight bash %}
sudo sh scripts/alpine.sh
{% endhighlight %}

A pre-built SD card image can be downloaded from [this link]({{ site.release-image }}).

To write the image to a SD card, copy the content of the SD card image zip file to an SD card.

More details about the SD card image can be found at [this link]({{ "/alpine/" | prepend: site.baseurl }}).

Reprogramming FPGA
-----

It's possible to reprogram the FPGA by loading the bitstream file into `/dev/xdevcfg`:
{% highlight bash %}
cat led_blinker.bit > /dev/xdevcfg
{% endhighlight %}

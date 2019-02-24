---
layout: page
title: Alpine with pre-built applications
permalink: /alpine/
---

Introduction
-----

To simplify maintenance and distribution of the pre-built applications described in the STEMlab SDR notes, I've put together a bootable SD card image based on the lightweight [Alpine Linux](https://alpinelinux.org) distribution.

Getting started
-----

 - Download [SD card image zip file]({{ site.release-image }}).
 - Copy the content of the SD card image zip file to an SD card.
 - Optionally, to start one of the applications automatically at boot time, copy its `start.sh` file from `apps/<application>` to the topmost directory on the SD card.
 - Insert the SD card in STEMlab SDR and connect the power.
 - Applications can be started from the web interface.

The default password for the `root` account is `changeme`.

Network configuration
-----

Wi-Fi is by default configured in hotspot mode with the network name (SSID) and password both set to `STEMlab SDR`. When in hotspot mode, the IP address of STEMlab SDR is [192.168.42.1](http://192.168.42.1).

The wired interface is by default configured to request an IP address via DHCP. If no IP address is provided by a DHCP server, then the wired interface falls back to a static IP address [192.168.1.100](http://192.168.1.100).

The configuration of the IP addresses is in [/etc/dhcpcd.conf](https://github.com/pavel-demin/stemlab-sdr-notes/blob/master/alpine/etc/dhcpcd.conf). More information about [/etc/dhcpcd.conf](https://github.com/pavel-demin/stemlab-sdr-notes/blob/master/alpine/etc/dhcpcd.conf) can be found at [this link](https://www.mankier.com/5/dhcpcd.conf).

From systems with enabled DNS Service Discovery (DNS-SD), STEMlab SDR can be accessed as `sdr-f0xxxx.local`, where `f0xxxx` are the last 6 characters from the MAC address written on the Ethernet connector.

In the local networks with enabled local DNS, STEMlab SDR can also be accessed as `sdr-f0xxxx`.

Useful commands
-----

The [Alpine Wiki](http://wiki.alpinelinux.org) contains a lot of information about administrating [Alpine Linux](https://alpinelinux.org). The following is a list of some useful commands.

Switching to client Wi-Fi mode:
{% highlight bash %}
# configure WPA supplicant
wpa_passphrase SSID PASSPHRASE > /etc/wpa_supplicant/wpa_supplicant.conf

# configure services for client Wi-Fi mode
./wifi/client.sh

# save configuration changes to SD card
lbu commit -d
{% endhighlight %}

Switching to hotspot Wi-Fi mode:
{% highlight bash %}
# configure services for hotspot Wi-Fi mode
./wifi/hotspot.sh

# save configuration changes to SD card
lbu commit -d
{% endhighlight %}

Changing password:
{% highlight bash %}
passwd

lbu commit -d
{% endhighlight %}

Installing packages:
{% highlight bash %}
apk add python3

lbu commit -d
{% endhighlight %}

Editing WSPR configuration:
{% highlight bash %}
# make SD card writable
rw

# edit decode-wspr.sh
nano apps/sdr_transceiver_wspr/decode-wspr.sh

# make SD card read-only
ro
{% endhighlight %}

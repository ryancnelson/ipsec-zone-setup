#!/bin/sh

ifconfig ip.tun0 plumb
ifconfig ip.tun0 100.100.44.2 100.100.44.1 tsrc $PUBIP tdst $DSTIP up

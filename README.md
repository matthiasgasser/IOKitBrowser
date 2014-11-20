IOKitBrowser
============

Uses private API to access various hardware related informations on iOS.
I used it to check the battery cycle count. But there are other informations hidden es well, eg. temperature etc.

(c) developed by Lyon Anderson
http://www.lyonanderson.org/blog/2014/02/12/ios-iokit-browser/

iOS 8 adapted by me.      

## Check memory type:                                                                                  

Root > N61AP > AppleARMPE > arm-io > AppleT7000IO > ans > AppleA7IOPV1 > AppleCSI > asp > ASPStorage

defaults-bits-per-cell:
1. 3 = TLC
2. 2 = MLC
3. 1 = SLC                                                                                                

## Check Battery Cycle Count

Root > N61AP > AppleARMPE > charger > AppleARMPMUCharger

Scroll to CycleCount.


Do not use for App submissions. You will be rejected.
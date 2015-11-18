CosyVerif
=========

![Build Status](https://img.shields.io/travis/CosyVerif/library.svg)
![Build Status](https://img.shields.io/shippable/561523fc1895ca44741ab91e.svg)

This library is at the core of the [CosyVerif](http://cosyverif.org)
platform. It allows to represent the data, interact with them, and interact
with the platform.

Install
-------

CosyVerif client can be installed from any CosyVerif server, using:

````bash
    curl -s http://<cosy-server>/setup | bash -s /dev/stdin --prefix=<target-directory>
or
    wget -q -O - http://<cosy-server>/setup | bash -s /dev/stdin --prefix=<target-directory>
````

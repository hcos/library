CosyVerif
=========

This library is at the core of the [CosyVerif](http://cosyverif.org)
platform. It allows to represent the data, interact with them, and interact
with the platform.

Install
-------

CosyVerif can currently be installed on a Debian system easily:

````bash
    curl -s https://raw.githubusercontent.com/CosyVerif/library/master/bin/install | bash -s ${HOME}/cosyverif
````

Note that installation still requires `sudo` privileges, as it needs
to install some dependencies.

Then, run the server:

````bash
  ${HOME}/cosyverif/bin/cosy server:start
  ${HOME}/cosyverif/bin/cosy --help
````


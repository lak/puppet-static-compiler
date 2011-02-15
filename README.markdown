New Puppet Compiler
===================
This is a prototype project to create a new kind of compiler for Puppet.  There are a few goals with this:

* Support off-line file serving
* Dramatically simplify and speed up fileserving

These will both be accomplished via post-compile processing, by finding all files with sources included and updating the files on the spot to include metadata, including owner, mode, and checksums.

This requires my Interfaces module:

https://github.com/lak/puppet-interfaces

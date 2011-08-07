Puppet Static Compiler
======================
**Note: This has been merged into Puppet core, so this repo is no longer maintained, although it should work fine with 2.6.x.**

This is a prototype project to create a new kind of compiler for Puppet - one
that produces catalogs that are entirely static and require no communication
between client and server during the catalog runs.  There are a few goals with
this:

* Support off-line file serving
* Dramatically simplify and speed up fileserving

These will both be accomplished via post-compile processing, by finding all
files with sources included and updating the files on the spot to include
metadata, including owner, mode, and checksums.

This requires my Interfaces module:

https://github.com/lak/puppet-interfaces

You also have to running on 2.6.5 or one of its release candidates.

Usage
-----

Use is pretty straightforward:

Make sure both this and the interfaces module are in your RUBYLIB search path

  # Create a test manifest that includes at least one file that does remote file serving
  # It should obviously point to a file for which serving works
  $ echo 'file { "/tmp/bar": source => "puppet:///modules/mymod/myfile" }' > /tmp/test.pp

  # Start the master with the new compiler terminus:
  $ ~/puppet/bin/puppet master --catalog_terminus=static_compiler --config=/Users/luke/.puppet/puppet.conf --manifest /tmp/test.pp

  # Download catalog
  $ puppet catalog --bucketdir /tmp/buckets --verbose download localhost

  # And check the local filebucket
  $ find /tmp/buckets

Now look in the catalog and notice that instead of it having a URL for the file in it, it
has the file checksum, mode, owner, and group specified in it.

It also has downloaded all of the needed files into the local file bucket.  It did this via the server
filebucket - both the server and client now have a copy of all needed files in their filebuckets.

You can use this plugin to create completely static catalogs, which can then be pushed
to clients to be run locally.

Problems
---------
* Files are all read into memory rather than streamed. This will definitely cause problems with large files, but the filebucket doesn't currently handle streaming.
* We test the local filebucket before downlaoding new files into it, to make sure the file doesn't already exist, but our test actually reads the whole file in.  This is again because of the limitations of the filebucket API.
* I think the recursion behavior is equivalent, but I can't really guarantee it without a good bit of testing.
* If you don't use the 'puppet catalog download' action to retrieve your catalog, then the local filebucket won't have the needed files.  This means you need to point the client at the server filebucket, or download them via some other means.
* Behavior on the server is currently undefined if your puppet masters are behind a load balancer and they're configured to do fileserving through that load balancer.  It should work, but it probably won't be that fast.

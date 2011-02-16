Puppet Static Compiler
======================
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

Use is pretty straightforward:

Make sure both this and the interfaces module are in your RUBYLIB search path

  # Create a test manifest that includes at least one file that does remote file serving
  # It should obviously point to a file for which serving works
  $ echo 'file { "/tmp/bar": source => "puppet:///modules/mymod/myfile" }' > /tmp/test.pp

  # Start the master with the new compiler terminus:
  $ ~/puppet/bin/puppet master --catalog_terminus=newcompiler --config=/Users/luke/.puppet/puppet.conf --manifest /tmp/test.pp

  # Try to download catalog
  $ puppet catalog --bucketdir /tmp/buckets --verbose download localhost

  # Notice the failure
  # Now download the file to the server's filebucket
  $ puppet file --verbose download puppet:///modules/mymod/myfile

  # And download the catalog again
  $ puppet catalog --bucketdir /tmp/buckets --verbose download localhost

  # And check the local filebucket
  $ find /tmp/buckets

Now look in the catalog and notice that instead of it having a URL for the file in it, it
has the file checksum, mode, owner, and group specified in it.

It also has downloaded all of the needed files into the local file bucket.

You can use this plugin to create completely static catalogs, which can then be pushed
to clients to be run locally.

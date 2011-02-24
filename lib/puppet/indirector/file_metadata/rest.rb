# -*- coding: utf-8 -*-
require 'puppet/file_serving/metadata'
require 'puppet/indirector/file_metadata'
require 'puppet/indirector/rest'

require 'dalli'

class Puppet::Indirector::FileMetadata::Rest < Puppet::Indirector::REST
  desc "Retrieve file metadata via a REST HTTP interface."

  def memcache
    # Compression in this client only hits when the value is 1K or larger, at
    # which point it is probably a win for cache efficiency.  Reconsider this
    # assumption if you use another client.
    #
    # Supply a default TTL for the data of an hour, plus a tiny bit, which
    # should give a good efficiency vs "recover from strangeness" trade-off.
    # Tune for your site, obviously, though the defaults should be
    # sufficiently good...
    @memcache ||= Dalli::Client.new('localhost:11211',
                                    :compression => true,
                                    :expires_in  => 62 * 60)
  end

  def memcache_key(request)
    # We do our own namespacing, because we know more than the memcache client
    # does about the different types of input we might have.
    "puppet@#{request.indirection_name}@#{request.uri}"
  end

  def memcache_get(request)
    key    = memcache_key(request)
    result = memcache.get(key)

    if result then
      # We should probably assert the right document type, not just a known
      # one.  Oh, well, this will do...
      envelope = PSON.parse(result)
      if decoder = PSON.registered_document_types[envelope['document_type']] then
        return decoder.from_pson(envelope['data'])
      end
    end

    # Couldn't decode it, or whatever.  We got here, so we want to get it,
    # encode it, and store it before we return.
    value = yield
    store = value.to_pson
    # key, value, TTL, options – raw means "don't mashall", which given that
    # has a habit of both changing between versions, and corrupting random
    # memory on invalid input, isn't really safe to use here.
    memcache.set(key, value.to_pson, nil, :raw => true)

    # Return that value, then.
    value
  end

  def find(request)
    # This is a cheap way around otherwise needing to patch the code; the
    # original is actually an empty class, so we are pretty much safe down
    # here doing this.
    if Puppet.settings[:run_mode] == "master" then
      memcache_get(request) do
        super(request)
      end
    else
      super(request)
    end
  end
end

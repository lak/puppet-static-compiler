# -*- coding: utf-8 -*-
require 'puppet/file_serving/metadata'
require 'puppet/indirector/file_metadata'
require 'puppet/indirector/rest'

require 'dalli'

class Puppet::Indirector::FileMetadata::Rest < Puppet::Indirector::REST
  desc "Retrieve file metadata via a REST HTTP interface."

  # REVISIT: We should wrap this in an object, since we want to override the
  # default serialization behaviour, and support more than one MemCache Ruby
  # gem interface to make life easier for our users.  Having an object of our
  # own makes it easier to do that cleanly.
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

  def memcache_invalidate
    # Incrument the generation counter, and "delete" all the older keys.  This
    # hits all servers simultaneously, more or less, but is vulnerable to the
    # same race the current file serving code is.
    memcache.incr("puppet@file_metadata@generation")
  end

  def memcache_key(request)
    # We do our own namespacing, because we know more than the memcache
    # client does about the different types of input we might have.
    namespace = "puppet@#{request.indirection_name}"
    generation = memcache.fetch("#{namespace}@generation") do 1 end
    "#{namespace}@#{generation}@#{request.uri}"
  end

  def memcached(request)
    begin
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
    rescue => e
      Puppet.notice("memcache fetch failed for #{key}: #{e}")
      result = nil
    end

    # Memcche was down, we couldn't decode the data, or whatever.  We got
    # here, so we want to get it, encode it, and store it before we return.
    value = yield

    begin
      # key, value, TTL, options – raw means "don't mashall", which given that
      # has a habit of both changing between versions, and corrupting random
      # memory on invalid input, isn't really safe to use.
      if key then
        Puppet.notice("cache #{key} to memcache")
        memcache.set(key, value.to_pson, nil, :raw => true)
      end
    rescue
      nil
    end

    # Return that value, then.
    value
  end

  def find(request)
    # This is a cheap way around otherwise needing to patch the code; the
    # original is actually an empty class, so we are pretty much safe down
    # here doing this.
    if Puppet.settings[:run_mode] == "master" then
      memcached(request) do
        super(request)
      end
    else
      super(request)
    end
  end
end

class RedisUtil
  HOST = 'localhost'
  CACHE_LIMIT_SECONDS = 60 * 30

  class << self
    def exists?(key)
      instance.exists(key)
    end

    def get(key)
      decode(instance.get(key))
    end

    def set(key, data, limit = CACHE_LIMIT_SECONDS)
      instance.setex(key, limit, encode(data))
    end

    private

    def encode(val)
      return nil if val.nil?
      Marshal.dump(val)
    rescue => e
      logger.warn "encode(val) #{e.inspect} #{val.inspect}"
      nil
    end

    def decode(val)
      return nil if val.nil?
      Marshal.load(val)
    rescue => e
      logger.warn "decode(val) #{e.inspect} #{val.inspect}"
      nil
    end

    def instance
      @@redis ||= Redis.new(host: HOST)
    end

    def logger
      @@logger ||= Rails.logger
    end
  end
end



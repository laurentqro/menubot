# frozen_string_literal: true

require 'json'
require 'digest'

module Menubot
  class MenuCache
    CACHE_FILE = 'data/menu_cache.json'

    def self.get(date, pdf_path)
      return nil unless File.exist?(CACHE_FILE) && File.exist?(pdf_path)

      cache = load_cache
      key = cache_key(date, pdf_path)
      cache[key]
    rescue JSON::ParserError
      nil
    end

    def self.set(date, pdf_path, menu)
      cache = load_cache
      key = cache_key(date, pdf_path)
      cache[key] = menu
      save_cache(cache)
      menu
    end

    def self.clear
      File.delete(CACHE_FILE) if File.exist?(CACHE_FILE)
    end

    def self.cache_key(date, pdf_path)
      pdf_checksum = Digest::MD5.file(pdf_path).hexdigest
      "#{pdf_checksum}_#{date.strftime('%Y-%m-%d')}"
    end

    def self.load_cache
      return {} unless File.exist?(CACHE_FILE)

      JSON.parse(File.read(CACHE_FILE))
    rescue JSON::ParserError
      {}
    end

    def self.save_cache(cache)
      File.write(CACHE_FILE, JSON.pretty_generate(cache))
    end

    private_class_method :cache_key, :load_cache, :save_cache
  end
end

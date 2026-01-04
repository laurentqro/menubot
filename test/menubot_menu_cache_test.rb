# frozen_string_literal: true

require_relative "test_helper"
require "tempfile"
require "json"

class MenubotMenuCacheTest < Minitest::Test
  def setup
    @original_cache_file = Menubot::MenuCache::CACHE_FILE
    @temp_cache = Tempfile.new(["menu_cache", ".json"])
    @temp_cache_path = @temp_cache.path
    @temp_cache.close

    @temp_pdf = Tempfile.new(["test_menu", ".pdf"])
    @temp_pdf.write("fake pdf content")
    @temp_pdf.close
    @pdf_path = @temp_pdf.path

    # Monkey-patch the constant for testing
    Menubot::MenuCache.send(:remove_const, :CACHE_FILE) if Menubot::MenuCache.const_defined?(:CACHE_FILE)
    Menubot::MenuCache.const_set(:CACHE_FILE, @temp_cache_path)
  end

  def teardown
    # Restore original constant
    Menubot::MenuCache.send(:remove_const, :CACHE_FILE)
    Menubot::MenuCache.const_set(:CACHE_FILE, @original_cache_file)

    # Clean up temp files
    File.delete(@temp_cache_path) if File.exist?(@temp_cache_path)
    File.delete(@pdf_path) if File.exist?(@pdf_path)
  end

  def test_get_returns_nil_when_no_cache_file
    File.delete(@temp_cache_path) if File.exist?(@temp_cache_path)
    assert_nil Menubot::MenuCache.get(Date.today, @pdf_path)
  end

  def test_get_returns_nil_when_pdf_missing
    File.delete(@pdf_path)
    assert_nil Menubot::MenuCache.get(Date.today, @pdf_path)
  end

  def test_get_returns_nil_when_not_cached
    File.write(@temp_cache_path, JSON.generate({}))
    assert_nil Menubot::MenuCache.get(Date.today, @pdf_path)
  end

  def test_set_and_get_roundtrip
    date = Date.new(2025, 12, 5)
    menu = "🥗 ENTRÉE\nCarottes râpées"

    Menubot::MenuCache.set(date, @pdf_path, menu)
    cached = Menubot::MenuCache.get(date, @pdf_path)

    assert_equal menu, cached
  end

  def test_cache_invalidated_when_pdf_changes
    date = Date.new(2025, 12, 5)
    menu = "🥗 ENTRÉE\nCarottes râpées"

    Menubot::MenuCache.set(date, @pdf_path, menu)

    # Modify the PDF content
    File.write(@pdf_path, "different pdf content")

    # Cache should miss because PDF checksum changed
    assert_nil Menubot::MenuCache.get(date, @pdf_path)
  end

  def test_different_dates_cached_separately
    date1 = Date.new(2025, 12, 5)
    date2 = Date.new(2025, 12, 6)
    menu1 = "🥗 ENTRÉE\nCarottes râpées"
    menu2 = "🥗 ENTRÉE\nSalade verte"

    Menubot::MenuCache.set(date1, @pdf_path, menu1)
    Menubot::MenuCache.set(date2, @pdf_path, menu2)

    assert_equal menu1, Menubot::MenuCache.get(date1, @pdf_path)
    assert_equal menu2, Menubot::MenuCache.get(date2, @pdf_path)
  end

  def test_clear_removes_cache_file
    Menubot::MenuCache.set(Date.today, @pdf_path, "menu")
    assert File.exist?(@temp_cache_path)

    Menubot::MenuCache.clear
    refute File.exist?(@temp_cache_path)
  end

  def test_get_handles_invalid_json
    File.write(@temp_cache_path, "not valid json {{{")
    assert_nil Menubot::MenuCache.get(Date.today, @pdf_path)
  end

  def test_set_overwrites_existing_entry
    date = Date.new(2025, 12, 5)
    menu1 = "First menu"
    menu2 = "Updated menu"

    Menubot::MenuCache.set(date, @pdf_path, menu1)
    Menubot::MenuCache.set(date, @pdf_path, menu2)

    assert_equal menu2, Menubot::MenuCache.get(date, @pdf_path)
  end
end

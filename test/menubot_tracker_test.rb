# frozen_string_literal: true

require_relative "test_helper"
require "tempfile"
require "json"

class MenubotTrackerTest < Minitest::Test
  def setup
    @original_tracking_file = Menubot::Tracker::TRACKING_FILE
    @temp_file = Tempfile.new(["tracking", ".json"])
    @temp_path = @temp_file.path
    @temp_file.close

    # Monkey-patch the constant for testing
    Menubot::Tracker.send(:remove_const, :TRACKING_FILE) if Menubot::Tracker.const_defined?(:TRACKING_FILE)
    Menubot::Tracker.const_set(:TRACKING_FILE, @temp_path)
  end

  def teardown
    # Restore original constant
    Menubot::Tracker.send(:remove_const, :TRACKING_FILE)
    Menubot::Tracker.const_set(:TRACKING_FILE, @original_tracking_file)

    # Clean up temp file
    File.delete(@temp_path) if File.exist?(@temp_path)
  end

  def test_already_run_today_returns_false_when_no_file
    File.delete(@temp_path) if File.exist?(@temp_path)
    refute Menubot::Tracker.already_run_today?
  end

  def test_already_run_today_returns_true_when_ran_today
    File.write(@temp_path, JSON.generate({ "last_run" => Date.today.to_s }))
    assert Menubot::Tracker.already_run_today?
  end

  def test_already_run_today_returns_false_when_ran_yesterday
    yesterday = (Date.today - 1).to_s
    File.write(@temp_path, JSON.generate({ "last_run" => yesterday }))
    refute Menubot::Tracker.already_run_today?
  end

  def test_already_run_today_returns_false_on_invalid_json
    File.write(@temp_path, "not valid json {{{")
    refute Menubot::Tracker.already_run_today?
  end

  def test_already_run_today_returns_false_on_empty_file
    File.write(@temp_path, "")
    refute Menubot::Tracker.already_run_today?
  end

  def test_mark_run_creates_file_with_today
    File.delete(@temp_path) if File.exist?(@temp_path)
    Menubot::Tracker.mark_run

    assert File.exist?(@temp_path)
    data = JSON.parse(File.read(@temp_path))
    assert_equal Date.today.to_s, data["last_run"]
  end

  def test_mark_run_overwrites_previous_run
    yesterday = (Date.today - 1).to_s
    File.write(@temp_path, JSON.generate({ "last_run" => yesterday }))

    Menubot::Tracker.mark_run

    data = JSON.parse(File.read(@temp_path))
    assert_equal Date.today.to_s, data["last_run"]
  end
end

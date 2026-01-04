# frozen_string_literal: true

require_relative "test_helper"

class MenubotRunTest < Minitest::Test
  def test_run_raises_when_already_run_today
    Menubot::Tracker.stub :already_run_today?, true do
      error = assert_raises(Menubot::Error) { Menubot.run }
      assert_match(/already run today/, error.message)
    end
  end

  def test_run_raises_when_nursery_closed_on_weekend
    Menubot::Tracker.stub :already_run_today?, false do
      Date.stub :today, Date.new(2026, 1, 10) do # Saturday
        error = assert_raises(Menubot::Error) { Menubot.run }
        assert_match(/closed today/, error.message)
      end
    end
  end

  def test_run_raises_when_nursery_closed_on_holiday
    Menubot::Tracker.stub :already_run_today?, false do
      Date.stub :today, Date.new(2026, 5, 1) do # Labor Day (Friday)
        error = assert_raises(Menubot::Error) { Menubot.run }
        assert_match(/closed today/, error.message)
      end
    end
  end
end

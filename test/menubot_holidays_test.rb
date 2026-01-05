# frozen_string_literal: true

require_relative "test_helper"

class MenubotHolidaysTest < Minitest::Test
  def test_holidays_returns_array
    assert_kind_of Array, Menubot::Config.holidays
  end

  def test_holidays_includes_christmas_break
    holidays = Menubot::Config.holidays
    assert_includes holidays, "25 décembre"
    assert_includes holidays, "4 janvier"
  end

  def test_holidays_includes_winter_break
    holidays = Menubot::Config.holidays
    assert_includes holidays, "13 février"
    assert_includes holidays, "28 février"
  end

  def test_holidays_includes_easter_monday
    assert_includes Menubot::Config.holidays, "6 avril"
  end

  def test_holidays_includes_spring_break
    holidays = Menubot::Config.holidays
    assert_includes holidays, "10 avril"
    assert_includes holidays, "26 avril"
  end

  def test_holidays_includes_labor_day
    assert_includes Menubot::Config.holidays, "1 mai"
  end

  def test_holidays_includes_corpus_christi_and_f1
    holidays = Menubot::Config.holidays
    assert_includes holidays, "3 juin"
    assert_includes holidays, "7 juin"
  end

  def test_holiday_returns_true_for_christmas
    Date.stub :today, Date.new(2025, 12, 25) do
      assert Menubot.holiday?
    end
  end

  def test_holiday_returns_true_for_labor_day
    Date.stub :today, Date.new(2026, 5, 1) do
      assert Menubot.holiday?
    end
  end

  def test_holiday_returns_false_for_regular_day
    Date.stub :today, Date.new(2026, 3, 10) do
      refute Menubot.holiday?
    end
  end

  def test_weekend_returns_true_for_saturday
    Date.stub :today, Date.new(2026, 1, 10) do # Saturday
      assert Menubot.weekend?
    end
  end

  def test_weekend_returns_true_for_sunday
    Date.stub :today, Date.new(2026, 1, 11) do # Sunday
      assert Menubot.weekend?
    end
  end

  def test_weekend_returns_false_for_weekday
    Date.stub :today, Date.new(2026, 1, 12) do # Monday
      refute Menubot.weekend?
    end
  end

  def test_nursery_closed_on_holiday
    Date.stub :today, Date.new(2026, 5, 1) do # Labor Day (Friday)
      assert Menubot.nursery_closed_today?
    end
  end

  def test_nursery_closed_on_weekend
    Date.stub :today, Date.new(2026, 1, 10) do # Saturday
      assert Menubot.nursery_closed_today?
    end
  end

  def test_nursery_open_on_regular_weekday
    Date.stub :today, Date.new(2026, 3, 10) do # Tuesday
      refute Menubot.nursery_closed_today?
    end
  end
end

# frozen_string_literal: true

require_relative "test_helper"

class MenubotConfigTest < Minitest::Test
  def test_school_name
    assert_equal "Parc, Carmes et Stella", Menubot::Config.school_name
  end

  def test_school_website
    assert_equal "https://ecole-carmes.gouv.mc", Menubot::Config.school_website
  end

  def test_school_menu_path
    assert_equal "/vie-de-l-etablissement/menus-du-restaurant-scolaire", Menubot::Config.school_menu_path
  end

  def test_menu_page_url
    expected = "https://ecole-carmes.gouv.mc/vie-de-l-etablissement/menus-du-restaurant-scolaire"
    assert_equal expected, Menubot::Config.menu_page_url
  end

  def test_email_subject_template
    assert_includes Menubot::Config.email_subject_template, "%{date}"
    assert_includes Menubot::Config.email_subject_template, "%{school_name}"
  end

  def test_not_available_message
    message = Menubot::Config.not_available_message
    assert_includes message, "menu"
    assert_includes message, "disponible"
  end

  def test_llm_model
    assert_match(/claude/, Menubot::Config.llm_model)
  end

  def test_mailgun_region
    assert_equal "api.eu.mailgun.net", Menubot::Config.mailgun_region
  end

  def test_menu_pdf_path
    assert_equal "data/menus.pdf", Menubot::Config.menu_pdf_path
  end

  def test_holidays_is_array
    assert_kind_of Array, Menubot::Config.holidays
  end

  def test_holidays_not_empty
    refute_empty Menubot::Config.holidays
  end
end

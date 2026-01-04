# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/date'
require 'active_support/core_ext/time'
require 'date'
require "i18n"
require "mailgun-ruby"
require "ruby_llm"
require "nokogiri"
require "open-uri"

require_relative "menubot/version"
require_relative "menubot/config"
require_relative "menubot/menu_cache"
require_relative "tracker"

RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY", nil)
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
  config.default_model = Menubot::Config.llm_model
end

# Add this configuration for French locale
I18n.available_locales = [:fr]
I18n.default_locale = :fr
I18n.backend.store_translations :fr, {
  date: {
    formats: {
      long: "%A %-d %B %Y",
      short: "%-d %B"
    },
    month_names: [
      nil,
      "janvier",
      "février",
      "mars",
      "avril",
      "mai",
      "juin",
      "juillet",
      "août",
      "septembre",
      "octobre",
      "novembre",
      "décembre"
    ],
    day_names: [
      "dimanche",
      "lundi",
      "mardi",
      "mercredi",
      "jeudi",
      "vendredi",
      "samedi"]
  }
}

module Menubot
  class Error < StandardError; end

  def self.run
    raise Menubot::Error, "Menubot has already run today" if Menubot::Tracker.already_run_today?
    raise Menubot::Error, "Nursery is closed today" if Menubot.nursery_closed_today?

    fetch_latest_menu

    today = Date.today
    menu = get_menu_of_the_day(today)

    body = if menu.include?("MENU_NOT_FOUND")
             Config.not_available_message
           else
             menu
           end

    todays_date = I18n.l(today, format: :long, locale: :fr)
    subject = Config.email_subject_template % { date: todays_date, school_name: Config.school_name }

    send_email(subject: subject, body: body)

    Menubot::Tracker.mark_run
  end

  def self.preview(date: Date.today)
    fetch_latest_menu

    date_str = I18n.l(date, format: :long, locale: :fr)
    short_date = date.strftime("%d/%m")
    prompt = build_prompt(date_str, short_date)
    menu = get_menu_of_the_day(date)

    result = if menu.include?("MENU_NOT_FOUND")
               Config.not_available_message
             else
               menu
             end

    <<~OUTPUT
      === PROMPT ===
      #{prompt}
      === RESPONSE ===
      #{result}
    OUTPUT
  end

  def self.fetch_latest_menu
    doc = Nokogiri::HTML(URI.open(Config.menu_page_url))
    pdf_link = doc.css('a[href*=".pdf"]').first

    return false unless pdf_link

    pdf_url = "#{Config.school_website}#{pdf_link['href']}"
    pdf_content = URI.open(pdf_url).read

    File.binwrite(Config.menu_pdf_path, pdf_content)
    true
  rescue StandardError => e
    warn "Failed to fetch menu: #{e.message}"
    false
  end

  # private

  def self.build_prompt(date_in_words, short_date)
    <<~PROMPT
      Extrais le menu du déjeuner pour le #{date_in_words}.

      IMPORTANT: Dans ce PDF, les dates apparaissent au format JJ/MM (exemple: #{short_date}).
      Cherche la date #{short_date} dans le document.

      Si le menu pour cette date n'est pas dans le PDF, réponds exactement : "MENU_NOT_FOUND"

      Sinon, formate la réponse exactement comme suit :

      🥗 ENTRÉE
      [entrée du jour]

      🍽️ PLAT
      [plat principal]
      [accompagnement]

      🧀 FROMAGE
      [fromage ou laitage]

      🍰 DESSERT
      [dessert]
    PROMPT
  end

  def self.get_menu_of_the_day(date)
    pdf_path = Config.menu_pdf_path

    # Check cache first
    cached = MenuCache.get(date, pdf_path)
    return cached if cached

    # Extract from PDF using LLM
    date_in_words = I18n.l(date, format: :long, locale: :fr)
    short_date = date.strftime("%d/%m")
    prompt = build_prompt(date_in_words, short_date)

    chat = RubyLLM.chat.with_temperature(0.0)
    chat.with_instructions("Tu extrais le menu du jour à partir du PDF. Retourne uniquement le menu formaté ou MENU_NOT_FOUND si la date n'est pas présente.")
    response = chat.ask(prompt, with: pdf_path)
    menu = response.content

    # Cache the result (including MENU_NOT_FOUND to avoid repeated lookups)
    MenuCache.set(date, pdf_path, menu)

    menu
  end

  def self.send_email(subject:, body:)
    mailgun = Mailgun::Client.new(ENV.fetch("MAILGUN_API_KEY"), Config.mailgun_region)
    mailgun_domain = ENV.fetch("MAILGUN_DOMAIN")

    message_params = {
      from: ENV.fetch("FROM_EMAIL"),
      to: ENV.fetch("TO_EMAIL"),
      subject: subject,
      text: body
    }

    mailgun.send_message(mailgun_domain, message_params)
  end

  def self.nursery_closed_today?
    weekend? || holiday?
  end

  def self.holiday?
    Config.holidays.include?(
      I18n.l(Date.today, format: :short, locale: :fr)
    )
  end

  def self.weekend?
    Date.today.saturday? || Date.today.sunday?
  end
end

# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/date'
require 'active_support/core_ext/time'
require 'date'
require "httparty"
require "i18n"
require "mailgun-ruby"
require "openai"
require "pdf-reader"

require_relative "menubot/version"
require_relative "tracker"

# Add this configuration for French locale
I18n.available_locales = [:fr]
I18n.default_locale = :fr
I18n.backend.store_translations :fr, {
  date: {
    formats: {
      long: "%A %-d %B %Y",
      short: "%-d %B"
    },
    month_names: [nil, "janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"],
    day_names: ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
  }
}

module Menubot
  class Error < StandardError; end

  def self.run
    raise Menubot::Error, "Menubot has already run today" if Menubot::Tracker.already_run_today?  
    raise Menubot::Error, "Nursery is closed today"       if Menubot.nursery_closed_today?

    if !File.exist?("data/menus.pdf") || Menubot.first_monday_of_month?
      Menubot.fetch_menus_for_the_month
    end

    send_email(
      subject: "🍽️ Menu pour le #{todays_date}",
      body: Menubot.extract_menu_of_the_day_from_pdf("data/menus.pdf", todays_date)
    )

    Menubot::Tracker.mark_run
  end

  # private

  def self.fetch_menus_for_the_month
    response = HTTParty.get(ENV.fetch("MENU_URL"))

    raise Menubot::Error, "Failed to fetch PDF (Status: #{response.code})" unless response.success?
    raise Menubot::Error, "Response is empty" if response.body.nil? || response.body.empty?
    raise Menubot::Error, "Content-Type is not PDF" unless response.headers['content-type']&.include?('pdf')

    FileUtils.mkdir_p('data') unless Dir.exist?('data')
    File.write("data/menus.pdf", response.body)

  rescue HTTParty::Error => e
    raise Menubot::Error, "HTTP request failed: #{e.message}"
  rescue StandardError => e
    raise Menubot::Error, "Failed to save PDF: #{e.message}"
  end

  def self.extract_menu_of_the_day_from_pdf(pdf_path, date)
    reader = PDF::Reader.new(pdf_path)
    pdf_content = reader.pages.map(&:text).join("\n")

    prompt = <<~PROMPT
      Le texte ci-dessous provient d'un PDF qui inclut les menus pour chaque jour de la semaine.

      Le PDF contient une page par semaine du mois. Sur chaque page, les menus sont séparés verticalement par des en-têtes de section. Chaque colonne contient le menu pour un jour de la semaine.
      Chaque en-tête de section est le jour de la semaine, écrit en majuscules et en gras.

      Les en-têtes horizontaux sont les repas de la journée : "COLLATION DU MATIN", "DEJEUNER", "COLLATION DE L'APRES-MIDI".

      Je souhaite extraire le menu pour une date précise.

      Par exemple, si nous sommes le mercredi 3 novembre 2024, vas voir la page 1 du PDF (car c'est la semaine 1 du mois), trouve l'en-tête de section "MERCREDI" et copie le contenu du menu pour ce jour.

      La date d'aujourd'hui est "#{date}", et j'ai besoin du détail pour la collation du matin, le déjeuner et la collation de l'après-midi pour cette date.

      Merci d'illustrer chaque en-tête de section avec un emoji correspondant :

      - 🥖 pour la collation du matin
      - 🍽️ pour le déjeuner
      - 🍎 pour les collation de l'après-midi

      Merci de me donner le menu du jour, en veillant bien de séparer chaque section (collation du matin, déjeuner, collation de l'après-midi). Fournis uniquement les éléments pertinents pour le #{date}.

      #{Menubot.first_day_of_month_warning}

      Voici le contenu du PDF :

      #{pdf_content}
    PROMPT

    response = ai_client.chat(
      parameters: {
        model: "gpt-4o",
        messages: [
          { role: "system", content: "Tu es un assistant qui extrait le menu du jour à partir d'un PDF" },
          { role: "user", content: prompt },
        ],
        temperature: 0.3
      }
    )

    response.dig("choices", 0, "message", "content")
  end

  def self.ai_client
    OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
  end

  def self.send_email(subject:, body:)
    mailgun = Mailgun::Client.new(ENV.fetch("MAILGUN_API_KEY"), "api.eu.mailgun.net")
    mailgun_domain = ENV.fetch("MAILGUN_DOMAIN")

    message_params = {
      from: ENV.fetch("FROM_EMAIL"),
      to: ENV.fetch("TO_EMAIL"),
      subject: subject,
      text: body
    }

    mailgun.send_message(mailgun_domain, message_params)
  end

  def self.todays_date
    I18n.l(Date.today, format: :long, locale: :fr)
  end

  def self.nursery_closed_today?
    weekend? || holiday?
  end

  def self.holiday?
    Menubot.holidays.include?(
      I18n.l(Date.today, format: :short, locale: :fr)
    )
  end

  def self.weekend?
    Date.today.saturday? || Date.today.sunday?
  end

  def self.first_monday_of_month?(date = Date.today)
    date.monday? && date == date.beginning_of_month.next_week(:monday)
  end

  def self.holidays
    [
      "29 mars", 
      "1 mai",
      "2 mai",
      "10 mai",
      "20 mai",
      "23 mai",
      "24 mai",
      "30 mai",
      "15 août",
      "2 septembre",
      "3 septembre",
      "1 novembre",
      "19 novembre",
      "9 décembre",
      "23 décembre",
      "24 décembre",
      "25 décembre",
      "26 décembre",
      "27 décembre",
      "28 décembre",
      "29 décembre",
      "30 décembre",
      "31 décembre",
      "1 janvier",
      "2 janvier",
      "3 janvier",
      "4 janvier",
      "5 janvier"
    ]
  end

  def self.first_day_of_month_warning
    "Attention, nous sommes le premier jour du mois. Le menu du jour se trouve sur la premiere page."
  end

  def self.first_day_of_month?
    Date.today == Date.today.beginning_of_month
  end
end

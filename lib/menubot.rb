# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/date'
require 'active_support/core_ext/time'
require 'date'
require "i18n"
require "mailgun-ruby"
require "ruby_llm"

require_relative "menubot/version"
require_relative "tracker"

RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY", nil)
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
  config.default_model = "claude-3-7-sonnet"
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
    raise Menubot::Error, "Nursery is closed today"       if Menubot.nursery_closed_today?

    todays_date = I18n.l(Date.today, format: :long, locale: :fr)

    send_email(
      subject: "🍽️ Menu pour le #{todays_date}",
      body: Menubot.get_menu_of_the_day(todays_date)
    )

    Menubot::Tracker.mark_run
  end

  # private

  def self.get_menu_of_the_day(date_in_words)
    prompt = <<~PROMPT
      Le texte ci-joint provient d'un PDF qui inclut les menus pour chaque jour de la semaine.

      Le PDF contient une page par semaine du mois. Sur chaque page, les menus sont séparés verticalement par des en-têtes de section. Chaque colonne contient le menu pour un jour de la semaine.
      Chaque en-tête de section est le jour de la semaine, écrit en majuscules et en gras.

      Les en-têtes horizontaux sont les repas de la journée : "COLLATION DU MATIN", "DEJEUNER", "COLLATION DE L'APRES-MIDI".

      Je souhaite extraire le menu pour une date précise.

      Par exemple, si nous sommes le mercredi 3 novembre 2024, vas voir la page 1 du PDF (car c'est la semaine 1 du mois), trouve l'en-tête de section "MERCREDI" et copie le contenu du menu pour ce jour.

      La date d'aujourd'hui est "#{date_in_words}", et j'ai besoin du détail pour la collation du matin, le déjeuner et la collation de l'après-midi pour cette date.

      Merci d'illustrer chaque en-tête de section avec un emoji correspondant :

      - 🥖 pour la collation du matin
      - 🍽️ pour le déjeuner
      - 🍎 pour les collation de l'après-midi

      Merci de me donner le menu du jour, en veillant bien de séparer chaque section (collation du matin, déjeuner, collation de l'après-midi). Fournis uniquement les éléments pertinents pour le #{date_in_words}.
    PROMPT

    chat = RubyLLM.chat.with_temperature(0.0)
    chat.with_instructions("Tu es un assistant qui extrait le menu du jour à partir d'un PDF. Ne réponds pas à la question, juste retourne le menu. Formatte le menu en texte, pas en markdown.")
    response = chat.ask(prompt, with: { pdf: "data/menus.pdf" })
    response.content
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
      "1 mai",
      "22 mai",
      "23 mai",
      "29 mai",
      "9 juin",
      "19 juin",
      "20 juin",
      "15 août"
    ]
  end
end
  def self.first_day_of_month_warning
    "Attention, nous sommes le premier jour du mois. Le menu du jour se trouve sur la premiere page."
  end

  def self.first_day_of_month?
    Date.today == Date.today.beginning_of_month
  end
end

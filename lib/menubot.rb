# frozen_string_literal: true

require_relative "menubot/version"
require "i18n"
require "pdf-reader"
require "openai"
require "mailgun-ruby"

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

  def self.closed_days
    [
      "29 mars", 
      "1 avril", 
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

  def self.extract_menu_of_the_day_from_pdf(pdf_path, date)
    reader = PDF::Reader.new(pdf_path)
    pdf_content = reader.pages.map(&:text).join("\n")

    prompt = <<~PROMPT
      Le texte ci-dessous provient d'un PDF qui inclut les menus pour chaque jour de la semaine. Je souhaite extraire le menu pour une date précise. La date d’aujourd’hui est "#{date}", et j’ai besoin du détail pour la collation du matin, le déjeuner et la collation de l'après-midi pour cette date. Merci d'illustrer chaque en-tête de section avec un emoji correspondant :
      - 🥖 pour la collation du matin
      - 🍽️ pour le déjeuner
      - 🍎 pour les collation de l'après-midi

      Merci de séparer chaque section (collation du matin, déjeuner, collation de l'après-midi) et de fournir uniquement les éléments pertinents pour le #{date}.

      Voici le contenu du PDF :

      #{pdf_content}
    PROMPT

    response = client.chat(
      parameters: {
        model: "gpt-4o",
        messages: [
          { role: "system", content: "Tu es un assistant qui extrait le menu du jour à partir d'un PDF" },
          { role: "user", content: prompt },
        ],
        temperature: 0.5
      }
    )

    response.dig("choices", 0, "message", "content")
  end
end

def client
  OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
end

def todays_date
  I18n.l(Date.today + 2, format: :long, locale: :fr)
end

def send_email(subject:, body:)
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

def nursery_closed_today?
  Menubot.closed_days.include?(
    I18n.l(Date.today, format: :short, locale: :fr)
  )
end

return if nursery_closed_today?

send_email(
  subject: "🍽️ Menu pour le #{todays_date}",
  body: Menubot.extract_menu_of_the_day_from_pdf("lib/menus.pdf", todays_date)
)

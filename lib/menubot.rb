# frozen_string_literal: true

require_relative "menubot/version"
require "i18n"
require "pdf-reader"
require "openai"
require "dotenv/load"

# Add this configuration for French locale
I18n.available_locales = [:fr]
I18n.default_locale = :fr
I18n.backend.store_translations :fr, {
  date: {
    formats: {
      long: "%A %-d %B %Y"
    },
    month_names: [nil, "janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"],
    day_names: ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
  }
}

module Menubot
  class Error < StandardError; end

  def self.extract_menu_of_the_day_from_pdf(pdf_path, date)
    reader = PDF::Reader.new(pdf_path)
    pdf_content = reader.pages.map(&:text).join("\n")

    prompt = <<~PROMPT
      Le texte ci-dessous provient d'un PDF qui inclut les menus pour chaque jour de la semaine. Je souhaite extraire le menu pour une date précise. La date d’aujourd’hui est "#{date}", et j’ai besoin du détail pour le petit-déjeuner, le déjeuner et les collations listées pour cette date. Merci d’illustrer chaque en-tête de section avec un emoji correspondant :
      - 🥐 pour le **petit-déjeuner**
      - 🍽️ pour le **déjeuner**
      - 🍎 pour les **collations**

      Merci de séparer chaque section (petit-déjeuner, déjeuner, collations) et de fournir uniquement les éléments pertinents pour le #{date}. Voici le contenu du PDF :

      #{pdf_content}
    PROMPT

    response = client.chat(
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
end

def client
  OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
end

def todays_date
  I18n.l(Date.today, format: :long, locale: :fr)
end

def tomorrows_date
  I18n.l(Date.today + 1, format: :long, locale: :fr)
end

puts Menubot.extract_menu_of_the_day_from_pdf("spec/fixtures/menus.pdf", tomorrows_date)
# frozen_string_literal: true

require "yaml"

module Menubot
  class Config
    class << self
      def load(path = "config.yml")
        @config = YAML.load_file(path)
      end

      def config
        @config ||= load
      end

      def school_name
        config.dig("school", "name")
      end

      def school_website
        config.dig("school", "website")
      end

      def school_menu_path
        config.dig("school", "menu_path")
      end

      def menu_page_url
        "#{school_website}#{school_menu_path}"
      end

      def email_subject_template
        config.dig("email", "subject_template")
      end

      def not_available_message
        config.dig("email", "not_available_message")
      end

      def llm_model
        config.dig("llm", "model")
      end

      def mailgun_region
        config.dig("mailgun", "region")
      end

      def menu_pdf_path
        config.dig("paths", "menu_pdf")
      end

      def holidays
        config["holidays"] || []
      end
    end
  end
end

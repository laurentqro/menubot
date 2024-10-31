require 'json'
require 'date'

module Menubot
  class Tracker
    TRACKING_FILE = 'data/last_run.json'

    def self.already_run_today?
      return false unless File.exist?(TRACKING_FILE)
      
      data = JSON.parse(File.read(TRACKING_FILE))
      last_run = Date.parse(data['last_run'])
      last_run == Date.today
    rescue JSON::ParserError
      false
    end

    def self.mark_run
      File.write(TRACKING_FILE, JSON.pretty_generate({ 'last_run' => Date.today.to_s }))
    end
  end
end
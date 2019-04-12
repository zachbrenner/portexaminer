require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Portexaminer
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true
    config.active_job.queue_adapter = :sidekiq
    config.i18n.default_locale = :en
    config.i18n.available_locales = [:en]
    config.i18n.enforce_available_locales = true
    require 'i18n/backend/fallbacks'
    I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
    I18n.fallbacks[:en] = [:en, :ja, :'zh-CN']
    I18n.fallbacks[:ja] = [:ja, :en, :'zh-CN']
    I18n.fallbacks[:'zh-CN'] = [:'zh-CN', :ja, :en]
  end
end

module I18n
  module JS
    def self.translations
     ::I18n::Backend::Simple.new.instance_eval do
        init_translations unless initialized?
        Private::HashWithSymbolKeys.new(translations)
                                   .slice(*::I18n.available_locales)
                                   .to_h
      end
    end
  end
end

    
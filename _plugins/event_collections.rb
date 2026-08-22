# frozen_string_literal: true

require "date"
require "thread"
require "jekyll"
require "tzinfo"

module FGEA
  module EventDates
    ISO_DATE = /\A\d{4}-\d{2}-\d{2}\z/
    TZ_MUTEX = Mutex.new

    module_function

    def parse(value, field, document)
      unless value.is_a?(String) && ISO_DATE.match?(value)
        raise Jekyll::Errors::FatalException,
              "#{document.relative_path}: #{field} must be a quoted ISO date (YYYY-MM-DD)"
      end

      parsed = Date.iso8601(value)
      raise Date::Error unless parsed.iso8601 == value

      parsed
    rescue Date::Error
      raise Jekyll::Errors::FatalException,
            "#{document.relative_path}: #{field} is not a valid calendar date"
    end

    def today
      override = ENV["FGEA_TODAY"]
      return Date.iso8601(override) if override

      TZ_MUTEX.synchronize do
        previous = ENV["TZ"]
        ENV["TZ"] = "Australia/Sydney"
        Date.today
      ensure
        ENV["TZ"] = previous
      end
    rescue Date::Error
      raise Jekyll::Errors::FatalException,
            "FGEA_TODAY must be an ISO date (YYYY-MM-DD)"
    end
  end

  class ActivityGenerator < Jekyll::Generator
    safe true
    priority :lowest

    def generate(site)
      events = published(site.collections.fetch("events").docs)
      resources = published(site.collections.fetch("resources").docs)
      posts = published(site.posts.docs)
      (events + resources + posts).each do |document|
        document.data["description"] ||= document.data["summary"]
      end
      dated_events = events.map { |event| normalize_event(event) }
      today = EventDates.today

      site.config["upcoming_events"] = dated_events
        .select { |event, finish| finish >= today && event.data["event_status"] != "cancelled" }
        .sort_by { |event, _finish| event_sort_key(event) }
        .map(&:first)

      past = dated_events
        .select { |_event, finish| finish < today }
        .sort_by { |event, _finish| event_sort_key(event).map { |part| invert(part) } }
        .map(&:first)
      site.config["past_events"] = past

      linked_event_ids = posts
        .filter_map { |post| post.data["event_id"] }
        .to_h { |event_id| [event_id, true] }

      event_activity = past.reject { |event| linked_event_ids[event.data["event_id"]] }
      site.config["recent_activity"] = (posts + event_activity).sort_by do |document|
        [-activity_date(document).jd, activity_type(document), stable_key(document)]
      end
    end

    private

    def published(documents)
      documents.select { |document| document.data["published"] == true }
    end

    def normalize_event(event)
      start_date = EventDates.parse(event.data["start_date"], "start_date", event)
      end_date = event.data["end_date"] ?
        EventDates.parse(event.data["end_date"], "end_date", event) : start_date
      timezone = event.data.fetch("timezone", "Australia/Sydney")
      if end_date < start_date
        raise Jekyll::Errors::FatalException,
              "#{event.relative_path}: end_date cannot precede start_date"
      end

      event.data["start_date"] = local_midnight(start_date, timezone)
      event.data["end_date"] = local_midnight(end_date, timezone) if event.data.key?("end_date")
      event.data["start_iso"] = event_timestamp(start_date, event.data["start_time"], timezone)
      if event.data["end_time"]
        event.data["end_iso"] = event_timestamp(end_date, event.data["end_time"], timezone)
      elsif event.data.key?("end_date")
        event.data["end_iso"] = end_date.iso8601
      end
      [event, end_date]
    rescue TZInfo::InvalidTimezoneIdentifier, TZInfo::PeriodNotFound, TZInfo::AmbiguousTime => error
      raise Jekyll::Errors::FatalException,
            "#{event.relative_path}: invalid local event time (#{error.message})"
    end

    def event_sort_key(event)
      [
        date_value(event.data["start_date"]).jd,
        date_value(event.data.fetch("end_date", event.data["start_date"])).jd,
        event.data["event_id"].to_s,
        stable_key(event)
      ]
    end

    def activity_date(document)
      if document.collection.label == "events"
        date_value(document.data.fetch("end_date", document.data["start_date"]))
      else
        value = document.data["date"]
        value.respond_to?(:to_date) ? value.to_date : Date.parse(value.to_s)
      end
    end

    def activity_type(document)
      document.collection.label == "posts" ? 0 : 1
    end

    def stable_key(document)
      document.respond_to?(:relative_path) ? document.relative_path.to_s : document.path.to_s
    end

    def invert(value)
      value.is_a?(Integer) ? -value : value
    end

    def local_midnight(date, timezone)
      TZInfo::Timezone.get(timezone).local_time(date.year, date.month, date.day)
    end

    def event_timestamp(date, time, timezone)
      return date.iso8601 unless time

      hour, minute = time.split(":").map(&:to_i)
      TZInfo::Timezone.get(timezone)
        .local_time(date.year, date.month, date.day, hour, minute)
        .iso8601
    end

    def date_value(value)
      value.respond_to?(:to_date) ? value.to_date : Date.iso8601(value.to_s)
    end
  end
end

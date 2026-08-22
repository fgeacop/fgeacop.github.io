#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "pathname"
require "psych"
require "time"
require "tzinfo"
require "uri"

ROOT = Pathname.new(__dir__).parent.expand_path
POST_KINDS = %w[announcement recap article update].freeze
EVENT_FORMATS = %w[online in-person hybrid].freeze
EVENT_STATUSES = %w[confirmed tentative postponed cancelled].freeze
RESOURCE_TYPES = %w[report guide tool recording presentation article other].freeze
ID_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
ISO_DATE = /\A\d{4}-\d{2}-\d{2}\z/
TIME_OF_DAY = /\A(?:[01]\d|2[0-3]):[0-5]\d\z/

errors = []
documents = Hash.new { |hash, key| hash[key] = [] }

def front_matter(path, errors)
  content = path.read
  unless content.start_with?("---\n") || content.start_with?("---\r\n")
    errors << "#{path.relative_path_from(ROOT)}: missing YAML front matter"
    return {}
  end

  yaml = content.split(/^---\s*$\r?\n?/, 3)[1]
  data = Psych.safe_load(yaml, permitted_classes: [Date, Time], aliases: true)
  unless data.is_a?(Hash)
    errors << "#{path.relative_path_from(ROOT)}: front matter must be a mapping"
    return {}
  end
  data.transform_keys(&:to_s)
rescue Psych::Exception => e
  errors << "#{path.relative_path_from(ROOT)}: invalid YAML (#{e.message.lines.first.strip})"
  {}
end

def require_fields(path, data, fields, errors)
  fields.each do |field|
    unless data.key?(field)
      errors << "#{path}: missing required #{field}"
      next
    end
    if data[field].nil? || (data[field].is_a?(String) && data[field].strip.empty?)
      errors << "#{path}: #{field} cannot be empty"
    end
  end
end

def validate_text(path, data, fields, errors)
  fields.each do |field|
    next unless data.key?(field)
    next if data[field].is_a?(String) && !data[field].strip.empty?

    errors << "#{path}: #{field} must be a non-empty string"
  end
end

def validate_boolean(path, data, field, errors)
  return if data[field] == true || data[field] == false

  errors << "#{path}: #{field} must be true or false"
end

def validate_enum(path, value, field, allowed, errors)
  return if allowed.include?(value)

  errors << "#{path}: #{field} must be one of: #{allowed.join(', ')}"
end

def iso_date(path, value, field, errors, quoted: true)
  if quoted && !value.is_a?(String)
    errors << "#{path}: #{field} must be a quoted ISO date (YYYY-MM-DD)"
    return
  end
  text = value.to_s
  unless ISO_DATE.match?(text)
    errors << "#{path}: #{field} must use YYYY-MM-DD"
    return
  end
  parsed = Date.iso8601(text)
  raise Date::Error unless parsed.iso8601 == text
  parsed
rescue Date::Error
  errors << "#{path}: #{field} is not a valid calendar date"
  nil
end

def valid_http_url?(value)
  uri = URI.parse(value.to_s)
  %w[http https].include?(uri.scheme) && !uri.host.to_s.empty?
rescue URI::InvalidURIError
  false
end

def validate_url_pair(path, data, url_field, label_field, errors)
  if data.key?(url_field) != data.key?(label_field)
    errors << "#{path}: #{url_field} and #{label_field} must be provided together"
    return
  end
  return unless data.key?(url_field)

  errors << "#{path}: #{url_field} must be an absolute HTTP(S) URL" unless valid_http_url?(data[url_field])
  unless data[label_field].is_a?(String) && !data[label_field].strip.empty?
    errors << "#{path}: #{label_field} must be a non-empty string"
  end
end

def safe_local_path?(value)
  path = value.to_s
  return false if path.empty? || path.include?("?") || path.include?("#")
  return false if path.match?(%r{\A[a-z][a-z0-9+.-]*:}i)
  return false if path.split("/").include?("..")

  ROOT.join(path.sub(%r{\A/}, "")).cleanpath.to_s.start_with?("#{ROOT}/")
end

def validate_local_file(path, value, field, errors)
  unless safe_local_path?(value)
    errors << "#{path}: #{field} must be a safe local path"
    return
  end

  target = ROOT.join(value.to_s.sub(%r{\A/}, "")).cleanpath
  errors << "#{path}: #{field} does not exist: #{value}" unless target.file?
end

def validate_image(path, data, errors)
  if data.key?("image") != data.key?("image_alt")
    errors << "#{path}: image and image_alt must be provided together"
    return
  end
  return unless data.key?("image")

  validate_local_file(path, data["image"], "image", errors)
  errors << "#{path}: image_alt must be a string" unless data["image_alt"].is_a?(String)
end

def validate_permalink(path, data, errors)
  return unless data.key?("permalink")

  permalink = data["permalink"]
  unless permalink.is_a?(String) && permalink.start_with?("/") && safe_local_path?(permalink)
    errors << "#{path}: permalink must be a root-relative safe local path"
  end
end

def validate_redirects(path, data, errors)
  return unless data.key?("redirect_from")

  redirects = data["redirect_from"]
  unless redirects.is_a?(Array) && !redirects.empty?
    errors << "#{path}: redirect_from must be a non-empty list"
    return
  end
  redirects.each do |redirect|
    unless redirect.is_a?(String) && redirect.start_with?("/") && safe_local_path?(redirect)
      errors << "#{path}: redirect_from entries must be root-relative safe local paths"
    end
  end
  errors << "#{path}: redirect_from contains duplicate paths" unless redirects.uniq.length == redirects.length
end

{
  "posts" => ROOT.join("_posts"),
  "events" => ROOT.join("_events"),
  "resources" => ROOT.join("_resources")
}.each do |type, directory|
  next unless directory.directory?

  directory.glob("**/*.{md,markdown,html}").sort.each do |file|
    documents[type] << [file, front_matter(file, errors)]
  end
end

event_ids = {}
resource_ids = {}
recap_paths = Hash.new { |hash, key| hash[key] = [] }

config_path = ROOT.join("_config.yml")
config = Psych.safe_load_file(config_path, permitted_classes: [Date, Time], aliases: true)
canonical_url = config.is_a?(Hash) ? config["url"] : nil
unless valid_http_url?(canonical_url) && URI.parse(canonical_url).scheme == "https"
  errors << "_config.yml: url must be an absolute HTTPS canonical origin"
end

documents["events"].each do |file, data|
  path = file.relative_path_from(ROOT).to_s
  require_fields(path, data, %w[layout event_id title summary start_date format event_status published], errors)
  errors << "#{path}: layout must be event" unless data["layout"] == "event"
  validate_text(path, data, %w[event_id title summary], errors)
  validate_boolean(path, data, "published", errors)
  validate_enum(path, data["format"], "format", EVENT_FORMATS, errors)
  validate_enum(path, data["event_status"], "event_status", EVENT_STATUSES, errors)
  validate_permalink(path, data, errors)
  validate_redirects(path, data, errors)
  validate_url_pair(path, data, "source", "source_label", errors)
  validate_image(path, data, errors)
  if data["registration_url"] && !valid_http_url?(data["registration_url"])
    errors << "#{path}: registration_url must be an absolute HTTP(S) URL"
  end

  event_id = data["event_id"]
  errors << "#{path}: event_id must be a lowercase hyphenated stable ID" unless ID_PATTERN.match?(event_id.to_s)
  if event_ids.key?(event_id)
    errors << "#{path}: duplicate event_id #{event_id.inspect} (also in #{event_ids[event_id]})"
  else
    event_ids[event_id] = path
  end

  start_date = iso_date(path, data["start_date"], "start_date", errors)
  end_date = data.key?("end_date") ? iso_date(path, data["end_date"], "end_date", errors) : start_date
  errors << "#{path}: end_date cannot precede start_date" if start_date && end_date && end_date < start_date

  %w[start_time end_time].each do |field|
    next unless data.key?(field)
    errors << "#{path}: #{field} must use 24-hour HH:MM" unless TIME_OF_DAY.match?(data[field].to_s)
  end
  if data.key?("end_time") && !data.key?("start_time")
    errors << "#{path}: end_time requires start_time"
  end
  if data.key?("start_time")
    unless data["timezone"].is_a?(String) && !data["timezone"].strip.empty?
      errors << "#{path}: timezone is required when a time is provided"
    else
      begin
        timezone = TZInfo::Timezone.get(data["timezone"])
        timestamp_pairs = [
          [start_date, data["start_time"]],
          [end_date, data["end_time"]]
        ]
        timestamp_pairs.each do |date, time|
          next unless date && TIME_OF_DAY.match?(time.to_s)

          hour, minute = time.split(":").map(&:to_i)
          timezone.local_time(date.year, date.month, date.day, hour, minute)
        end
      rescue TZInfo::InvalidTimezoneIdentifier
        errors << "#{path}: timezone must be a valid IANA timezone"
      rescue TZInfo::PeriodNotFound, TZInfo::AmbiguousTime => error
        errors << "#{path}: local event time is invalid or ambiguous (#{error.message})"
      end
    end
  end
  if start_date == end_date && TIME_OF_DAY.match?(data["start_time"].to_s) &&
      TIME_OF_DAY.match?(data["end_time"].to_s) && data["end_time"] <= data["start_time"]
    errors << "#{path}: end_time must be later than start_time for a single-day event"
  end
end

documents["posts"].each do |file, data|
  path = file.relative_path_from(ROOT).to_s
  require_fields(path, data, %w[layout title date summary kind published], errors)
  errors << "#{path}: layout must be post" unless data["layout"] == "post"
  validate_text(path, data, %w[title summary], errors)
  validate_boolean(path, data, "published", errors)
  validate_enum(path, data["kind"], "kind", POST_KINDS, errors)
  iso_date(path, data["date"], "date", errors)
  validate_permalink(path, data, errors)
  validate_redirects(path, data, errors)
  validate_url_pair(path, data, "source_url", "source_label", errors)
  validate_image(path, data, errors)

  if data["event_id"] && !event_ids.key?(data["event_id"])
    errors << "#{path}: event_id #{data['event_id'].inspect} does not reference an event"
  end
  if data["kind"] == "recap" && data["event_id"]
    recap_paths[data["event_id"]] << path
  end
end

recap_paths.each do |event_id, paths|
  next unless paths.length > 1

  errors << "event #{event_id.inspect}: only one recap is allowed (#{paths.join(', ')})"
end

documents["resources"].each do |file, data|
  path = file.relative_path_from(ROOT).to_s
  require_fields(
    path, data,
    %w[layout resource_id title summary resource_type published_date published],
    errors
  )
  errors << "#{path}: layout must be resource" unless data["layout"] == "resource"
  validate_text(path, data, %w[resource_id title summary], errors)
  validate_boolean(path, data, "published", errors)
  validate_enum(path, data["resource_type"], "resource_type", RESOURCE_TYPES, errors)
  iso_date(path, data["published_date"], "published_date", errors)
  validate_permalink(path, data, errors)
  validate_redirects(path, data, errors)
  validate_url_pair(path, data, "source_url", "source_label", errors)
  validate_image(path, data, errors)

  resource_id = data["resource_id"]
  errors << "#{path}: resource_id must be a lowercase hyphenated stable ID" unless ID_PATTERN.match?(resource_id.to_s)
  if resource_ids.key?(resource_id)
    errors << "#{path}: duplicate resource_id #{resource_id.inspect} (also in #{resource_ids[resource_id]})"
  else
    resource_ids[resource_id] = path
  end

  links = %w[external_url download_path].select { |field| data[field].is_a?(String) && !data[field].empty? }
  errors << "#{path}: provide exactly one of external_url or download_path" unless links.length == 1
  if data["external_url"] && !valid_http_url?(data["external_url"])
    errors << "#{path}: external_url must be an absolute HTTP(S) URL"
  end
  if data["download_path"]
    validate_local_file(path, data["download_path"], "download_path", errors)
  end
end

if errors.empty?
  count = documents.values.sum(&:length)
  puts "Content validation passed (#{count} source documents checked)."
else
  warn "Content validation failed with #{errors.length} error#{errors.length == 1 ? '' : 's'}:"
  errors.each { |error| warn "  - #{error}" }
  exit 1
end

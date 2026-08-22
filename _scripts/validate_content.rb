#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "exifr/jpeg"
require "pathname"
require "psych"
require "time"
require "tzinfo"
require "uri"

ROOT = Pathname.new(__dir__).parent.expand_path
POST_KINDS = %w[announcement recap article update].freeze
EVENT_FORMATS = %w[online in-person hybrid unspecified].freeze
EVENT_STATUSES = %w[confirmed tentative postponed cancelled].freeze
EVENT_OCCURRENCE_STATUSES = %w[occurred scheduled unconfirmed].freeze
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

def image_dimensions(path)
  case path.extname.downcase
  when ".jpg", ".jpeg"
    image = EXIFR::JPEG.new(path.to_s)
    [image.width, image.height]
  when ".png"
    header = path.binread(24)
    raise "invalid PNG signature" unless header.start_with?("\x89PNG\r\n\x1A\n".b)

    header.byteslice(16, 8).unpack("NN")
  else
    raise "unsupported image format"
  end
end

def png_chunk_types(path)
  data = path.binread
  raise "invalid PNG signature" unless data.start_with?("\x89PNG\r\n\x1A\n".b)

  chunks = []
  offset = 8
  while offset + 12 <= data.bytesize
    length = data.byteslice(offset, 4).unpack1("N")
    type = data.byteslice(offset + 4, 4)
    raise "invalid PNG chunk" unless type && offset + length + 12 <= data.bytesize

    chunks << type
    offset += length + 12
    break if type == "IEND"
  end
  chunks
end

def validate_image(path, data, errors)
  image_fields = %w[image image_alt image_width image_height]
  if image_fields.any? { |field| data.key?(field) } && !image_fields.all? { |field| data.key?(field) }
    errors << "#{path}: image, image_alt, image_width, and image_height must be provided together"
    return
  end
  return unless data.key?("image")

  validate_local_file(path, data["image"], "image", errors)
  unless data["image_alt"].is_a?(String) && !data["image_alt"].strip.empty?
    errors << "#{path}: image_alt must be a non-empty string"
  end
  %w[image_width image_height].each do |field|
    errors << "#{path}: #{field} must be a positive integer" unless data[field].is_a?(Integer) && data[field].positive?
  end
  if data.key?("image_caption") && (!data["image_caption"].is_a?(String) || data["image_caption"].strip.empty?)
    errors << "#{path}: image_caption must be a non-empty string"
  end
  return unless safe_local_path?(data["image"])

  target = ROOT.join(data["image"].sub(%r{\A/}, "")).cleanpath
  return unless target.file?

  actual_width, actual_height = image_dimensions(target)
  unless [data["image_width"], data["image_height"]] == [actual_width, actual_height]
    errors << "#{path}: declared image dimensions #{data['image_width']}x#{data['image_height']} " \
              "do not match #{actual_width}x#{actual_height}"
  end
rescue StandardError => error
  errors << "#{path}: cannot inspect image metadata (#{error.message})"
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
  require_fields(
    path, data,
    %w[layout event_id title summary start_date format event_status occurrence_status published],
    errors
  )
  errors << "#{path}: layout must be event" unless data["layout"] == "event"
  validate_text(path, data, %w[event_id title summary], errors)
  validate_boolean(path, data, "published", errors)
  validate_enum(path, data["format"], "format", EVENT_FORMATS, errors)
  validate_enum(path, data["event_status"], "event_status", EVENT_STATUSES, errors)
  validate_enum(
    path, data["occurrence_status"], "occurrence_status",
    EVENT_OCCURRENCE_STATUSES, errors
  )
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

media_path = ROOT.join("_data/media.yml")
media_data = Psych.safe_load_file(media_path, permitted_classes: [Date, Time], aliases: true)
media_items = media_data.is_a?(Hash) ? media_data["items"] : nil
unless media_items.is_a?(Array)
  errors << "_data/media.yml: items must be a list"
  media_items = []
end

ledger_paths = []
media_items.each_with_index do |item, index|
  path = "_data/media.yml item #{index + 1}"
  unless item.is_a?(Hash)
    errors << "#{path}: must be a mapping"
    next
  end
  require_fields(
    path, item,
    %w[path event_id source_page source_url original_format derivative authorisation],
    errors
  )
  validate_local_file(path, item["path"], "path", errors)
  %w[source_page source_url].each do |field|
    errors << "#{path}: #{field} must be an absolute HTTP(S) URL" unless valid_http_url?(item[field])
  end
  %w[derivative authorisation].each do |field|
    unless item[field].is_a?(String) && !item[field].strip.empty?
      errors << "#{path}: #{field} must be a non-empty string"
    end
  end
  errors << "#{path}: unknown event_id #{item['event_id'].inspect}" unless event_ids.key?(item["event_id"])
  errors << "#{path}: original_format must be PNG, JPEG, or HEIC" unless %w[PNG JPEG HEIC].include?(item["original_format"])
  if safe_local_path?(item["path"])
    target = ROOT.join(item["path"].sub(%r{\A/}, "")).cleanpath
    if target.file? && %w[.jpg .jpeg].include?(target.extname.downcase)
      begin
        image = EXIFR::JPEG.new(target.to_s)
        if image.exif? || image.gps
          errors << "#{path}: published JPEG must not contain EXIF or GPS metadata"
        end
      rescue StandardError => error
        errors << "#{path}: cannot inspect JPEG metadata (#{error.message})"
      end
    elsif target.file? && target.extname.downcase == ".png"
      begin
        metadata_chunks = png_chunk_types(target) & %w[eXIf iTXt tEXt zTXt]
        unless metadata_chunks.empty?
          errors << "#{path}: published PNG must not contain EXIF, XMP, IPTC, or text metadata"
        end
      rescue StandardError => error
        errors << "#{path}: cannot inspect PNG metadata (#{error.message})"
      end
    end
  end
  ledger_paths << item["path"]
end
errors << "_data/media.yml: duplicate local media paths" unless ledger_paths.uniq.length == ledger_paths.length

local_media_paths = ROOT.join("assets/images/events").glob("**/*").select(&:file?).map do |file|
  "/#{file.relative_path_from(ROOT)}"
end.sort
missing_ledger = local_media_paths - ledger_paths
stale_ledger = ledger_paths - local_media_paths
errors << "_data/media.yml: missing ledger entries for #{missing_ledger.join(', ')}" unless missing_ledger.empty?
errors << "_data/media.yml: ledger paths without files: #{stale_ledger.join(', ')}" unless stale_ledger.empty?

content_files = %w[_posts _events].flat_map do |directory|
  ROOT.join(directory).glob("**/*.{md,markdown,html}")
end
content_files.each do |file|
  file.read.scan(/\{%\s*include\s+event-figure\.html\s+(.+?)%\}/m).each do |match|
    attributes = match.first.scan(/([a-z_]+)="([^"]*)"/).to_h
    source = attributes["src"]
    path = file.relative_path_from(ROOT).to_s
    unless source && attributes["alt"] && attributes["width"] && attributes["height"]
      errors << "#{path}: event figures require src, alt, width, and height"
      next
    end
    unless safe_local_path?(source)
      errors << "#{path}: event figure src must be a safe local path"
      next
    end

    target = ROOT.join(source.sub(%r{\A/}, "")).cleanpath
    unless target.file?
      errors << "#{path}: event figure does not exist: #{source}"
      next
    end
    begin
      actual_width, actual_height = image_dimensions(target)
      declared = [Integer(attributes["width"]), Integer(attributes["height"])]
      unless declared == [actual_width, actual_height]
        errors << "#{path}: event figure #{source} declares #{declared.join('x')}, " \
                  "but the image is #{actual_width}x#{actual_height}"
      end
    rescue ArgumentError, StandardError => error
      errors << "#{path}: cannot inspect event figure #{source} (#{error.message})"
    end
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

require "csv"

class WorkshopRosterImporter
  Error = Class.new(StandardError)

  Result = Data.define(:created, :updated, :matched, :removed, :errors) do
    def message
      parts = []
      parts << "#{created} created" if created.positive?
      parts << "#{updated} updated" if updated.positive?
      parts << "#{matched} matched" if matched.positive?
      parts << "#{removed} removed" if removed.positive?

      message = if parts.any?
        "Roster imported: #{parts.join(", ")}"
      else
        "Roster imported (no participants added or removed)."
      end
      message = message.sub(/\.\z/, "") + "; #{errors.join("; ")}." if errors.any?
      message
    end
  end

  HEADER_ROW = "Participant Name"

  def self.call(workshop:, csv:)
    new(workshop:, csv:).call
  end

  def initialize(workshop:, csv:)
    @workshop = workshop
    @csv = csv
  end

  def call
    rows = parse_csv
    created = 0
    updated = 0
    matched = 0
    errors = []
    roster_user_ids = []

    rows.each do |row|
      user, status = upsert_user(row)
      unless user
        errors << row_error(row, status)
        next
      end

      @workshop.participations.find_or_create_by!(user:)
      roster_user_ids << user.id
      created += 1 if status == :created
      updated += 1 if status == :updated
      matched += 1 if status == :matched
    rescue ActiveRecord::RecordInvalid => e
      errors << "#{row[:participant_name]}: #{e.record.errors.full_messages.join(", ")}"
    end

    removed = if roster_user_ids.any?
      @workshop.participations.where.not(user_id: roster_user_ids).destroy_all.count
    else
      0
    end
    @workshop.participations.reload
    @workshop.regenerate_completions

    Result.new(created:, updated:, matched:, removed:, errors:)
  end

  private

  def parse_csv
    content = @csv.respond_to?(:read) ? @csv.read : @csv.to_s
    lines = content.lines
    header_index = lines.index { |line| line.start_with?(HEADER_ROW) }
    raise Error, "No roster header (#{HEADER_ROW}) found in file" unless header_index

    CSV.parse(lines[header_index..].join, headers: true, header_converters: :symbol)
  end

  def upsert_user(row)
    email = row[:email].to_s.strip.downcase
    return [ nil, :missing_email ] if email.blank?

    user = User.find_by(email_address: email)
    if user
      user.name = display_name(row[:participant_name])
      status = user.name_changed? ? :updated : :matched
      user.save!
      [ user, status ]
    else
      unit = row[:unit].to_s.strip
      return [ nil, :missing_unit ] if unit.blank?

      user = User.new(
        email_address: email,
        name: display_name(row[:participant_name]),
        password: unit,
        password_confirmation: unit
      )
      user.save!
      [ user, :created ]
    end
  end

  def row_error(row, status)
    name = row[:participant_name].to_s.strip
    label = name.presence || "row"
    status == :missing_email ? "#{label}: missing email" : "#{label}: missing unit"
  end

  def display_name(full_name)
    words = full_name.to_s.strip.split(/\s+/)
    return "" if words.empty?

    first = words.first.capitalize
    words.length == 1 ? first : "#{first} #{words.last[0].upcase}"
  end
end

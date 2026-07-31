require "csv"

class RosterImporter
  Result = Struct.new(:created_users, :updated_users, :added_participations, :removed_participations, :errors, keyword_init: true) do
    def success?
      errors.empty?
    end
  end

  HEADER_MARKER = "Participant Name"

  def initialize(workshop:, io:)
    @workshop = workshop
    @io = io
  end

  def import
    @result = Result.new(created_users: 0, updated_users: 0, added_participations: 0, removed_participations: 0, errors: [])

    begin
      @workshop.transaction do
        roster = parse_roster
        roster.each { |attrs| import_participant(attrs) }
        sync_removals(roster.map { |attrs| attrs[:email] })
        @workshop.participations.reload
        @workshop.regenerate_completions
      end
    rescue StandardError => e
      @result.errors << e.message
    end

    @result
  end

  private

  def parse_roster
    rows = CSV.parse(@io.read.delete_prefix("\uFEFF"))
    header_index = rows.index { |row| row.first.to_s.strip.casecmp?(HEADER_MARKER) }
    raise ArgumentError, "Could not find a \"#{HEADER_MARKER}\" header row in the roster file." unless header_index

    header = rows[header_index].map { |cell| cell.to_s.strip }
    name_index = header.index { |cell| cell.casecmp?("Participant Name") }
    email_index = header.index { |cell| cell.casecmp?("Email") }
    unit_index = header.index { |cell| cell.casecmp?("Unit") }

    rows.drop(header_index + 1).filter_map do |row|
      next if row.empty? || row.all? { |cell| cell.to_s.strip.empty? }

      name = row[name_index].to_s.strip
      next if name.empty?

      {
        name: name,
        email: row[email_index].to_s.strip.downcase,
        unit: row[unit_index].to_s.strip
      }
    end.tap do |roster|
      raise ArgumentError, "No participants found in the roster file." if roster.empty?
    end
  end

  def import_participant(attrs)
    raise ArgumentError, "Roster row has no email address." if attrs[:email].blank?

    user = User.find_or_initialize_by(email_address: attrs[:email])
    user.name = display_name(attrs[:name])
    user.password = attrs[:unit] if user.new_record?

    if user.new_record?
      @result.created_users += 1
    elsif user.changed?
      @result.updated_users += 1
    end
    user.save!

    unless user.participations.exists?(workshop: @workshop)
      @workshop.participations.create!(user: user)
      @result.added_participations += 1
    end
  rescue ActiveRecord::RecordInvalid => e
    raise ArgumentError, "#{attrs[:name]} (#{attrs[:email]}): #{e.record.errors.full_messages.to_sentence}"
  end

  def sync_removals(roster_emails)
    keep_user_ids = User.where(email_address: roster_emails).pluck(:id)
    participations = keep_user_ids.any? ? @workshop.participations.where.not(user_id: keep_user_ids) : @workshop.participations
    @result.removed_participations = participations.count
    participations.destroy_all
  end

  def display_name(full_name)
    parts = full_name.split(/\s+/)
    return full_name if parts.length < 2

    "#{parts.first} #{parts.last[0].upcase}"
  end
end

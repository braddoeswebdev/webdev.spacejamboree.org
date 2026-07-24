class NetworkNodeDedupeKey
  def self.build(internet_map_id:, user_id:, ip_address:, is_private:)
    if is_private
      "private:#{internet_map_id}:#{user_id}:#{ip_address}"
    else
      "public:#{internet_map_id}:#{ip_address}"
    end
  end
end

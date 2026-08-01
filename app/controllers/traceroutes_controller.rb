class TraceroutesController < ApplicationController
  before_action :require_login
  before_action :set_internet_map
  before_action :require_workshop_access

  def create
    @traceroute = @internet_map.traceroutes.new(traceroute_params)
    @traceroute.user = Current.user

    if @traceroute.save
      ProcessTracerouteJob.perform_later(@traceroute)
      redirect_to @internet_map, notice: "Traceroute submitted! Processing..."
    else
      @traceroutes = @internet_map.traceroutes.includes(:user).order(created_at: :desc).limit(20)
      @organizations = Organization.where(id: @internet_map.network_nodes.select(:organization_id)).distinct

      final_node_domains = build_final_node_domains

      @elements = {
        nodes: @internet_map.network_nodes.includes(:organization).map { |n|
          serialize_node(n, final_node_domains: final_node_domains)
        },
        edges: @internet_map.network_links.map { |l| serialize_link(l) }
      }
      render "internet_maps/show", status: :unprocessable_content
    end
  end

  def retry
    @traceroute = @internet_map.traceroutes.find(params.expect(:id))
    @traceroute.update!(status: :pending, error_message: nil)
    ProcessTracerouteJob.perform_later(@traceroute)
    redirect_to @internet_map, notice: "Traceroute re-submitted! Processing..."
  end

  private

  def set_internet_map
    @internet_map = InternetMap.find(params.expect(:internet_map_id))
  end

  def require_login
    unless Current.user
      redirect_to new_session_path, alert: "You must be signed in to view this page."
    end
  end

  def require_workshop_access
    workshop = @internet_map.workshop
    unless Current.user.admin? ||
        workshop.instructor == Current.user ||
        workshop.participants.include?(Current.user)
      redirect_to workshop, alert: "You don't have access to this map."
    end
  end

  def traceroute_params
    params.expect(traceroute: [ :target_domain, :raw_output ])
  end

  def serialize_node(node, final_node_domains: {})
    data = {
      id: "node_#{node.id}",
      label: node.hostname || node.ip_address,
      ip: node.ip_address,
      org_name: node.organization&.name,
      org_color: node.organization&.color || (node.is_private ? "#a9a9a9" : "#808080"),
      is_private: node.is_private,
      x: node.x,
      y: node.y,
      user_name: node.user.name,
      domain: final_node_domains[node.id]
    }
    if data[:domain]
      data[:label] = "#{data[:domain]}\n#{data[:label]}"
    end
    { data: data }
  end

  def serialize_link(link)
    {
      data: {
        id: "link_#{link.id}",
        source: "node_#{link.start_node_id}",
        target: "node_#{link.end_node_id}",
        label: link.rtt_samples.presence,
        hop_number: link.hop_number,
        spans_gap: link.spans_gap,
        timed_out: link.timed_out
      }
    }
  end

  def build_final_node_domains
    domains = {}
    @internet_map.traceroutes.complete.includes(:network_links).each do |t|
      last_link = t.network_links.max_by(&:hop_number)
      next unless last_link
      domains[last_link.end_node_id] ||= t.target_domain
    end
    domains
  end
end

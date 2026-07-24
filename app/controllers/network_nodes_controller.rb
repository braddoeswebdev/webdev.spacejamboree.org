class NetworkNodesController < ApplicationController
  before_action :require_login

  def position
    @node = NetworkNode.find(params.expect(:id))
    @node.update!(x: params.expect(:x), y: params.expect(:y))
    head :ok
  end

  private

  def require_login
    unless Current.user
      head :unauthorized
    end
  end
end

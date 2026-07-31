module ApplicationHelper
  def impersonating?
    Current.session&.impersonating?
  end
end

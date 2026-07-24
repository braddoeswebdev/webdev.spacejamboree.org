module InternetMapsHelper
  def traceroute_badge(traceroute)
    classes = {
      "pending" => "bg-secondary",
      "processing" => "bg-info",
      "complete" => "bg-success",
      "failed" => "bg-danger"
    }
    tag.span traceroute.status.titleize, class: "badge #{classes[traceroute.status]}"
  end
end

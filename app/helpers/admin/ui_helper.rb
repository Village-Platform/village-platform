module Admin
  module UiHelper
    TONES = {
      "pending" => "warning", "active" => "success", "rejected" => "danger", "suspended" => "danger",
      "current" => "success", "scheduled" => "info", "expired" => "muted",
      "super_admin" => "success", "firm_admin" => "warning", "user" => "muted",
      "news" => "info", "article" => "muted", "announcement" => "warning",
      true => "success", false => "muted"
    }.freeze

    def enum_label(model, attribute, value)
      return "—" if value.blank?

      t("enums.#{model.model_name.i18n_key}.#{attribute}.#{value}", default: value.to_s.humanize)
    end

    # [[label, value], ...] for <select>
    def enum_options(model, attribute)
      model.public_send(attribute.to_s.pluralize).keys.map { |key| [ enum_label(model, attribute, key), key ] }
    end

    def badge(text, tone = "muted")
      tag.span(text, class: "badge badge-#{tone}")
    end

    def enum_badge(model, attribute, value)
      badge(enum_label(model, attribute, value), TONES.fetch(value.to_s, "muted"))
    end

    def yes_no_badge(value)
      badge(value ? "نعم" : "لا", TONES[!!value])
    end

    def egp(cents)
      return "—" if cents.nil?

      "#{number_with_precision(cents / 100.0, precision: 2, strip_insignificant_zeros: true)} ج.م"
    end

    def fmt_time(time)
      time ? l(time, format: "%Y-%m-%d %H:%M") : "—"
    end

    def fmt_date(time)
      time ? l(time.to_date, format: "%Y-%m-%d") : "—"
    end

    def nav_link(label, path, icon_name, exact: false, count: nil)
      active = exact ? request.path == path : request.path.start_with?(path)
      link_to path, class: [ "nav-link", ("active" if active) ], "aria-current": (active ? "page" : nil) do
        safe_join([ icon(icon_name), tag.span(label), (tag.span(count, class: "nav-count") if count.to_i.positive?) ].compact)
      end
    end

    # <%= page_header "الأقسام", :categories, subtitle: "..." do %> buttons <% end %>
    def page_header(title, icon_name, subtitle: nil, &block)
      content_for(:title, title) unless content_for?(:title)
      actions = block ? tag.div(capture(&block), class: "header-actions") : nil

      tag.div(class: "page-header") do
        heading = tag.div(class: "title") do
          tag.span(icon(icon_name, size: 22), class: "icon-tile") +
            tag.div { tag.h1(title) + (subtitle ? tag.p(subtitle) : "".html_safe) }
        end
        safe_join([ heading, actions ].compact)
      end
    end

    def initials(name)
      name.to_s.split.first(2).map { |part| part[0] }.join
    end

    def empty_state(message)
      tag.div(class: "empty") do
        safe_join([ image_tag("/brand/web/mark.png", alt: "", class: "empty-mark"), tag.p(message) ])
      end
    end

    # Keeps current filters when building links (pagination, etc.)
    def filter_params(**overrides)
      request.query_parameters.symbolize_keys.merge(overrides)
    end
  end
end

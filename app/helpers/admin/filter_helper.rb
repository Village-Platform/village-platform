module Admin
  # Advanced filtering and sorting on admin index screens, over the ransack search the
  # controller built with `filter(scope)` (see Filterable). Fields submit under `f[...]`; the
  # plain-text `q` box and status tabs stay separate and are carried through as hidden fields.
  module FilterHelper
    # A collapsible panel, opened only while a filter is in use. `carry` names the existing
    # params the panel must keep when it is submitted, so applying an advanced filter does not
    # silently drop the text search or the status tab the admin is already looking at.
    def advanced_filter(url:, carry: %i[ q status deleted kind role active ], &block)
      return "".html_safe unless filter_object

      form = search_form_for(filter_object, url:, html: { class: "adv-filter-form" }) do |f|
        hidden = carry.filter_map { |key| hidden_field_tag(key, params[key], id: nil) if params[key].present? }
        actions = tag.div(class: "adv-filter-actions") do
          safe_join([ f.submit("تطبيق", class: "btn btn-sm", name: nil),
                      link_to("مسح", url, class: "btn btn-ghost btn-sm") ])
        end
        safe_join([ *hidden, tag.div(capture(f, &block), class: "adv-filter-grid"), actions ])
      end

      tag.details(class: "adv-filter", open: filter_active?) do
        safe_join([ tag.summary { safe_join([ icon(:search, size: 14), " بحث متقدّم" ]) }, form ])
      end
    end

    # A sort on its own is not a filter, so it does not open the panel.
    def filter_active?
      raw = params[:f]
      return false unless raw.respond_to?(:to_unsafe_h)

      raw.to_unsafe_h.except("s").values.any?(&:present?)
    end

    # A header that sorts by `attribute`, keeping the current search. aria-sort tells a screen
    # reader which column is sorted and which way, which the arrow alone does not.
    def sortable_th(label, attribute)
      return tag.th(label) unless filter_object

      sort = filter_object.sorts.find { |s| s.name == attribute.to_s }
      aria = { nil => "none", "asc" => "ascending", "desc" => "descending" }.fetch(sort&.dir)
      tag.th(sort_link(filter_object, attribute, label, class: "th-sort"), "aria-sort": aria)
    end

    def filter_text(form, predicate, label, ltr: false)
      filter_field(label, form.search_field(predicate, class: ("ltr" if ltr), "aria-label": label))
    end

    def filter_select(form, predicate, choices, label)
      filter_field(label, form.select(predicate, choices, { include_blank: "الكل" }, "aria-label": label))
    end

    # Two bounds on one attribute: `<attr>_gteq` and `<attr>_lteq`.
    def filter_range(form, attribute, label, as: :number)
      input = as == :date ? :date_field : :number_field
      bounds = tag.div(class: "adv-range") do
        safe_join([ form.public_send(input, :"#{attribute}_gteq", "aria-label": "#{label} من", placeholder: "من"),
                    form.public_send(input, :"#{attribute}_lteq", "aria-label": "#{label} إلى", placeholder: "إلى") ])
      end
      filter_field(label, bounds)
    end

    private

    def filter_field(label, control)
      tag.div(class: "adv-field") { safe_join([ tag.span(label, class: "lbl"), control ]) }
    end
  end
end

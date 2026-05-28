class ApplicationFormBuilder < ActionView::Helpers::FormBuilder
  # Wrap common field helpers with form-group div, label, and inline errors.
  %i[text_field email_field telephone_field date_field number_field
     text_area password_field url_field].each do |method_name|
    define_method(method_name) do |attribute, options = {}, &block|
      if options.delete(:skip_group)
        return super(attribute, options, &block)
      end

      label_text = options.delete(:label)
      hint       = options.delete(:hint)

      # Merge default class
      options[:class] = [ options[:class], "form-control" ].compact.join(" ")

      field_html = super(attribute, options, &block)
      wrap_field(attribute, field_html, label_text: label_text, hint: hint)
    end
  end

  def select(attribute, choices, options = {}, html_options = {}, &block)
    if options.delete(:skip_group)
      return super(attribute, choices, options, html_options, &block)
    end

    label_text = options.delete(:label)
    hint       = options.delete(:hint)

    html_options[:class] = [ html_options[:class], "form-control" ].compact.join(" ")

    field_html = super(attribute, choices, options, html_options, &block)
    wrap_field(attribute, field_html, label_text: label_text, hint: hint)
  end

  private

  def wrap_field(attribute, field_html, label_text: nil, hint: nil)
    has_error = object&.errors&.[](attribute)&.any?
    group_classes = [ "form-group", ("has-error" if has_error) ].compact.join(" ")

    @template.content_tag(:div, class: group_classes) do
      parts = []
      parts << required_label(attribute, label_text)
      parts << field_html
      parts << inline_errors(attribute) if has_error
      parts << hint_html(hint) if hint
      @template.safe_join(parts)
    end
  end

  def required_label(attribute, label_text)
    if required_attribute?(attribute)
      label_content = @template.safe_join([
        label_text || attribute.to_s.humanize,
        @template.content_tag(:span, " *", class: "required-mark")
      ])
      label(attribute, label_content)
    else
      label(attribute, label_text)
    end
  end

  def required_attribute?(attribute)
    return false unless object&.class&.respond_to?(:validators_on)

    object.class.validators_on(attribute).any? do |validator|
      validator.is_a?(ActiveRecord::Validations::PresenceValidator) &&
        validator.options.except(:message).empty?
    end
  end

  def inline_errors(attribute)
    @template.safe_join(
      object.errors.full_messages_for(attribute).map do |msg|
        @template.content_tag(:span, msg, class: "field-error")
      end
    )
  end

  def hint_html(hint)
    @template.content_tag(:div, hint, class: "form-hint")
  end
end

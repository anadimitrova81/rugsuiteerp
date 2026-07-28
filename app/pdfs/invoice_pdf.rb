require "prawn"
require "prawn/table"

# Renders a subscription Invoice as a Bulgarian VAT invoice (фактура), matching
# the operator's standard layout. Pure Prawn (no browser/binary); Cyrillic comes
# from the vendored DejaVu Sans font.
#
# Structural labels are localised to the invoice's locale (the recipient's
# language) so the company can read it. Bulgarian legal specifics stay as-is:
# the issuer's own details, the ЗДДС grounds citation, the BGN dual currency,
# and the "Словом" (amount in words) line, which only appears on the Bulgarian
# copy. The platform console passes locale: :bg to force the Bulgarian version.
#
# Usage: InvoicePdf.new(invoice).render  /  InvoicePdf.new(invoice, locale: :bg)
class InvoicePdf < Prawn::Document
  GREY   = "666666".freeze
  LIGHT  = "F2F2F2".freeze
  BORDER = "999999".freeze

  def initialize(invoice, locale: nil)
    super(page_size: "A4", margin: 40)
    @invoice = invoice
    @locale = resolve_locale(locale)
    setup_fonts
    I18n.with_locale(@locale) do
      brand_header
      move_down 14
      parties
      move_down 16
      title_block
      move_down 16
      line_items
      move_down 12
      totals
      move_down 18
      notes
      move_down 28
      signatures
    end
  end

  private

  def resolve_locale(override)
    candidate = (override || @invoice.locale || I18n.default_locale).to_s.to_sym
    I18n.available_locales.include?(candidate) ? candidate : I18n.default_locale
  end

  def tr(key, **opts)
    I18n.t("invoice_pdf.#{key}", **opts)
  end

  def setup_fonts
    font_families.update(
      "DejaVu" => {
        normal: Rails.root.join("vendor/fonts/DejaVuSans.ttf").to_s,
        bold:   Rails.root.join("vendor/fonts/DejaVuSans-Bold.ttf").to_s,
      },
    )
    font "DejaVu"
    font_size 9
  end

  # ----- Brand header (issuer logo + wordmark) -----
  def brand_header
    logo = Rails.root.join("public/icon.png").to_s
    cells = []
    if File.exist?(logo)
      cells << { image: logo, image_width: 34, image_height: 34, borders: [], padding: 0, vposition: :center }
    end
    cells << {
      content: "<b>RugSuite</b> ERP", inline_format: true, size: 16,
      text_color: "0f3f7e", valign: :center, borders: [], padding: [ 0, 0, 0, 8 ]
    }
    widths = cells.size == 2 ? [ 40, bounds.width - 40 ] : [ bounds.width ]
    table([ cells ], width: bounds.width, column_widths: widths) { |t| t.cells.borders = [] }
  end

  # ----- Recipient / supplier boxes -----
  def parties
    recipient = {
      name:    @invoice.recipient_name,
      address: @invoice.recipient_address,
      eik:     @invoice.recipient_eik,
      vat:     @invoice.recipient_vat_number,
      mol:     @invoice.recipient_mol,
    }
    supplier = Invoice::SUPPLIER

    recipient_labels = BillingFields.for(@invoice.recipient_country_code)
    supplier_labels  = BillingFields::PROFILES["BG"] # the issuer is always Bulgarian

    data = [
      [ header_cell(tr(:recipient)), header_cell(tr(:supplier)) ],
      [ party_cell(recipient, recipient_labels), party_cell(supplier, supplier_labels) ],
    ]
    table(data, width: bounds.width, column_widths: [ bounds.width / 2, bounds.width / 2 ]) do |t|
      t.cells.borders = [ :left, :right, :top, :bottom ]
      t.cells.border_color = BORDER
      t.cells.padding = 6
      t.row(0).font_style = :bold
      t.row(0).size = 8
      t.row(0).text_color = GREY
    end
  end

  def header_cell(text)
    { content: text, borders: [] }
  end

  def party_cell(p, labels)
    lines = []
    lines << "<b>#{p[:name]}</b>"
    lines << p[:address] if p[:address].present?
    lines << "#{labels[:reg]}: #{p[:eik]}" if p[:eik].present?
    lines << "#{labels[:tax]}: #{p[:vat]}" if p[:vat].present?
    lines << "#{labels[:rep]}: #{p[:mol]}" if p[:mol].present?
    { content: lines.join("\n"), inline_format: true }
  end

  # ----- "Оригинал" / title + number & dates -----
  def title_block
    right = "<font size='18'><b>#{tr(:title)}</b></font>\n" \
            "#{tr(:number)}: <b>#{@invoice.number}</b>\n" \
            "#{tr(:issued_on)}: <b>#{fmt_date(@invoice.issued_on)}</b>\n" \
            "#{tr(:tax_event)}: <b>#{fmt_date(@invoice.issued_on)}</b>"

    table([ [
      { content: tr(:original), size: 20, font_style: :bold, valign: :center },
      { content: right, inline_format: true, align: :right, valign: :center, leading: 2 },
    ] ], width: bounds.width, column_widths: [ bounds.width * 0.38, bounds.width * 0.62 ]) do |t|
      t.cells.borders = []
      t.cells.padding = [ 2, 0 ]
    end
  end

  # ----- Line items -----
  def line_items
    header = [ tr(:col_no), tr(:col_item), tr(:col_qty), tr(:col_price), tr(:col_total) ]
             .map { |h| { content: h, font_style: :bold } }
    row = [
      "1",
      tr(:line_item, plan: I18n.t("plan.#{@invoice.plan}"),
                     from: fmt_date(@invoice.period_start), to: fmt_date(@invoice.period_end)),
      "1.00",
      fmt_eur_plain(@invoice.amount),
      eur(@invoice.amount),
    ]
    widths = [ 24, bounds.width - 24 - 82 - 62 - 74, 82, 62, 74 ]
    table([ header, row ], width: bounds.width, column_widths: widths) do |t|
      t.cells.borders = [ :top, :bottom ]
      t.cells.border_color = BORDER
      t.cells.padding = 6
      t.row(0).background_color = LIGHT
      t.row(0).size = 8
      t.columns(2..4).align = :right
      t.column(0).align = :center
    end
  end

  # ----- Totals (right aligned) -----
  def totals
    rows = []
    rows << money_row("#{tr(:subtotal)}:", @invoice.amount)
    if @invoice.discount_percent.positive?
      rows << [ { content: "#{tr(:discount)}:", align: :right }, { content: "-#{@invoice.discount_percent} %", align: :right, font_style: :bold } ]
    end
    rows << money_row("#{tr(:tax_base)}:", @invoice.net_amount)
    rows << [ { content: "#{tr(:vat_rate)}:", align: :right }, { content: "#{@invoice.vat_rate} %", align: :right, font_style: :bold } ]
    rows << money_row("#{tr(:vat_amount)}:", @invoice.vat_amount)
    rows << money_row("#{tr(:total_due)}:", @invoice.total_amount, big: true)

    tbl = make_table(rows, column_widths: [ 150, 110 ]) do |t|
      t.cells.borders = []
      t.cells.padding = [ 3, 4 ]
    end
    bounding_box([ bounds.width - 260, cursor ], width: 260) do
      tbl.draw
    end
    move_down 4
    text "#{tr(:rate)}: 1 € = 1.95583 лв.", size: 7, align: :right, color: GREY
  end

  def money_row(label, euros, big: false)
    [
      { content: label, align: :right, size: (big ? 10 : 9) },
      {
        content: "<b>#{eur(euros)}</b>\n<font size='7'>#{bgn(euros)}</font>",
        align: :right, inline_format: true, size: (big ? 12 : 9),
      },
    ]
  end

  # ----- Footer notes -----
  def notes
    # "Словом" (amount in words) is a Bulgarian invoicing element — only on the BG copy.
    note_line("Словом:", BulgarianAmountInWords.call(@invoice.total_amount)) if @locale == :bg
    note_line("#{tr(:vat_grounds)}:", @invoice.vat_grounds) if @invoice.vat_grounds.present?
    note_line("#{tr(:payment_method)}:", tr(:payment_by_bank))
  end

  def note_line(label, value)
    table([ [ { content: "#{label} <b>#{value}</b>", inline_format: true } ] ],
          width: bounds.width) do |t|
      t.cells.borders = [ :bottom ]
      t.cells.border_color = "DDDDDD"
      t.cells.padding = [ 5, 2 ]
      t.cells.size = 9
    end
  end

  # ----- Signatures -----
  def signatures
    table([ [
      { content: "#{tr(:received_by)}: <b>#{@invoice.recipient_mol.presence || @invoice.recipient_name}</b>", inline_format: true },
      { content: "#{tr(:prepared_by)}: <b>Ана Димитрова</b>", inline_format: true, align: :left },
    ] ], width: bounds.width) do |t|
      t.cells.borders = []
      t.cells.padding = [ 2, 0 ]
    end
  end

  # ----- helpers -----
  def eur(v)  = format("%.2f €", v.to_f)
  def bgn(v)  = format("%.2f лв.", @invoice.to_bgn(v).to_f)
  def fmt_eur_plain(v) = format("%.2f", v.to_f)
  def fmt_date(d) = d.strftime("%d.%m.%Y")
end

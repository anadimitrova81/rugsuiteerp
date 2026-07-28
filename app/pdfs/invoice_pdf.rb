require "prawn"
require "prawn/table"

# Renders a subscription Invoice as a Bulgarian VAT invoice (фактура), matching
# the operator's standard layout. Pure Prawn (no browser/binary); Cyrillic comes
# from the vendored DejaVu Sans font. Usage: InvoicePdf.new(invoice).render
class InvoicePdf < Prawn::Document
  GREY   = "666666".freeze
  LIGHT  = "F2F2F2".freeze
  BORDER = "999999".freeze

  def initialize(invoice)
    super(page_size: "A4", margin: 40)
    @invoice = invoice
    setup_fonts
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

  private

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

  # ----- Получател / Доставчик boxes -----
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
      [ header_cell("ПОЛУЧАТЕЛ"), header_cell("ДОСТАВЧИК") ],
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

  # ----- "Оригинал" / "ФАКТУРА" + number & dates -----
  def title_block
    right = [
      [ { content: "<b>ФАКТУРА</b>", size: 18, align: :right, inline_format: true } ],
      [ { content: "Номер: <b>#{@invoice.number}</b>", align: :right, inline_format: true } ],
      [ { content: "Дата на издаване: <b>#{fmt_date(@invoice.issued_on)}</b>", align: :right, inline_format: true } ],
      [ { content: "Дата на данъчно събитие: <b>#{fmt_date(@invoice.issued_on)}</b>", align: :right, inline_format: true } ],
    ]

    table([ [
      { content: "Оригинал", size: 20, font_style: :bold, valign: :center },
      { content: make_table(right) { |t| t.cells.borders = []; t.cells.padding = [ 1, 0 ] } },
    ] ], width: bounds.width, column_widths: [ bounds.width * 0.45, bounds.width * 0.55 ]) do |t|
      t.cells.borders = []
      t.cells.padding = [ 2, 0 ]
    end
  end

  # ----- Line items -----
  def line_items
    header = %w[№ Артикул Количество Ед.\ цена Стойност].map { |h| { content: h, font_style: :bold } }
    row = [
      "1",
      "Абонамент RugSuite ERP — план #{@invoice.plan.capitalize} (#{fmt_date(@invoice.period_start)} – #{fmt_date(@invoice.period_end)})",
      "1.00 бр.",
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
    rows << money_row("Сума (без отстъпка):", @invoice.amount)
    rows << [ { content: "Отстъпка:", align: :right }, { content: "-#{@invoice.discount_percent} %", align: :right, font_style: :bold } ] if @invoice.discount_percent.positive?
    rows << money_row("Данъчна основа:", @invoice.net_amount)
    rows << [ { content: "Процент ДДС:", align: :right }, { content: "#{@invoice.vat_rate} %", align: :right, font_style: :bold } ]
    rows << money_row("Начислен ДДС:", @invoice.vat_amount)
    rows << money_row("Сума за плащане:", @invoice.total_amount, big: true)

    tbl = make_table(rows, column_widths: [ 150, 110 ]) do |t|
      t.cells.borders = []
      t.cells.padding = [ 3, 4 ]
    end
    # Right-align the whole totals block.
    bounding_box([ bounds.width - 260, cursor ], width: 260) do
      tbl.draw
    end
    move_down 4
    text "Курс: 1 € = 1.95583 лв.", size: 7, align: :right, color: GREY
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
    note_line("Словом:", BulgarianAmountInWords.call(@invoice.total_amount))
    note_line("Основание за неначисляване на ДДС:", @invoice.vat_grounds) if @invoice.vat_grounds.present?
    note_line("Начин на плащане:", Invoice::PAYMENT_METHOD)
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
      { content: "Получател: <b>#{@invoice.recipient_mol.presence || @invoice.recipient_name}</b>", inline_format: true },
      { content: "Съставил: <b>Ана Димитрова</b>", inline_format: true, align: :left },
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

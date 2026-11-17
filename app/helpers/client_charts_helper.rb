# Geometry for the column charts on the admin "Statistics" page (ported from
# nexus-cleaning). The charts are
# plain SVG drawn on the server; chart_tooltip_controller.js adds the hover
# readout. Columns follow the dataviz mark spec: at most 24px wide, 4px
# rounded data-end, square at the baseline, 2px surface gap between stacked
# segments.
module ClientChartsHelper
  CHART_WIDTH = 1000
  CHART_HEIGHT = 250
  CHART_PADDING = { top: 22, right: 8, bottom: 40, left: 48 }.freeze
  MAX_COLUMN_WIDTH = 24
  SEGMENT_GAP = 2
  CORNER_RADIUS = 4
  # Narrowest column band that still fits a value label; with more months
  # than fit, the chart scrolls sideways instead of overlapping labels.
  MIN_BAND = 44

  # series: [{ key:, label:, color: }] drawn bottom-up; columns: one hash per
  # x position with :label (tooltip title), :date (first day of the month)
  # and a value per series key. cap_format is for the total over each column,
  # where space is tightest. Returns everything the partial draws.
  def column_chart(columns:, series:, format: ->(v) { number_with_delimiter(v.round) }, cap_format: format)
    plot_width = CHART_WIDTH - CHART_PADDING[:left] - CHART_PADDING[:right]
    plot_height = CHART_HEIGHT - CHART_PADDING[:top] - CHART_PADDING[:bottom]
    baseline = CHART_PADDING[:top] + plot_height

    totals = columns.map { |c| series.sum { |s| c[s[:key]].to_f } }
    step = nice_step(totals.max.to_f / 4)
    top_value = [ step * (totals.max.to_f / step).ceil, step ].max
    scale = ->(v) { v.to_f / top_value * plot_height }

    band = plot_width.to_f / [ columns.size, 1 ].max
    width = [ MAX_COLUMN_WIDTH, band * 0.6 ].min
    drawn = columns.each_with_index.map do |column, i|
      x = CHART_PADDING[:left] + band * i + (band - width) / 2
      bottom = baseline
      visible = series.select { |s| scale.call(column[s[:key]]) > SEGMENT_GAP }
      segments = visible.each_with_index.map do |s, j|
        height = scale.call(column[s[:key]])
        seg_bottom = j.zero? ? bottom : bottom - SEGMENT_GAP
        seg_top = bottom - height
        bottom = seg_top
        { color: s[:color], path: column_path(x, seg_top, width, seg_bottom - seg_top, top: j == visible.size - 1) }
      end

      {
        segments: segments,
        hit: { x: CHART_PADDING[:left] + band * i, width: band },
        top: baseline - scale.call(totals[i]),
        center: x + width / 2,
        total: format.call(totals[i]),
        cap: cap_format.call(totals[i]),
        labeled: totals[i].positive?,
        title: column[:label],
        rows: series.reverse.map { |s| { label: s[:label], value: format.call(column[s[:key]].to_f), color: s[:color] } },
        month: I18n.t("date.abbr_month_names")[column[:date].month],
        year: (i.zero? || column[:date].month == 1) ? column[:date].year : nil,
      }
    end

    {
      width: CHART_WIDTH, height: CHART_HEIGHT, baseline: baseline,
      left: CHART_PADDING[:left], right: CHART_WIDTH - CHART_PADDING[:right],
      plot_top: CHART_PADDING[:top], plot_height: plot_height,
      min_width: (CHART_PADDING[:left] + CHART_PADDING[:right] + columns.size * MIN_BAND).round,
      ticks: (0..(top_value / step).round).map { |k| { y: baseline - scale.call(k * step), label: format.call(k * step) } },
      columns: drawn, series: series, show_totals_in_tooltip: series.size > 1,
    }
  end

  private

  # A column with a rounded data-end and a square base.
  def column_path(x, y, width, height, top:)
    r = top ? [ CORNER_RADIUS, height, width / 2 ].min : 0
    right = x + width
    bottom = y + height
    "M#{fmt x},#{fmt bottom} L#{fmt x},#{fmt y + r} Q#{fmt x},#{fmt y} #{fmt x + r},#{fmt y} " \
      "L#{fmt right - r},#{fmt y} Q#{fmt right},#{fmt y} #{fmt right},#{fmt y + r} L#{fmt right},#{fmt bottom} Z"
  end

  # The smallest of 1, 2, 2.5, 5 × 10^k that is at least `raw`.
  def nice_step(raw)
    return 1 if raw <= 0

    magnitude = 10**Math.log10(raw).floor
    [ 1, 2, 2.5, 5, 10 ].map { |m| m * magnitude }.find { |s| s >= raw }
  end

  def fmt(value) = value.round(1)
end

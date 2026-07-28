require "bigdecimal"

# Spells a euro amount in Bulgarian words for the "Словом" line of a фактура,
# e.g. 49.00 => "Четиридесет и девет евро и нула цента". Gender differs by
# noun: евро is neuter ("едно", "две"), цент is masculine ("един", "два").
# Handles 0–999 999; plan prices are well within range.
class BulgarianAmountInWords
  ONES_N = %w[нула едно две три четири пет шест седем осем девет].freeze   # neuter (евро)
  ONES_M = %w[нула един два три четири пет шест седем осем девет].freeze   # masculine (цент)
  TEENS  = %w[десет единадесет дванадесет тринадесет четиринадесет петнадесет
              шестнадесет седемнадесет осемнадесет деветнадесет].freeze
  TENS     = [ nil, nil, "двадесет", "тридесет", "четиридесет", "петдесет",
               "шестдесет", "седемдесет", "осемдесет", "деветдесет" ].freeze
  HUNDREDS = [ nil, "сто", "двеста", "триста", "четиристотин", "петстотин",
               "шестстотин", "седемстотин", "осемстотин", "деветстотин" ].freeze

  def self.call(amount)
    d     = BigDecimal(amount.to_s)
    euros = d.to_i
    cents = ((d - euros) * 100).round.to_i

    euro_word = "евро"
    cent_word = cents == 1 ? "цент" : "цента"
    text = "#{spell(euros, :n)} #{euro_word} и #{spell(cents, :m)} #{cent_word}"
    text[0].upcase + text[1..]
  end

  # Spells 0–999 999 with the given gender for the trailing unit.
  def self.spell(n, gender)
    ones = gender == :m ? ONES_M : ONES_N
    return ones[0] if n.zero?

    parts = []
    thousands = n / 1000
    rest = n % 1000
    if thousands.positive?
      parts.concat(thousands_words(thousands))
    end
    parts.concat(group_words(rest, ones)) if rest.positive?
    join_bg(parts)
  end

  # Words for the thousands group ("хиляда", "две хиляди", "три хиляди", …).
  def self.thousands_words(n)
    return [ "хиляда" ] if n == 1
    # "две хиляди" uses feminine 2; 3–9 are gender-neutral.
    lead = group_words(n, ONES_N.each_with_index.map { |w, i| i == 2 ? "две" : w })
    lead[-1] = "#{lead[-1]} хиляди"
    lead
  end

  # Component words for 1–999 as an array (so join_bg can place "и").
  def self.group_words(n, ones)
    w = []
    h = n / 100
    rem = n % 100
    t = rem / 10
    u = rem % 10
    w << HUNDREDS[h] if h.positive?
    if t == 1
      w << TEENS[u]
    else
      w << TENS[t] if t.positive?
      w << ones[u] if u.positive?
    end
    w
  end

  # Bulgarian joins the final component with "и"; the rest with spaces.
  # ["сто","двадесет","три"] => "сто двадесет и три".
  def self.join_bg(parts)
    return parts.first if parts.size <= 1
    "#{parts[0..-2].join(' ')} и #{parts[-1]}"
  end
end

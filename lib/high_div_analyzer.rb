require_relative "base.rb"

class HighDivAnalyzer < Base
  FOLDER_PATH = "/Users/batesjernigan/Desktop/finviz/csv_files/high_div"
  HEADERS = ["Ticker", "Market Cap", "Div", "ROA", "ROE", "ROI", "Curr R", "Quick R", "LTDebt/Eq", "Debt/Eq", "Gross M", "Profit M", "Earnings", "Price", "Change", "Volume"].freeze

  def screener_content(record_offset = 1)
    resp = self.class.get("/screener.ashx?v=161&f=fa_div_o10&ft=4&o=-dividendyield&r=#{record_offset}")
    Nokogiri::HTML(resp).at_css('#screener-content')
  end

  def retrieve_company_info
    CSV.open("#{FOLDER_PATH}/#{Date.today.strftime('%Y-%m-%dT%H-%M-%S%z')}-finviz.csv", 'wb') do |csv|
      csv << HEADERS
      offset = 0
      more_rows = true
      while more_rows
        content = screener_content(offset * 20 + 1).css('table[bgcolor="#d3d3d3"]').css("tr[valign='top']")
        sleep(4) # sleep 4 seconds to avoid bots
        content.flat_map do |table_row|
          csv << extract_row(table_row.css("td"))
        end
        offset += 1
        more_rows = content.size == 20
      end
    end
  end

  def diff_companies
    retrieve_company_info
    most_recent_file_created, previous_file_created = Dir["#{FOLDER_PATH}/*finviz*"].sort { |a, b| b <=> a }[0..1]

    most_recent_file_content = CSV.read(most_recent_file_created)
    previous_file_content = CSV.read(previous_file_created) if previous_file_created

    CSV.open("#{FOLDER_PATH}/#{Date.today.strftime('%Y-%m-%dT%H-%M-%S%z')}-diff.csv", 'wb') do |csv|
      csv << (["Action"] + HEADERS)
      most_recent_file_content.each do |recent_file_line|
        unless previous_file_content&.any? { |prev_file_line| prev_file_line[0] == recent_file_line[0] } # ticker
          csv << (["ADDED"] + recent_file_line)
        end
      end

      previous_file_content&.each do |prev_file_line|
        unless most_recent_file_content.any? { |recent_file_line| prev_file_line[0] == recent_file_line[0] } # ticker
          csv << (["REMOVED"] + prev_file_line)
        end
      end
    end
  end

  # All HEADERS
  # No, Ticker, Market Cap, Div, roa, roe, roi, curr_r, quick_r, lt_debt_eq, debt_eq, gross_margin, profit_margin, earnings, price, change, volume
  def extract_row(elem)
    ticker = elem.css("td")[1].text
    market_cap = elem.css("td")[2].text
    dividend_yield = elem.css("td")[3].text
    roa = elem.css("td")[4].text
    roe = elem.css("td")[5].text
    roi = elem.css("td")[6].text
    curr_r = elem.css("td")[7].text
    quick_r = elem.css("td")[8].text
    lt_debt_eq = elem.css("td")[9].text
    debt_eq = elem.css("td")[10].text
    gross_margin = elem.css("td")[11].text
    profit_margin = elem.css("td")[12].text
    earnings = elem.css("td")[13].text
    price = elem.css("td")[14].text
    change = elem.css("td")[15].text
    volume = elem.css("td")[16].text

    [ticker, market_cap, dividend_yield, roa, roe, roi, curr_r, quick_r, lt_debt_eq, debt_eq, gross_margin,
      profit_margin, earnings, price, change, volume]
  end
end

HighDivAnalyzer.new.diff_companies

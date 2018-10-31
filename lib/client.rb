require "httmultiparty"
require "nokogiri"
require "pry"
require "csv"

class FinvizClient
  include HTTMultiParty
  base_uri "https://finviz.com"

  HEADERS = ["Ticker", "Company", "Sector", "Industry", "Country", "Market Cap", "P/E", "Price"].freeze

  def screener_content(record_offset = 1)
    resp = self.class.get("/screener.ashx?v=111&f=fa_pe_u5&ft=4&o=pe&r=#{record_offset}")
    Nokogiri::HTML(resp).at_css('#screener-content')
  end

  def retrieve_company_info
    CSV.open("csv_files/#{Date.today.strftime('%Y-%m-%dT%H:%M:%S%z')}-finviz.csv", 'wb') do |csv|
      csv << HEADERS
      offset = 0
      more_rows = true
      while more_rows
        content = screener_content(offset * 20 + 1).css('table[bgcolor="#d3d3d3"]').css("tr[valign='top']")
        sleep(4)
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
    most_recent_file_created, previous_file_created = Dir["csv_files/*finviz*"].sort { |a, b| b <=> a }[0..1]

    most_recent_file_content = CSV.read(most_recent_file_created)
    previous_file_content = CSV.read(previous_file_created)

    CSV.open("csv_files/#{Date.today.strftime('%Y-%m-%dT%H:%M:%S%z')}-diff.csv", 'wb') do |csv|
      csv << (["Action"] + HEADERS)
      most_recent_file_content.each do |recent_file_line|
        unless previous_file_content.any? { |prev_file_line| prev_file_line[0] == recent_file_line[0] } # ticker
          csv << (["ADDED"] + recent_file_line)
        end
      end

      previous_file_content.each do |prev_file_line|
        unless most_recent_file_content.any? { |recent_file_line| prev_file_line[0] == recent_file_line[0] } # ticker
          csv << (["REMOVED"] + prev_file_line)
        end
      end
    end
  end

  # All HEADERS
  # No, Ticker, Company, Sector, Industry, Country, Market Cap, P/E, Price, Change, Volume
  def extract_row(elem)
    ticker = elem.css("td")[1].text
    company = elem.css("td")[2].text
    sector = elem.css("td")[3].text
    industry = elem.css("td")[4].text
    country = elem.css("td")[5].text
    market_cap = elem.css("td")[6].text
    price_earnings = elem.css("td")[7].text
    price = elem.css("td")[8].text

    [ticker, company, sector, industry, country, market_cap, price_earnings, price]
  end
end

FinvizClient.new.diff_companies

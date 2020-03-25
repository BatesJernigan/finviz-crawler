require "httmultiparty"
require "nokogiri"
require "pry"
require "csv"

class Base
  include HTTMultiParty
  base_uri "https://finviz.com"
end

# frozen_string_literal: true

require 'logger'
require 'faraday'
require 'selenium-webdriver'

def main
  logger = Logger.new($stdout)
  logger.info('sonybank_scraper is started')

  amount = fetch_amount
  logger.info("Current amount is: #{amount}")

  update_amount(amount)

  logger.info('sonybank_scraper is finished')
end

# @return [Integer] Fetched amount
def fetch_amount
  args = %w[
    --no-sandbox
    --headless
  ]

  options = Selenium::WebDriver::Chrome::Options.new(args: args)
  driver = Selenium::WebDriver.for(:chrome, options: options)

  ten_no = ENV['SONYBANK_TEN_NO']
  koza_no = ENV['SONYBANK_KOZA_NO']
  password = ENV['SONYBANK_PASSWORD']
  raise '店番号・口座番号・パスワードがセットされていません。' unless ten_no && koza_no && password

  credential = {
    ten_no: ten_no,
    koza_no: koza_no,
    password: password
  }

  login_url = 'https://o2o.moneykit.net'
  driver.get(login_url)

  ten_no_input = driver.find_element(:name, 'TenNo')
  koza_no_input = driver.find_element(:name, 'KozaNo')
  password_input = driver.find_element(:name, 'Password')
  login_button = driver.find_element(:link_text, 'ログイン')

  sleep 3

  ten_no_input.send_keys(credential[:ten_no])
  koza_no_input.send_keys(credential[:koza_no])
  password_input.send_keys(credential[:password])
  login_button.click

  sleep 3

  zandaka_element = driver.find_element(:id, 'setEnYkinZandaka')
  zandaka_text = zandaka_element.text
  amount = zandaka_text.gsub(',', '').gsub('円', '').to_i

  driver.quit

  amount
end

# @param [Integer] amount
# @return [Faraday::Response]
def update_amount(amount)
  api_token = ENV['API_TOKEN']
  raise 'API_TOKENがセットされていません。' unless api_token

  connection = Faraday.new endpoint_url do |conn|
    conn.headers = {
      'Authorization' => "Bearer #{api_token}"
    }
    conn.params = {
      amount: amount
    }
  end

  connection.patch
end

def endpoint_url
  env = ENV['ENV'] || 'development'
  base_url = case env
             when 'development'
               'http://localhost:3000'
             when 'production'
               'https://api.yuru28.com'
             end

  "#{base_url}/external/amount"
end

main if __FILE__ == $PROGRAM_NAME

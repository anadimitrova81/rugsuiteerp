namespace :seo do
  # Notify IndexNow (Bing, Yandex, and other participating engines) that the
  # marketing pages should be (re)crawled. Bing's index is what ChatGPT Search
  # grounds on, so this is the fastest route to AI/search discoverability.
  # The key is public — it's verified against https://<host>/<key>.txt.
  desc "Ping IndexNow with the marketing URLs"
  task :index_now do
    require "net/http"
    require "json"

    key  = "cd2cfc6a4b87bb95d8c42fc1998cea5d"
    host = ENV.fetch("INDEXNOW_HOST", "rugsuiteerp.com")
    urls = [ "https://#{host}/", "https://#{host}/signup" ]

    payload = {
      host: host,
      key: key,
      keyLocation: "https://#{host}/#{key}.txt",
      urlList: urls,
    }

    res = Net::HTTP.post(
      URI("https://api.indexnow.org/indexnow"),
      payload.to_json,
      "Content-Type" => "application/json; charset=utf-8",
    )
    puts "IndexNow (#{host}): HTTP #{res.code} #{res.message} — submitted #{urls.size} URLs"
  end
end

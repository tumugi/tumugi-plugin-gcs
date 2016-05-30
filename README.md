[![Build Status](https://travis-ci.org/tumugi/tumugi-plugin-google_cloud_storage.svg?branch=master)](https://travis-ci.org/tumugi/tumugi-plugin-google_cloud_storage) [![Code Climate](https://codeclimate.com/github/tumugi/tumugi-plugin-google_cloud_storage/badges/gpa.svg)](https://codeclimate.com/github/tumugi/tumugi-plugin-google_cloud_storage) [![Coverage Status](https://coveralls.io/repos/github/tumugi/tumugi-plugin-google_cloud_storage/badge.svg?branch=master)](https://coveralls.io/github/tumugi/tumugi-plugin-google_cloud_storage?branch=master) [![Gem Version](https://badge.fury.io/rb/tumugi-plugin-google_cloud_storage.svg)](https://badge.fury.io/rb/tumugi-plugin-google_cloud_storage)

# tumugi-plugin-google_cloud_storage

[tumugi](https://github.com/tumugi/tumugi) plugin for Google Cloud Storage.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tumugi-plugin-google_cloud_storage'
```

And then execute:

```sh
$ bundle
```

Or install it yourself as:

```sh
$ gem install tumugi-plugin-google_cloud_storage
```

## Component

### Tumugi::Plugin::GoogleCloudStorageFileTarget

This target represent file or directory on Googl Cloud Storage.
This target has 2 parameters, `bucket` and `key`.

Tumugi workflow file using this target is like this:

```rb
task :task1 do
  param :bucket, type: :string, auto_bind: true, required: true
  param :day, type: :time, auto_bind: true, required: true
  output do
    target(:google_cloud_storage_file, bucket: bucket, key: "test_#{day.strftime('%Y%m%d')}.txt")
  end
  run do
    log 'task1#run'
    output.open('w') {|f| f.puts('done') }
  end
end
```

### Config Section

tumugi-plugin-google_cloud_storage provide config section named "google_cloud_storage" which can specified Google Cloud Storage autenticaion info.

#### Authenticate by client_email and private_key

```rb
Tumugi.config do |config|
  config.section("google_cloud_storage") do |section|
    section.project_id = "xxx"
    section.client_email = "yyy@yyy.iam.gserviceaccount.com"
    section.private_key = "zzz"
  end
end
```

#### Authenticate by JSON key file

```rb
Tumugi.configure do |config|
  config.section("google_cloud_storage") do |section|
    section.private_key_file = "/path/to/key.json"
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/tumugi/ttumugi-plugin-google_cloud_storage

## License

The gem is available as open source under the terms of the [Apache License
Version 2.0](http://www.apache.org/licenses/).

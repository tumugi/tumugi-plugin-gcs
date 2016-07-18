[![Build Status](https://travis-ci.org/tumugi/tumugi-plugin-google_cloud_storage.svg?branch=master)](https://travis-ci.org/tumugi/tumugi-plugin-google_cloud_storage) [![Code Climate](https://codeclimate.com/github/tumugi/tumugi-plugin-google_cloud_storage/badges/gpa.svg)](https://codeclimate.com/github/tumugi/tumugi-plugin-google_cloud_storage) [![Coverage Status](https://coveralls.io/repos/github/tumugi/tumugi-plugin-google_cloud_storage/badge.svg?branch=master)](https://coveralls.io/github/tumugi/tumugi-plugin-google_cloud_storage?branch=master) [![Gem Version](https://badge.fury.io/rb/tumugi-plugin-google_cloud_storage.svg)](https://badge.fury.io/rb/tumugi-plugin-google_cloud_storage)

# Google Cloud Storage plugin for [tumugi]((https://github.com/tumugi/tumugi)

tumugi-plugin-google_cloud_storage is a plugin for integrate [Google Cloud Storage](https://cloud.google.com/storage/) and [tumugi](https://github.com/tumugi/tumugi).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tumugi-plugin-google_cloud_storage'
```

And then execute `bundle install`

## Target

### Tumugi::Plugin::GoogleCloudStorageFileTarget

This target represent file or directory of Googl Cloud Storage.

#### Paramters

| name   | type   | required? | default | description                                                                              |
|--------|--------|-----------|---------|------------------------------------------------------------------------------------------|
| bucket | string | required  |         | [bucket](https://cloud.google.com/storage/docs/json_api/v1/buckets) name of GCS          |
| key    | string | required  |         | key (= [object](https://cloud.google.com/storage/docs/json_api/v1/objects) name) of GCS. |

#### Examples

Create a file which content is "done" in Google Cloud Storage.

```rb
task :task1 do
  param :bucket, type: :string, auto_bind: true, required: true
  param :day, type: :time, auto_bind: true, required: true

  output do
    target(:google_cloud_storage_file,
      bucket: bucket,
      key: "test_#{day.strftime('%Y%m%d')}.txt")
  end

  run do
    log 'task1#run'
    output.open('w') {|f| f.puts('done') }
  end
end
```

Execute this file:

```sh
$ bundle exec tumugi run -f workflow.rb -p bucket:BUCKET_NAME day:2016-07-01
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

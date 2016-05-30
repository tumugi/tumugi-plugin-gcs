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

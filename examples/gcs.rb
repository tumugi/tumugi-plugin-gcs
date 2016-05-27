task :task1 do
  param :day, type: :time, auto_bind: true, required: true
  output do
    target(:gcs_file, bucket: "tumugi-plugin-gcs", key: "test_#{day.strftime('%Y%m%d')}.txt")
  end
  run do
    log 'task1#run'
    output.open('w') {|f| f.puts('done') }
  end
end

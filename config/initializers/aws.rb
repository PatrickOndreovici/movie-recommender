Aws.config.update({
  region: 'us-east-1',
  credentials: Aws::Credentials.new('test', 'test'),
  endpoint: 'http://localhost:4566',
  force_path_style: true
})